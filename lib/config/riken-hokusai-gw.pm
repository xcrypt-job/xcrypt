# Config file for the HOKUSAI GrateWave system of RIKEN
use config_common;
use File::Spec;
use File::Basename qw(basename);
use POSIX qw/ceil/;
my $myname = basename(__FILE__, '.pm');
my $NCORE = 32; # cores per physical node
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => 'pjsub',
    qdel_command => 'pjdel',
    qstat_command => 'pjstat',
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
    #jobscript_body_preamble => [''],
    #jobscript_option_stdout => workdir_file_option('#QSUB -oo ', 'stdout'),
    #jobscript_option_stderr => workdir_file_option('#QSUB -eo ', 'stderr'),
    jobscript_workdir => sub { File::Spec->catfile('.'); },
    jobscript_other_options => sub {
	my $self = shift;
	## # MPI processes
	my $node = $self->{JS_node} || 1;  
        ## # cores / MPI proc.
	my $cpu = $self->{JS_cpu} || 1;
	## # physical nodes
	my $phnode = $self->{JS_phnode} || ceil(($node*$cpu)/$NCORE);
	return (
	    "#PJM -L \"node=$phnode\"",
	    "#PJM --mpi \"proc=$node\"",
            "#PJL -j"
	    );
    },
    #jobscript_option_node => (see other_options),
    #jobscript_option_cpu => (see other_options),
    #jobscript_option_thread => (invalid),
    #jobscript_option_memory => (invalid),
    jobscript_option_limit_time => sub {
	my ($self, $mbname) = @_;
	return $self->{$mbname}?
	    '#PJM -L "elapse='.$self->{$mbname}.'"' : ();
    },
    jobscript_option_queue => sub {
	my ($self, $mbname) = @_;
	return $self->{$mbname}?
	    '#PJM -L "rscunit='.$self->{$mbname}.'"' : ();
    },
    jobscript_option_group => sub {
	my ($self, $mbname) = @_;
	return $self->{$mbname}?
	    '#PJM -L "rscgrp='.$self->{$mbname}.'"' : ();
    },
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        # [INFO] PJM 0000 pjsub Job 12345 submitted.
        my (@lines) = @_;
        foreach my $ln (@lines) {
            if ($ln =~ /\s+([0-9]+)\s+submitted/) {
                return $1;
            }
        }
        return -1;
    },
    extract_req_ids_from_qstat_output => sub {
        # JOB_ID JOB_NAME MD ST USER START_DATE ELAPSE_LIM NODE_REQUIRE VNODE CORE V_MEM
        # 123430 a.sh NM QUE q0903102 - 0000:00:15 1 - - -
        # 123431 a.sh NM RNP q0903102 (03/12 11:05)< 0000:00:15 1 - - -
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
