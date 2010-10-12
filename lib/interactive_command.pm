package interactive_command;

use xcropt;
use File::Spec;
use common;

my $Inventory_Path = $xcropt::options{inventory_path};
my $Logfile = File::Spec->catfile($Inventory_Path, 'transitions.log');
my %Last_State = ();
my %Last_Request_ID = ();
my %Last_Userhost_ID = ();
my %Last_Sched_ID = ();
sub read_log {
    if (-e $Logfile) {
        open (my $LOG, '<', $Logfile);
        unless ($LOG) {
            warn "Failed to open the log file $Logfile in read mode.";
            return 0;
        }
        while (<$LOG>) {
            chomp;
            if ($_ =~ /^:transition\s+(\S+)\s+(\S+)\s+([0-9]+)/ ) {
                my ($id, $stat, $time) = ($1, $2, $3);
                $Last_State{$id} = $stat;
            } elsif ($_ =~ /^:reqID\s+(\S+)\s+([0-9]+)\s+(\S+)\s+(\S+)/ ) {
                my ($id, $req_id, $userhost, $sched) = ($1, $2, $3, $4);
                $Last_Request_ID{$id} = $req_id;
                $Last_Userhost_ID{$id} = $userhost;
                $Last_Sched_ID{$id} = $sched;
            }
        }
        close ($LOG);
    }
}

sub qdel {
    my ($id) = @_;
    if (($Last_State{$id} eq 'queued') || ($Last_State{$id} eq 'running')) {
	unless ($Last_State{$id} eq 'done') {
	    my $qdel_command = $jsconfig::jobsched_config{$Last_Sched_ID{$id}}{qdel_command};
	    unless ( defined $qdel_command ) {
		die "qdel_command is not defined in $Last_Sched_ID{$id}.pm";
	    }
	    if ($Last_Request_ID{$id}) {
		# execute qdel
		my $command_string = any_to_string_spc ("$qdel_command ", $Last_Request_ID{$id});
		if ($Last_Userhost_ID{$id} eq 'local') {
#        if (cmd_executable ($command_string, $self->{env})) {
		    exec_async ($command_string);
#        } else {
#            warn "$command_string not executable.";
#        }
		} else {
		    print "Deleting $id (request ID: $Last_Request_ID{$id})\n";
		    my ($user, $host) = split(/@/, $Last_Userhost_ID{$id});
		    my $ssh = Net::OpenSSH->new($host, (user => $user));
		    $ssh->system("$command_string") or warn $ssh->error;
		}
	    }
	}
    }
}

sub get_job_status { return $Last_State{$_[0]}; }

1;

