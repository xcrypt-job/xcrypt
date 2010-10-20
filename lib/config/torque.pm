# Config file for torque
use config_common;
use File::Spec;

$jsconfig::jobsched_config{"torque"} = {
    qsub_command => "/opt/torque/bin/qsub",
    qdel_command => "/opt/torque/bin/qdel",
    qstat_command => "/opt/torque/bin/qstat",
    jobscript_option_queue => '#PBS -q ',
    jobscript_option_stdout => workdir_file_option('#PBS -o ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#PBS -e ', 'stderr'),
    # jobscript_option_node => ## See jobscript_other_options
    # jobscript_option_cpu =>  ## See jobscript_other_options
    jobscript_option_memory => '#PBS -l pmem=',
    # jobscript_stack => ???
    jobscript_other_options => sub {
	$self = shift;
	my $node = $self->{JS_node} || 1;
	my $cpu = $self->{JS_cpu} || 1;
	return "#PBS -l nodes=$node:ppn=$cpu";
    },
    # jobscript_workdir => '', # OK ad hok (since 'cd $PWD' is described)
    jobscript_body_preamble => 'SCORE_RSH="/opt/torque/bin/pbsdsh -h %s /bin/sh -c"',
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /^([0-9]*)\./) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /^([0-9]+)\./) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
