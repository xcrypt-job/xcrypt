# Config file for the supercomputer of Hokkaido University (SR16000)
# http://www.hucc.hokudai.ac.jp/hop_info.html
use config_common;
use File::Spec;
use File::Basename qw(basename);
use POSIX qw/ceil floor/;
my $myname = basename(__FILE__, '.pm');
my $NCORE = 8*4;  # cores per physical node
# my $MEM = 122880; # memory size per node available for users in MB
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => 'llsubmit',
    qdel_command => 'llcancel',
    qstat_command => 'llq',
    # standard options
    jobscript_preamble => ['#!/bin/csh -f'],
    jobscript_shell_type => 'csh',
    jobscript_body_preamble => sub {
	my $self = shift;
	my $thread = $self->{JS_thread} || $self->{JS_cpu} || 1;
	return ('unlimit',
		'setenv MEMORY_AFFINITY MCM',               		
                'setenv MP_SHARED_MEMORY no',
		"setenv XLSMPOPTS \"spins=0:yields=0:parthds=$thread\"",
		"setenv HF_90OPTS -F'PRUNST(THREADNUM($thread),STACKSIZE(65536))'");
    },
    jobscript_option_stdout => workdir_file_option('#@output = ', 'stdout'),
    jobscript_option_stderr => workdir_file_option('#@error =', 'stderr'),
    jobscript_workdir => sub { File::Spec->catfile('.'); },
    jobscript_other_options => sub {
	my $self = shift;
	my $node = $self->{JS_node} || 1;
	my $cpu = $self->{JS_cpu} || 1;
	my $thread = $self->{JS_thread} || $cpu;
	# number of physical nodes
	my $phnode = $self->{JS_phnode} || ceil(($node*$cpu)/$NCORE);
	return ('#@job_type = parallel',
		'#@network.MPI=sn_single,,US,,instances=1',
		'#@node = '.($phnode),
                '#@task_affinity = cpu('.($cpu*2).')',
                '#@cpus_per_core = '.(($thread>$cpu)?2:1),
                '#@rset=rset_mcm_affinity',
		'#@total_tasks = '.($node),
		'#@queue',		
		);
    },
    #jobscript_option_node => (see other_options),
    #jobscript_option_cpu => (see other_options),
    #jobscript_option_thread => (see other_options and jobscript_body_preamble),
    #jobscript_option_memory => (see other_options),
    #jobscript_option_limit_time => (no description in the manual documents),
    jobscript_option_queue => '#@class = ',
    #jobscript_option_group => (unnecessary in this system),
    # non-standard options
    jobscript_option_bulkxfer => boolean_option ('#@bulkxfer=yes',1),
    # Extract from output messages
    extract_req_id_from_qsub_output => sub {
        # llsubmit: The job "htcf02c01p02.137700" has been submitted.
        my (@lines) = @_;
        foreach my $ln (@lines) {
            if ($ln =~ /llsubmit:\s+The\s+job\s+\"(\S+)\"\s+has/) {
                return $1;
            }
        }
        return -1;
    },
    extract_req_ids_from_qstat_output => sub {
	# Id                       Owner      Submitted   ST PRI Class        Running On
	# ------------------------ ---------- ----------- -- --- ------------ -----------
	# htcf02c01p02.162090.0    bu8402      6/10 17:45 R  50  G4           htcf02c05p07
	# htcf02c01p02.162091.0    bu7702      6/10 17:48 R  50  b            htcf01c01p04
        # ...
        my (@lines) = @_;
        my @ids = ();
        shift (@lines);
        foreach (@lines) {
            if ($_ =~ /^\s*(htcf\S+)\s+/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
    sleep_after_qstat => 5,
};
