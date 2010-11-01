# Config file for SGE
$jsconfig::jobsched_config{"SGE"} = {
    qsub_command => "/usr/bin/qsub",
    qdel_command => "/usr/bin/qdel",
    qstat_command => "/usr/bin/qstat",
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

