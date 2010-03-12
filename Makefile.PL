# $Id: Makefile.PL 25 2010-03-12 17:36:29Z jo $
use 5.006000;
use ExtUtils::MakeMaker;

use constant HAVE_APACHE_TEST => eval {
    require Apache::Test && Apache::Test->VERSION >= 1.22
};

my @CleanFiles;

if (HAVE_APACHE_TEST) {
    # $Apache::TestTrace::Level = 'debug';

    require Apache::TestMM;
    Apache::TestMM->import(qw(test clean));

    push @CleanFiles, 't/TEST';
    Apache::TestMM::filter_args();
    Apache::TestMM::generate_script('t/TEST');
}
else {
    print "Skipping Apache::Test setup (Apache::Test 1.22 or later required)\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Cindy::Apache2',
    VERSION_FROM      => 'lib/Cindy/Apache2.pm', # finds $VERSION
    PREREQ_PM   => {
	    'Cindy'	=> '0.07', 
      'mod_perl2' => '0', 
    }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Cindy/Apache2.pm', # retrieve abstract from module
       AUTHOR         => 'JZOBEL (jz-2009@heute-morgen.de)') : ()),
);
