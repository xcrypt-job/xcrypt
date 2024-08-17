# Config file for the Subsystem B (Laurel2, CS400 2820XT)
# of ACCMS, Kyoto University installed in 2016
# http://web.kudpc.kyoto-u.ac.jp/manual-new/ja/run/systembc
use config_common;
use File::Spec;
use File::Basename qw(basename);
use POSIX qw/ceil floor/;
my $myname = basename(__FILE__, '.pm');
my $NCORE = 68;  # cores per physical node
my $MEM = 92160; # memory size per proc available for users in MB
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => 'qsub',
    qdel_command => 'qdel',
    qstat_command => '/opt/dpc/bin/qstat',
    # standard options
    jobscript_preamble => ['#!/bin/bash'],
    jobscript_option_stdout => workdir_file_option('#QSUB -o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#QSUB -e ', 'stderr'),
    jobscript_workdir => '$QSUB_WORKDIR',
    jobscript_other_options => sub {
	my $self = shift;
	my $node = $self->{JS_node} || 1;
	my $cpu = $self->{JS_cpu} || 1;
	my $thread = $self->{JS_thread} || $cpu;
	my $memory = $self->{JS_memory} || ceil($MEM/$NCORE*$cpu).'M';
	return "#QSUB -A p=$node:t=$thread:c=$cpu:m=$memory";
    },
    #jobscript_option_node => (see other_options),
    #jobscript_option_cpu => (see other_options),
    #jobscript_option_thread => (see other_options),
    #jobscript_option_memory => (see other_options),
    # If JS_limit_time looks like a number, treat it as seconds and convert it into the 'hh:mm' format.
    jobscript_option_limit_time => time_hhmm_option ('#QSUB -W '),
    jobscript_option_queue => '#QSUB -q ',
    jobscript_option_group => '#QSUB -ug ',
    # non-standard options
    # prohibit the job to restart automatically after the system fails.
    jobscript_option_norestart => boolean_option ('#QSUB -rn', 1),
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        # $ qsub sample.sh
        # 11.jb
        my (@lines) = @_;
        foreach my $ln (@lines) {
            if ($ln =~ /\s*([0-9]+)\.jb\s+/) {
                return $1;
            }
        }
        return -1;
    },
    extract_req_ids_from_qstat_output => sub {
        # $ qstat
        # Job id            Name             User              Time Use S Queue
        # ----------------  ---------------- ----------------  -------- - -----
        # 86.pbs            qsubtest.sh      b59999            00:00:00 R workq
        # ...
        my (@lines) = @_;
        my @ids = ();
        shift (@lines);
        foreach (@lines) {
            # print $_;
            if ($_ =~ /^\s*([0-9]+)\.jb\s+/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};

