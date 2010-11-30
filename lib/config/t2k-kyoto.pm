# Config file for Kyoto Fujitsu NQS
use config_common;
use File::Spec;

$jsconfig::jobsched_config{"t2k-kyoto"} = {
    # commands
    qsub_command => "/thin/local/bin/qsub",
    qdel_command => "/usr/bin/qdel -K",
    qstat_command => "/thin/local/bin/qstat",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
#    jobscript_workdir => sub { File::Spec->catfile('$QSUB_WORKDIR',$_[0]->{id}); },
    jobscript_workdir => sub { File::Spec->catfile('$QSUB_WORKDIR'); },
    jobscript_option_stdout => workdir_file_option('# @$-o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('# @$-e ', 'stderr'),
    jobscript_option_merge_output => boolean_option ('# @$-eo'),
    jobscript_option_node => '# @$-lP ',
    jobscript_option_cpu => '# @$-lp ',
    jobscript_option_memory => '# @$-lm ',
    jobscript_option_limit_time => '# @$-cp ',
    jobscript_option_limit_cputime => '# @$-lT ',
    jobscript_option_queue => '# @$-q ',
    jobscript_option_group => '# @$-g ',
    # non-standard options
    jobscript_option_stack => '# @$-ls ',
    jobscript_option_verbose => boolean_option ('# @$-oi'),
    jobscript_option_verbose_node => boolean_option ('# @$-OI'),
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /([0-9]*)\.nqs/) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /([0-9]+)\.nqs/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
