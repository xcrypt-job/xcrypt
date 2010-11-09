package interactive;

use xcropt;
use File::Spec;
use common;
use Net::OpenSSH;


sub qdel {
    my ($id) = @_;
    my $user;
    my $host;
    my $ssh;
    unless ($jobsched::Last_Userhost_ID{$id} eq 'local') {
	($user, $host) = split(/@/, $jobsched::Last_Userhost_ID{$id});
	$ssh = Net::OpenSSH->new($host, (user => $user));
    }

    my $running_file = File::Spec->catfile($jobsched::Last_Workdir{$id}, $id . '_is_running');
    my $done_file = File::Spec->catfile($jobsched::Last_Workdir{$id}, $id . '_is_done');
    if ($jobsched::Last_Userhost_ID{$id} eq 'local') {
	unlink $running_file;
	unlink $done_file;
    } else {
	$ssh->system("rm -f $running_file") or warn $ssh->error;
	$ssh->system("rm -f $done_file") or warn $ssh->error;
    }
    if (($jobsched::Last_State{$id} eq 'queued') || ($jobsched::Last_State{$id} eq 'running')) {
	my $qdel_command = $jsconfig::jobsched_config{$jobsched::Last_Sched_ID{$id}}{qdel_command};
	unless ( defined $qdel_command ) {
    die "qdel_command isn't defined in $jobsched::Last_Sched_ID{$id}.pm";
	}
	# execute qdel
	my $command_string = any_to_string_spc ("$qdel_command ", $jobsched::Last_Request_ID{$id});
	if ($jobsched::Last_Userhost_ID{$id} eq 'local') {
#        if (cmd_executable ($command_string, $self->{env})) {
	    exec_async ($command_string);
#        } else {
#            warn "$command_string not executable.";
#        }
	} else {
	    print "Deleting $id (request ID: $jobsched::Last_Request_ID{$id})\n";
	    $ssh->system("$command_string") or warn $ssh->error;
	}
    }
}

1;

