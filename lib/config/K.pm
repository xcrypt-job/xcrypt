use config_common;
use File::Spec;
use File::Basename qw(basename);
my $myname = basename(__FILE__, '.pm');
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => "pjsub",
    qdel_command => 'pjdel',
    qstat_command => "pjstat",
    left_message_running_file_type => 'file',
    left_message_done_file_type => 'file',
    # standard options
	#jobscript_preamble => ['#!/bin/sh', '#PJM -s', '#PJM --mpi "use-rankdir"'],
    jobscript_preamble => ['#!/bin/sh', '#PJM -s'],
    jobscript_workdir => sub { File::Spec->catfile('.'); },
    jobscript_option_stdout => workdir_file_option('#PJM -o ', '"stdout"'),
    jobscript_option_stderr => workdir_file_option('#PJM -e ', '"stderr"'),
    is_alive => sub {
        my $self = shift;
	sleep 5;
        if ((-e $self->{JS_stderr}) && (-z $self->{JS_stderr})) {
	    return 0;
	} else {
	    return 1;
	}
    },
    jobscript_option_bulk => boolean_option ('#PJM --bulk\n#PJM --mpi "assign-online-node"'),
    jobscript_option_sparam => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --sparam '.$self->{$mbname};
	} else {
	    return '';
	}
    },
    jobscript_option_node => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --rsc-list "node='.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_limit_time => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --rsc-list "elapse='.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_rank_map_bynode => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --mpi "rank-map-bynode'.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_use_rankdir => boolean_option ('#PJM --mpi "use-rankdir"'),
    jobscript_option_rank_map_bychip => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --mpi "rank-map-bychip:'.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_rank_map_hostfile => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --mpi "rank-map-hostfile='.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_mpi_node => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --mpi "node='.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_mpi_shape => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --mpi "shape='.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_mpi_proc => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --mpi "proc='.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_stg_transfiles => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --stg-transfiles '.$self->{$mbname};
	} else {
	    return '';
	}
    },
    jobscript_option_name => sub {
	my ($self, $mbname) = @_;
	if (defined $self->{$mbname}) {
	    return '#PJM --name "'.$self->{$mbname}.'"';
	} else {
	    return '';
	}
    },
    jobscript_option_mpi_vset => sub {
	my ($self, $mbname) = @_;
	my @tmp;
	foreach my $i (@{$self->{$mbname}}) {
	    push(@tmp, '#PJM --vset "'.$i.'"');
 	}
	if ($#tmp < 0) {
	    return '';
	} else {
	    return @tmp;
	}
    },
    stage_in_files => sub{
    	return 1;
    },
    stage_out_files => sub{
    	return 1;
    },
    jobscript_option_stgin => sub {
	my ($self, $mbname) = @_;
	my @tmp;
	foreach my $i (@{$self->{xcr_stage_in_files_list}}) {
#	    push(@tmp, '#PJM --stgin "rank=* '.$i.' %r:./"');
	    push(@tmp, '#PJM --stgin "'.$i.' ./"');
 	}
	foreach my $i (@{$self->{$mbname}}) {
#	    push(@tmp, '#PJM --stgin "rank=* '.$i.'"');
	    push(@tmp, '#PJM --stgin "'.$i.'"');
 	}
	if ($#tmp < 0) {
	    return '';
	} else {
	    return @tmp;
	}
    },
    jobscript_option_stgout => sub {
	my ($self, $mbname) = @_;
	my @tmp;
	foreach my $i (@{$self->{xcr_stage_out_files_list}}) {
	    push(@tmp, '#PJM --stgout "'.$i.' ./"');
 	}
	foreach my $i (@{$self->{$mbname}}) {
	    push(@tmp, '#PJM --stgout "'.$i.'"');
 	}
	if ($#tmp < 0) {
	    return '';
	} else {
	    return @tmp;
	}
    },
    jobscript_option_stgin_dir => sub {
	my ($self, $mbname) = @_;
	my @tmp;
	foreach my $i (@{$self->{$mbname}}) {
	    push(@tmp, '#PJM --stgin-dir "'.$i.'"');
 	}
	if ($#tmp < 0) {
	    return '';
	} else {
	    return @tmp;
	}
    },
    jobscript_option_stgout_dir => sub {
	my ($self, $mbname) = @_;
	my @tmp;
# 	foreach my $i (@{$self->{xcr_stage_out_files_list}}) {
# 	    push(@tmp, '#PJM --stgout-dir "'.$i.' ./"');
#  	}
	foreach my $i (@{$self->{$mbname}}) {
	    push(@tmp, '#PJM --stgout-dir "'.$i.'"');
 	}
	if ($#tmp < 0) {
	    return '';
	} else {
	    return @tmp;
	}
    },
    jobscript_body_preamble => sub {
	$self = shift;
	return ("export PARALLEL=$self->{JS_cpu}",
		"export OMP_NUM_THREADES=$self->{JS_cpu}",
		". /work/system/Env_base");
    },
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /\[INFO\]\sPJM\s0000\spjsub\sJob\s([0-9]+)\ssubmitted/) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /^([0-9]+)\s/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
