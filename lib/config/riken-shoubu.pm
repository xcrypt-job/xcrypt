# Config file for the SHOUBU system of RIKEN
use config_common;
use File::Spec;
use File::Basename qw(basename);
use POSIX qw/ceil/;
my $myname = basename(__FILE__, '.pm');
my $NCORE = 4; # cores per physical node
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => 'sbatch',
    qdel_command => 'scancel',
    qstat_command => 'squeue',
    # standard options
    jobscript_preamble => [
	'#!/bin/sh',
	'#SBATCH -p debug',
	'#SBATCH --exclusive'],
    jobscript_workdir => sub { File::Spec->catfile('.'); },
    jobscript_other_options => sub {
	my $self = shift;
	my $node = $self->{JS_node} || 1;  
	my $cpu = $self->{JS_cpu} || 1;
	return ("#SBATCH -N $node",
		"#SBATCH --ntasks-per-node=$cpu");
    },
    #jobscript_option_node => (see other_options),
    #jobscript_option_cpu => (see other_options),
    #jobscript_option_thread => (invalid),
    #jobscript_option_memory => (invalid),
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        # Submitted batch job 12345
        my (@lines) = @_;
        foreach my $ln (@lines) {
            if ($ln =~ /Submitted batch job\s+([0-9]+)/) {
                return $1;
            }
        }
        return -1;
    },
    extract_req_ids_from_qstat_output => sub {
        # JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
        # 15108     debug     bash     maho  R    3:25:56      1 t2n154
        # ...
        my (@lines) = @_;
        my @ids = ();
        shift (@lines); # ignore the first line
        foreach (@lines) {
            if ($_ =~ /^\s*([0-9]+)\s+/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
