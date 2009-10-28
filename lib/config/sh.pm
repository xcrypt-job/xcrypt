# Config file for sh
$jsconfig::jobsched_config{"sh"} = {
    qsub_command => "$ENV{XCRYPT}/lib/config/run-output-pid.sh",
    qdel_command => "kill -9",
    qstat_command => "ps",
    qsub_stdout_option => '-o ',
    qsub_stderr_option => '-e ',
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /([0-9]*)/) {
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
    },
};
