package interactive;

use xcropt;
use File::Spec;
use common;
use jobsched;
use Net::OpenSSH;

sub qdel {
    my ($id) = @_;
    if (($jobsched::Last_State{$id} eq 'queued') || ($jobsched::Last_State{$id} eq 'running')) {
	unless ($jobsched::Last_State{$id} eq 'done') {
	    my $qdel_command = $jsconfig::jobsched_config{$jobsched::Last_Sched_ID{$id}}{qdel_command};
	    unless ( defined $qdel_command ) {
		die "qdel_command is not defined in $jobsched::Last_Sched_ID{$id}.pm";
	    }
	    if ($jobsched::Last_Request_ID{$id}) {
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
		    my ($user, $host) = split(/@/, $jobsched::Last_Userhost_ID{$id});
		    my $ssh = Net::OpenSSH->new($host, (user => $user));
		    $ssh->system("$command_string") or warn $ssh->error;
		}
	    }
	}
    }
}

1;

