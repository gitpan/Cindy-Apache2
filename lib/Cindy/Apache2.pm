# $Id: Apache2.pm 38 2010-04-11 19:09:28Z jo $
# Cindy::Apache2 - mod_perl2 interface for the Cindy module.
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package Cindy::Apache2;

use strict;
use warnings;

our $VERSION = '0.03';

use APR::Brigade ();
use Apache2::Response ();
use Apache2::SubRequest ();
use Apache2::Filter ();
use Apache2::Log;
use Apache2::Const -compile => qw(OK DECLINED 
    HTTP_NOT_MODIFIED HTTP_NOT_FOUND SERVER_ERROR);
use APR::Const    -compile => qw(:error SUCCESS);
#use Log::Log4perl qw(:easy);

use Apache2::RequestRec ();
use APR::Finfo ();

use Cindy;
use Cindy::Log;

use constant CIS => 'CIS';
use constant DATA => 'DATA';
use constant DOC => 'DOC';

#
# funktion: handler	
# param.:	-
# return:	-
# Since this handler actually needs 3 parameters, these
# are passed as enviroment variables. Their names are
# CINDY_CIS_URL, CINDY_DATA_URL, CINDY_DOC_URL or
# CINDY_CIS_FILE, CINDY_DATA_FILE, CINDY_DOC_FILE
# as an alternative. 
#
sub handler {
	my ($r)	= @_;
  #$r = Apache2::RequestRec->new($r);
  
  my $rv;

  # Subrequest for DOC
  my ($doc, $doc_type);
  $rv = read_subrequest($r, DOC, \$doc, \$doc_type);
  if ($rv != Apache2::Const::OK) {
    return $rv;
  }
  # Subrequest for DATA
  my ($data, $data_type);
  $rv = read_subrequest($r, DATA, \$data, \$data_type);
  if ($rv != Apache2::Const::OK) {
    return $rv;
  }
  # Subrequest for CIS
  my $cis;
  $rv = read_subrequest($r, CIS, \$cis);
  if ($rv != Apache2::Const::OK) {
    return $rv;
  }
  
  # Do the 304
  if ($r->meets_conditions == Apache2::Const::HTTP_NOT_MODIFIED) {
    $r->set_last_modified;
    return Apache2::Const::HTTP_NOT_MODIFIED;
  } 
 
  # Parse DOC
  $doc = parse_by_type($doc_type, $doc, DOC);
  if (!defined($doc)) {
    return Apache2::Const::SERVER_ERROR;
  }  
  # Parse DATA
  $data = parse_by_type($data_type, $data, DATA);
  if (!defined($data)) {
    return Apache2::Const::SERVER_ERROR;
  }
  # Parse CIS
  if (!$cis) {
    ERROR "Failed to retrieve content for CIS.";
    return Apache2::Const::SERVER_ERROR;
  }
  $cis = parse_cis_string($cis);
  if (!defined($cis)) {
    ERROR "Error parsing CIS file.";
    return Apache2::Const::SERVER_ERROR;
  }

  INFO "Parsing succeeded. Will do injection now.";
  my $out = inject($data, $doc, $cis);

  INFO "Injection successful. Sending content.";
  $r->set_last_modified;
  $r->content_type('text/html;charset='.$doc->actualEncoding());
  print $out->toStringHTML();

  dump_xpath_profile();

  return Apache2::Const::OK;
}

#
# Read data of the given kind into a stringref
#
sub read_subrequest($$$;$)
{
  my ($r, $what, $rtext, $rtype) = @_;
  my $rsub = lookup_by_env($r, $what);
  if (!defined($rsub)) {
    return Apache2::Const::HTTP_NOT_FOUND;
  }
  my $rv = $rsub->run_trapped($rtext);
  if ($rv != Apache2::Const::OK) {
    return $rv;
  }
  if ($rtype) {
    $$rtype = $rsub->content_type;
  }
  copy_mtime($rsub, $r);
  
  return Apache2::Const::OK;
}

#
# Reads a subrequests LastModified header and sets it
# for the main request 
#
sub copy_mtime($$)
{
  my ($from, $to) = @_;
  # If no mtime is available 
  # we asume the document has just 
  # been created.
  my $mtime = $from->mtime || time; 
  $to->update_mtime($mtime);
}

#
# return An apache subrequest object
# 
sub lookup_by_env($$)
{
  my ($r, $pname) = @_;

  my $rtn;
  my $env_file = $r->subprocess_env("CINDY_$pname"."_FILE");
  if ($env_file) {
    DEBUG "Looking up '$env_file' for $pname."; 
    $rtn = $r->lookup_file($env_file);
  }

  my $env_uri = $r->subprocess_env("CINDY_$pname"."_URI");
  if ($env_uri) {
    WARN "CINDY_$pname._FILE=$env_file overwritten "
          ."by CINDY_$pname._URI=$env_uri." 
      if ($rtn);
    DEBUG "Looking up '$env_uri' for $pname."; 
    $rtn = $r->lookup_uri($env_uri);
  }

  #if ($lastmod) {
  #  $r_sub->headers_in('If-Modified-Since', time2str($lastmod));
  #}
  if (!$rtn) {
    ERROR "Could not lookup '$env_file' or '$env_uri' for $pname."; 
  } else {
    DEBUG "Lookup succeeded for '$env_file' or '$env_uri' for $pname."; 
  }

  return $rtn;     
}

#
# return An XML:LibXML root node.
# 
sub parse_by_type($$$)
{
  my ($type, $text, $what) = @_;

  if ($type =~ m/html/io) {
    my %opt = (html_parse_noimplied => 1);
    if ($type =~ /;\s*charset\s*=\s*(\S+)/) {
      # We pass the encoding from the header
      # to the HTML parser
      $opt{encoding} = $1;
    }
    return parse_html_string($text, \%opt);
  } elsif ($type =~ m/xml/io) {
    return parse_xml_string($text);
  } else {
    ERROR "Invalid $what Content-Type $type.";
    return undef;
  }
}

#
# This is shamelessly stolen from Apache2::TrapSubRequest
#
sub Apache2::SubRequest::run_trapped {
  my ($r, $dataref) = @_;
  ERROR 'Usage: $subr->run_trapped(\$data)'
      unless ref $dataref eq 'SCALAR';

  $$dataref = '' unless defined $$dataref;
  $r->pnotes(__PACKAGE__, $dataref);
  $r->add_output_filter(\&_filter);
  
  return $r->run;
}

sub _filter {
  my ($f, $bb) = @_;
  my $r = $f->r;
  my $dataref = $r->pnotes(__PACKAGE__);

  $bb->flatten(my $string);
  $$dataref .= $string;
  # Do not send anything to the client
  $bb->cleanup;
  
  return Apache2::Const::OK;
}

1;
__END__

=head1 NAME

Cindy::Apache2 - use unmodified XML or HTML documents as templates.

=head1 SYNOPSIS

  RewriteEngine On
  RewriteRule ^/cindy/content/(.*)$  /cindy/content.data/$1 [NS,E=CINDY_DATA_URI:/cindy/content.data/$1]
 
  PerlModule Cindy::Apache2
  <Location /cindy/content>
  SetEnv CINDY_CIS_URI /cindy/tmpl/frame.cjs
  SetEnv CINDY_DOC_URI /cindy/tmpl/frame.html

  SetHandler  perl-script
  PerlHandler Cindy::Apache2
  </Location>


=head1 DESCRIPTION

C<Cindy::Apache2> uses the Cindy module in an apache
content handler. Cindy merges data into a document template 
using a content injection sheet to create its response. As
you see above it is used by configuring apache. This can 
be done from .htaccess.

Since the handler needs 3 components for a request 
their names are passed as 
enviroment variables. These are CINDY_DOC_URI, 
CINDY_DATA_URI and CINDY_CIS_URI. Alternatively
CINDY_DOC_FILE, CINDY_DATA_FILE, CINDY_CIS_FILE can be used.
While the former ones are used as URIs (similiar to SSIs 
include virtual), the latter
ones require a file system path. In each case an internal 
subrequest is made. This means that all three components
can be dynamically created.

If one of the components does not return a 200 status, 
processing is aborted and that status is returned. The 
last modified headers of the components are used to
either add a last modified header to the response or to
respond with a 304.

=head1 AUTHOR

Joachim Zobel <jz-2008@heute-morgen.de> 

=head1 SEE ALSO

See the C<Cindy> documentation for further explanantions on 
content injection sheets and on what is done with those 3 files.

See L<http://www.heute-morgen.de/site/> for a more elaborate 
example of what can be done with Cindy::Apache2.


