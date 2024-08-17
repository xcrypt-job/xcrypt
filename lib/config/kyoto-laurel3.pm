# Config file for the Subsystem B (Laurel3, DELL PowerEdge C6620)
# of ACCMS, Kyoto University installed in 2023
# https://www.iimc.kyoto-u.ac.jp/ja/services/comp/supercomputer/system/specification.html
use config_common;
use File::Spec;
use File::Basename qw(basename);
use POSIX qw/ceil floor/;
my $myname = basename(__FILE__, '.pm');
my $NCORE = 112;  # cores per physical node
my $MEM = 500*1024; # memory size per proc available for users in MiB
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => 'sbatch',
    qdel_command => 'scancel',
    qstat_command => 'qs',
    # standard options
    jobscript_preamble => ['#!/bin/bash'],
    jobscript_option_stdout => workdir_file_option('#SBATCH -o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#SBATCH -e ', 'stderr'),
    # jobscript_workdir => '$QSUB_WORKDIR',
    jobscript_other_options => sub {
        my $self = shift;
	    my $node = $self->{JS_node} || 1;
        my $cpu = $self->{JS_cpu} || 1;
        my $thread = $self->{JS_thread} || $cpu;
        my $memory = $self->{JS_memory} || floor($MEM*$cpu/$NCORE).'M';
        return "#SBATCH --rsc p=$node:t=$thread:c=$cpu:m=$memory";
    },
    #jobscript_option_node => (see other_options),
    #jobscript_option_cpu => (see other_options),
    #jobscript_option_thread => (see other_options),
    #jobscript_option_memory => (see other_options),
    # If JS_limit_time looks like a number, treat it as seconds and convert it into the 'hh:mm' format.
    jobscript_option_limit_time => time_hhmmss_option ('#SBATCH -t '),
    jobscript_option_queue => '#SBATCH -p ',
    #jobscript_option_group => '#SBATCH -ug ',
    # non-standard options
    # prohibit the job to restart automatically after the system fails.
    jobscript_option_norestart => boolean_option ('#SBATCH --no-requeue', 1),
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        # $ sbatch sample.sh
        # Submitted batch job 20
        my (@lines) = @_;
        foreach my $ln (@lines) {
            if ($ln =~ /^\s*Submitted.*?(\d+)\s*$/) {
                return $1;
            }
        }
        return -1;
    },
    extract_req_ids_from_qstat_output => sub {
        # $ squeue
        # JOBID PARTITION     NAME     USER ST   TIME  NODES NODELIST(REASON)
        #     1  gr19999b interact   b59999  R   0:33      1 no0001
        my (@lines) = @_;
        my @ids = ();
        shift (@lines);
        foreach my $ln (@lines) {
            if ($ln =~ /^\s*(\d+)\s+/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};

