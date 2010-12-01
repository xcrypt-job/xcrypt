package jsconfig;

use strict;
#use xcropt;

# Load all configulation files in $XCRYPT/lib/config/*.pm and initialize %jobsched_config

our %jobsched_config = undef;

my $jobsched_config_dir = File::Spec->catfile ($xcropt::options{xd}, 'lib', 'config');
unless ( -e File::Spec->catfile ($jobsched_config_dir, $xcropt::options{sched} . ".pm") ) {
    die "No config file for $xcropt::options{sched} ($xcropt::options{sched}.pm) in $jobsched_config_dir";
}
foreach ( glob (File::Spec->catfile ($jobsched_config_dir, "*" . ".pm")) ) {
    # print "loading config file $_\n";
    do $_;
}

1;
