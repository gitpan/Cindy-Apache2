# $Id: Apache2.pm 7 2010-03-01 21:55:46Z jo $
# Cindy::Log - Logging for Cindy
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#


package Cindy::Log::Apache2;

use strict;
use warnings;

use base qw(Exporter);

our @EXPORT= qw(DEBUG INFO WARN ERROR FATAL); 

use Apache2::RequestUtil ();
use Apache2::Const -compile => qw(OK DECLINED :log);
use APR::Const    -compile => qw(:error SUCCESS);

use Apache2::ServerUtil ();

sub rlog
{
  my $r = Apache2::RequestUtil->request()
  or die "Please enable PerlOptions +GlobalRequest.";
  return $r;
}

sub ERROR ($)
{
  rlog->log_error(@_);
}

sub WARN ($)
{
  rlog->warn(@_);
}

sub INFO($)
{
  rlog->log_rerror(Apache2::Log::LOG_MARK, Apache2::Const::LOG_INFO,
                   APR::Const::SUCCESS, @_);
}

sub DEBUG($)
{
  rlog->log_rerror(Apache2::Log::LOG_MARK, Apache2::Const::LOG_DEBUG,
                   APR::Const::SUCCESS, @_);
}

1;

