# Config file for Reedbush of the University of Tokyo
use config_common;
use File::Spec;
use File::Basename qw(basename);

my $myname = basename(__FILE__, '.pm');
my $NCORE = 36; # cores per physical node

$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => "/opt/pbs/default/bin/qsub",
    qdel_command => "/lustre/pbs/bin/qdel",
    qstat_command => "/lustre/pbs/bin/rbstat",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
    jobscript_option_queue => '#PBS -q ',
    jobscript_option_stdout => workdir_file_option('#PBS -o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#PBS -e ', 'stderr'),
    jobscript_option_limit_time => '#PBS -l walltime=',
    jobscript_option_group => '#PBS -W group_list=',
    # Treat node (phnode), cpu, thread in other_options
    jobscript_other_options => sub {
	my $self = shift;
	## # MPI processes
	my $node = $self->{JS_node} || 1;  
        ## # cores / MPI proc.
	my $cpu = $self->{JS_cpu} || 1;
        ## # threads / MPI proc.
	my $thread = $self->{JS_thread} || $cpu;
	## # physical nodes
	my $phnode = $self->{JS_phnode} || ceil($node/floor($NCORE/$cpu));
	## # procs/cpus per phnode
	my $node_phnode = ceil($node/$phnode);
	my $cpu_phnode = $node_phnode*$cpu;
	return (
	    "#PBS -l select=$phnode:ncpus=$cpu_phnode:mpiprocs=$node_phnode:ompthreads=$thread",
            "#PBS -V", # export all environment variables
	    );
    },
    # body preamble
    # jobscript_body_preamble => ['cd $PBS_O_WORKDIR'],
    # extractors
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /^([0-9]+)/) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /^([0-9]+)/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
