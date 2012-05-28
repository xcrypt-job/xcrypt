# Config file for Kyoto Fujitsu NQS
use config_common;
use File::Spec;
use File::Basename qw(basename);
my $myname = basename(__FILE__, '.pm');
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => '/usr/share/lsf/kclustera/8.0/linux2.6-glibc2.3-x86_64/bin/qsub <',
    qdel_command => '/opt/dpc/bin/qkill',
    qstat_command => '/usr/share/lsf/kclustera/8.0/linux2.6-glibc2.3-x86_64/bin/qjobs',
    # standard options
    jobscript_preamble => ['#!/bin/bash'],
    jobscript_option_stdout => workdir_file_option('#QSUB -oo ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#QSUB -eo ', 'stderr'),
    jobscript_workdir => '$LS_SUBCWD',
    jobscript_other_options => sub {
	$self = shift;
	my $node = $self->{JS_node} || 1;
	my $cpu = $self->{JS_cpu} || 1;
	my $thread = $self->{JS_thread} || $cpu;
	my $memory = $self->{JS_memory} || (61440/32*$cpu).'M';
	return "#QSUB -A p=$node:t=$thread:c=$cpu:m=$memory";
    },
    #jobscript_option_node => (see other_options),
    #jobscript_option_cpu => (see other_options),
    #jobscript_option_thread => (see other_options),
    #jobscript_option_memory => (see other_options),
    jobscript_option_limit_time => '#QSUB -W ',
    jobscript_option_queue => '#QSUB -q ',
    jobscript_option_group => '#QSUB -ug ',
    # non-standard options
    # prohibit the job to restart automatically after the system fails.
    jobscript_option_norestart => boolean_option ('#QSUB -rn', 1),
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        # Job <5610> is submitted to queue <gr10001b>.   # as the second line
        my (@lines) = @_;
        foreach my $ln (@lines) {
            if ($ln =~ /Job\s+<([0-9]+)>\s+is/) {
                return $1;
            }
        }
        return -1;
    },
    extract_req_ids_from_qstat_output => sub {
        # JOBID     USER     STAT  QUEUE         FROM_HOST   EXEC_HOST   JOB_NAME   SUBMIT_TIME
        # 5610      w00001   RUN   gr10001b      gb-0001     gb-0200     ./a.out    May  1 00:01
        # 5611      w00001   PEND  gr10002b      gb-0001     gb-0201     ./a.out    May  1 00:02
        # ...
        my (@lines) = @_;
        my @ids = ();
        shift (@lines);
        foreach (@lines) {
            if ($_ =~ /^\s*([0-9]+)\s+/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};

