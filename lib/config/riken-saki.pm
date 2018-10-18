# Config file for SAKI, RIKEN BSI
use config_common;
use File::Spec;
use File::Basename qw(basename);
my $myname = basename(__FILE__, '.pm');
$jsconfig::jobsched_config{$myname} = {
    qsub_command => "qsub",
    qdel_command => "qdel",
    qstat_command => "qstat",
    jobscript_preamble => ['#$ -S /bin/sh'],
    jobscript_option_stdout => workdir_file_option('#$-o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#$-e ', 'stderr'),
    jobscript_option_queue => '#$-q ',
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /^\s*Your\s+job\s+([0-9]+)/ ) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /^\s*([0-9]+)/) {
                push (@ids, $1);
            }
        }
        return @ids;
    }
};

