# Config file for XBS
use config_common;
use File::Spec;

$jsconfig::jobsched_config{"XBS"} = {
    # commands
    qsub_command => "xqsub",
    qdel_command => "xqdel",
    qstat_command => "xqstat",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
#    jobscript_workdir => sub { File::Spec->catfile('$QSUB_WORKDIR'); },
    jobscript_option_stdout => workdir_file_option('#XBS --stdout ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#XBS --stderr ', 'stderr'),
#    jobscript_option_merge_output => boolean_option ('# @$-eo'),
#    jobscript_option_node => '# @$-lP ',
#    jobscript_option_cpu => '# @$-lp ',
#   jobscript_option_memory => '# @$-lm ',
#    jobscript_option_limit_time => '# @$-cp ',
#    jobscript_option_limit_cputime => '# @$-lT ',
    jobscript_option_queue => '#XBS --queue ',
    jobscript_option_group => '#XBS --group ',
    qsub_option_site => sub { '--site ' . $xcropt::options{'xbs-site'} . ' -- '; },
    qdel_option_site => sub { '--site ' . $xcropt::options{'xbs-site'} . ' '; },
    qstat_option_site => sub { '--site ' . $xcropt::options{'xbs-site'} . ' '; },
    # non-standard options
#    jobscript_option_stack => '# @$-ls ',
#    jobscript_option_verbose => boolean_option ('# @$-oi'),
#    jobscript_option_verbose_node => boolean_option ('# @$-OI'),
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
