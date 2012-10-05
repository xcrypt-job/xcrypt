# Config file for XBS
use config_common;
use File::Spec;
use File::Basename qw(basename);
my $myname = basename(__FILE__, '.pm');
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => "xqsub",
    qdel_command => "xqdel",
    qstat_command => "xqstat",
    # standard options
    jobscript_preamble => ['#!/bin/sh'],
#    jobscript_workdir => sub { File::Spec->catfile('$QSUB_WORKDIR'); },
    jobscript_option_stdout => workdir_file_option('#XBS --stdout ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#XBS --stderr ', 'stderr'),
    jobscript_option_merge_output => boolean_option ('#XBS --join oe'),
    jobscript_option_node => '#XBS --node_number ',
    jobscript_option_cpu => '#XBS --process_number ',
    jobscript_option_memory => '#XBS --proc_memory_size ',
    jobscript_option_limit_time => '#XBS --job_elapse_time ',
    jobscript_option_limit_cputime => '#XBS --node_cpu_time ',
    jobscript_option_queue => '#XBS --queue ',
    jobscript_option_group => '#XBS --group ',
    qsub_option_site => sub { '--type ' . $xcropt::options{'xbs-type'} . ' -- '; },
    qdel_option_site => sub { '--type ' . $xcropt::options{'xbs-type'} . ' '; },
    qstat_option_site => sub { '--type ' . $xcropt::options{'xbs-type'} . ' '; },
    # non-standard options
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
