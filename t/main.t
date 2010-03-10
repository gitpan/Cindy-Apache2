#!perl

use strict;
use warnings FATAL => 'all';
use lib qw(t/lib lib);
use Test::More;
use My::TestHelper qw(cmp_file_ok read_file);

use constant HAVE_APACHE_TEST => eval {
    require Apache::Test && Apache::Test->VERSION >= 1.22
};

unless (HAVE_APACHE_TEST) {
    plan skip_all => 'Apache::Test 1.22 is not installed';
}
elsif (not Apache::Test::need_lwp()) {
    plan skip_all => 'libwww-perl is not installed';
}
else {
    plan tests => 7;

    require Apache::TestUtil;
    require Apache::TestRequest;

    Apache::Test->import(':withtestmore');
    Apache::TestUtil->import;
    Apache::TestRequest->import('GET');
}

SKIP: {
    # Check reqirements
    use_ok('Apache2::Request') or exit 1;
    use_ok('Cindy') or exit 1;
    # Check if Cindy::Apache2 is there
    use_ok('Cindy::Apache2') or exit 1;

    my $docroot = Apache::Test::vars('documentroot');

    # make sure we can get a regular file
    {
        my $url = '/test.html';
        my $r = GET($url);
        is $r->code, 200;
        cmp_file_ok $r->content, "$docroot/test.html";
    }

    # Try to use Cindy
    # This is an older test for the cindy module.
    # The purpose of this test is not to check if cindy is 
    # working correctly. We just test if cindy is working.
    {
        my $url = '/cindy_test.html';
        my $r = GET($url);
        is $r->code, 200;

        cmp_file_ok $r->content, "$docroot/cindy_test.html";
    }


#    # filter a .less file
#    {
#        my $url = '/stylesheet.less';
#        my $r = GET($url);
#
#        is $r->code, 200;
#        is $r->content_type, 'text/css';
#
#        my $expected = join '', CSS::LESSp->parse(
#            read_file("$docroot/stylesheet.less"));
#        my $got = $r->content;
#
#        $expected =~ s/[\r\n]//g;
#        $got      =~ s/[\r\n]//g;
#
#        is $got, $expected, 'less filtering';
#    }
#
#    # check .less.txt is text/plain
#    {
#        my $url = '/stylesheet.less.txt';
#        my $r = GET($url);
#
#        is $r->code, 200;
#        is $r->content_type, 'text/plain';
#    }
}
