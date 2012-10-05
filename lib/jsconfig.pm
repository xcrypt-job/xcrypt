package jsconfig;

use strict;
use File::Spec;
#use xcropt;

# Load all configulation files in $XCRYPT/lib/config/*.pm and initialize %jobsched_config

our %jobsched_config = undef;

my $jobsched_config_dir = File::Spec->catfile ($ENV{XCRYPT}, 'lib', 'config');
foreach ( glob (File::Spec->catfile ($jobsched_config_dir, "*" . ".pm")) ) {
    # print "loading config file $_\n";
    do $_;
}

1;
