# Config file for Tsukuba SGE
$jsconfig::jobsched_config{"t2k-tsukuba"} = {
    qsub_command => "/opt/sge/local/bin/qsub2",
    qdel_command => "/opt/sge/local/bin/qdel",
    qstat_command => "/opt/sge/bin/lx24-amd64/qstat",
    jobscript_preamble => ['#% -S /bin/sh', '#% -cwd'],
    jobscript_workdir => sub { '.'; },
    jobscript_option_stdout => '#% -o ',
    jobscript_option_stderr => '#% -e ',
    jobscript_option_cpu => '#% -H ',
    jobscript_option_group => '#% -P ',
    jobscript_option_limit_time => '#% -T ',
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[1] =~ /^\s*Your\s+job\s+([0-9]+)/ ) {
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
