# Config file for Oakbridge-CX of the University of Tokyo
# http://www.cc.u-tokyo.ac.jp/system/obcx/
use config_common;
use File::Spec;
use File::Basename qw(basename);

my $myname = basename(__FILE__, '.pm');
my $NCORE = 56; # cores per physical node

$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => 'pjsub',
    qdel_command => "pjdel",
    qstat_command => "pjstat",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
    jobscript_option_stdout => workdir_file_option('#PJM -o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#PJM -e ', 'stderr'),
    jobscript_option_queue => '#PJM -L rscgrp=',
    jobscript_option_group => '#PJM -g ',
    # If JS_limit_time looks like a number, treat it as seconds and convert it into the 'hh:mm:ss' format.
    # If JS_limit_time is not specified, set to 1800 ('0:30:00').
    jobscript_option_limit_time => time_hhmmss_option ('#PJM -L elapse=', 1800),
    # Treat node (phnode), cpu, thread, queue, and limit_time in other_options
    jobscript_other_options => sub {
	my $self = shift;
	## Queue (resource group, e.g., 'private-flat')
	my $queue = $self->{JS_queue};
	## Limit time
	my $limit_time = $self->{JS_limit_time};
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
	    "#PJM -L node=$phnode",
	    "#PJM --mpi proc=$node",
	    "#PJM --omp thread=$thread",
	    );
    },
    # body preamble
    # jobscript_body_preamble => ['cd $PBS_O_WORKDIR'],
    # extractors
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
	# print @lines;
	# [INFO] PJM 0000 pjsub Job 1293852 submitted.
        if ($lines[0] =~ /Job ([0-9]+) submitted./) {
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
