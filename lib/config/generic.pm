# Config file for Generic
use config_common;
use File::Spec;

$jsconfig::jobsched_config{"generic"} = {
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
#    jobscript_workdir => sub { File::Spec->catfile('$QSUB_WORKDIR'); },
#    jobscript_option_stdout => workdir_file_option('# @$-o ', 'stdout'),
#    jobscript_option_stderr => workdir_file_option('# @$-e ', 'stderr'),
#    jobscript_option_merge_output => boolean_option ('# @$-eo'),
#    jobscript_option_node => '# @$-lP ',
#    jobscript_option_cpu => '# @$-lp ',
#   jobscript_option_memory => '# @$-lm ',
#    jobscript_option_limit_time => '# @$-cp ',
#    jobscript_option_limit_cputime => '# @$-lT ',
    jobscript_option_queue => '#XBS--queue ',
    jobscript_option_group => '#XBS--group ',
    # non-standard options
#    jobscript_option_stack => '# @$-ls ',
#    jobscript_option_verbose => boolean_option ('# @$-oi'),
#    jobscript_option_verbose_node => boolean_option ('# @$-OI'),
};
