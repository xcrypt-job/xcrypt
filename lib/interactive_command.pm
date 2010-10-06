package interactive_command;

use xcropt;
use File::Spec;
use common;

my $Inventory_Path = $xcropt::options{inventory_path};
my $Logfile = File::Spec->catfile($Inventory_Path, 'transitions.log');

sub qdel {
    my ($last_stat, $request_id, $userhost, $sched) = @_;
    if (($last_stat eq 'queued') || ($last_stat eq 'running')) {
	unless ($last_stat eq 'done') {
	    my $qdel_command = $jsconfig::jobsched_config{$sched}{qdel_command};
	    unless ( defined $qdel_command ) {
		die "qdel_command is not defined in $sched.pm";
	    }
	    if ($request_id) {
		# execute qdel
		my $command_string = any_to_string_spc ("$qdel_command ", $request_id);
		if ($userhost eq 'local') {
#        if (cmd_executable ($command_string, $self->{env})) {
		    exec_async ($command_string);
#        } else {
#            warn "$command_string not executable.";
#        }
		} else {
		    print "Deleting $id (request ID: $request_id)\n";
		    my ($user, $host) = split(/@/, $userhost);
		    my $ssh = Net::OpenSSH->new($host, (user => $user));
		    $ssh->system("$command_string") or warn $ssh->error;
		}
	    }
	}
    }
}

sub read_log {
    my ($arg) = @_;
    open (my $LOG, '<', $Logfile);
    unless ($LOG) {
	warn "Failed to open the log file $Logfile in read mode.";
	return 0;
    }
    my $last_stat = 'uninitialized';
    my ($req_id, $userhost, $sched);
    while (<$LOG>) {
	chomp;
	if ($_ =~ /^:transition\s+(\S+)\s+(\S+)\s+([0-9]+)/ ) {
	    my ($id, $stat, $time) = ($1, $2, $3);
	    if ($id eq $arg) {
		$last_stat = $stat;
	    }
	} elsif ($_ =~ /^:reqID\s+(\S+)\s+([0-9]+)\s+(\S+)\s+(\S+)/ ) {
	    $id = $1;
	    if ($1 eq $arg) {
		($req_id, $userhost, $sched) = ($2, $3, $4);
	    }
	}
    }
    close ($LOG);
    return ($last_stat, $req_id, $userhost, $sched);
}

1;
