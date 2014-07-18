# Config file for the Subsystem E (camellia, XC30 w/ Xeoh Phi)
# of ACCMS, Kyoto University installed in 2014
# http://web.kudpc.kyoto-u.ac.jp/manual/ja/run/batchjob/systeme
use config_common;
use File::Spec;
use File::Basename qw(basename);
use POSIX qw/ceil floor/;
my $myname = basename(__FILE__, '.pm');
my $NCORE = 8;   # cores per physical node
my $MEM = 30720; # memory size per node available for users in MB
my $MIC_NCORE = 60; # MIC cores per physical node
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => 'qsub <',
    qdel_command => 'qkill',
    qstat_command => 'qjobs',
    # standard options
    jobscript_preamble => ['#!/bin/bash'],
    jobscript_option_stdout => workdir_file_option('#QSUB -oo ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#QSUB -eo ', 'stderr'),
    jobscript_workdir => '$LS_SUBCWD',
    jobscript_other_options => sub {
	my $self = shift;
        my $host_str = '';
        my $mic_str = '';
        if ( $self->{JS_node} || $self->{JS_cpu} || $self->{JS_thread}
             || $self->{JS_memory} ) {
            my $node = $self->{JS_node} || 1;
            my $cpu = $self->{JS_cpu} || 1;
            my $thread = $self->{JS_thread} || $cpu;
            my $memory = $self->{JS_memory} || ceil($MEM/$NCORE*$cpu).'M';
            $host_str = "#QSUB -A p=$node:t=$thread:c=$cpu:m=$memory";
        }
        if ( $self->{JS_mic_phnode} || $self->{JS_mic_node} 
             || $self->{JS_mic_cpu} || $self->{JS_mic_thread} ) {
            my $mic_cpu = $self->{JS_mic_cpu} || 1;
            my $mic_thread = $self->{JS_mic_thread} || $mic_cpu;
            if ( $self->{JS_mic_node} ) {
                my $mic_node = $self->{JS_mic_node};
                my $mic_phnode
                    = $self->{JS_mic_phnode} || ceil($mic_node/floor($MIC_NCORE/$mic_cpu));
                $mic_str = "#QSUB -AP n=$mic_phnode:p=$mic_node:c=$mic_cpu:t=$mic_thread";
                if ( $host_str eq '' ) {
                    # Native execution
                    return $mic_str;
                } else {
                    # Symetric execution (not supported by magnolia)
                    warn "Camellia does not support symmetric execution!";
                    return ($host_str,$mic_str);
                }
            } else {
                # Offload execution
                $mic_str = "#QSUB -AP c=$mic_cpu:t=$mic_thread";
                return ($host_str,$mic_str);
            }
        } else {
            # Host only execution
            return $host_str;
        }
    },
    #jobscript_option_node => (see other_options),
    #jobscript_option_cpu => (see other_options),
    #jobscript_option_thread => (see other_options),
    #jobscript_option_memory => (see other_options),
    #jobscript_option_mic_phnode => (see other_options),
    #jobscript_option_mic_node => (see other_options),
    #jobscript_option_mic_cpu => (see other_options),
    #jobscript_option_mic_thread => (see other_options),
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
