# Config file for Tokyo Hitachi NQS
$jsconfig::jobsched_config{"TOKYO"} = {
    qsub_command => "/opt/hitachi/nqs/bin/qsub",
    qdel_command => "/opt/hitachi/nqs/bin/qdel",
    qstat_command => "/opt/hitachi/nqs/bin/qstat",
#    jobscript_queue => '#@$-q ',
    jobscript_stdout => '#@$-o ',
    jobscript_stderr => '#@$-e ',
#    jobscript_proc => '# @$-J ',
#    jobscript_cpu => '# @$-lp ',
    jobscript_memory => '#@$-lm ',
    jobscript_stack => '#@$-ls ',
#    jobscript_workdir => '', # OK ad hok (since 'cd $PWD' is described)
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
