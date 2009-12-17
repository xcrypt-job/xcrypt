# Config file for NQS
$jsconfig::jobsched_config{"NQS"} = {
    qsub_command => "/thin/local/bin/qsub",
    qdel_command => "/usr/bin/qdel -K",
    qstat_command => "/thin/local/bin/qstat",
    jobscript_queue => '# @$-q ',
    jobscript_group => '# @$-g ',
    jobscript_stdout => '# @$-o ',
    jobscript_stderr => '# @$-e ',
    jobscript_proc => '# @$-lP ',
    jobscript_cpu => '# @$-lp ',
    jobscript_memory => '# @$-lm ',
    jobscript_stack => '# @$-ls ',
    jobscript_verbose => '# @$-oi',
    jobscript_verbose_node => '# @$-OI',
    jobscript_workdir => '$QSUB_WORKDIR',
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
