package jsconfig;

use strict;

our %jobsched_config = undef; # used in jobsched.pm, xcryptstat, and xcryptdel

my $jobsched_config_dir = File::Spec->catfile ($ENV{XCRYPT}, 'lib', 'config');
unless ( -e File::Spec->catfile ($jobsched_config_dir, $ENV{XCRJOBSCHED} . ".pm") ) {
    die "No config file for $ENV{XCRJOBSCHED} ($ENV{XCRJOBSCHED}.pm) in $jobsched_config_dir";
}
foreach ( glob (File::Spec->catfile ($jobsched_config_dir, "*" . ".pm")) ) {
    # print "loading config file $_\n";
    do $_;
}

1;
