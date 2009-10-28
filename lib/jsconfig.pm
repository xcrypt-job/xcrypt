package jsconfig;

use strict;

foreach ('XCRYPT', 'XCRJOBSCHED','PERL5LIB') {
    unless (defined $ENV{"$_"}) {
	die "Set the environment varialble $_\n";
    }
}

# Load jobscheduler config files.
our %jobsched_config = undef;
our $jobsched = $ENV{'XCRJOBSCHED'};

my $jobsched_config_dir = File::Spec->catfile ($ENV{'XCRYPT'}, 'lib', 'config');
unless ( -f File::Spec->catfile ($jobsched_config_dir, $jobsched . ".pm") ) {
    die "No config file for $jobsched ($jobsched.pm) in $jobsched_config_dir";
}
foreach ( glob (File::Spec->catfile ($jobsched_config_dir, "*" . ".pm")) ) {
    do $_;
}

1;
