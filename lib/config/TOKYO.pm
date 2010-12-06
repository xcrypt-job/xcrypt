# Config file for Tokyo Hitachi NQS
use config_common;
use File::Spec;

$jsconfig::jobsched_config{"TOKYO"} = {
    # commands
    qsub_command => "/opt/hitachi/nqs/bin/qsub",
    qdel_command => "/opt/hitachi/nqs/bin/qdel",
    qstat_command => "/opt/hitachi/nqs/bin/qstat",
    jobscript_preamble => ['#!/bin/bash'],
    # standard options
    jobscript_option_stdout => workdir_file_option('#@$-o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#@$-e ', 'stderr'),
    jobscript_option_memory => '#@$-lM ',
    jobscript_option_queue => '#@$-q ',
    jobscript_option_proc => '#@$-N ',
    jobscript_option_cpu => '# @$-lp ',
    jobscript_option_limit_time => '#@$-lT ',
    # non-standard options
    jobscript_option_stack => '#@$-ls ',
#    jobscript_workdir => sub { '.'; }, # if set, NG
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /([0-9]*)\.batch1/) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /([0-9]+)\.batch1/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
