package user;
use xcropt;
use builtin;
use Coro;
use jobsched;
our @VALUE = ();
sub before {local ($self, @VALUE) = @_; if ($self->{before}) {&{$self->{before}}($self, @VALUE)};}
sub start  {my $self = shift;$self->SUPER::start();}
sub after  {local ($self, @VALUE) = @_; if ($self->{after} ) {&{$self->{after}}($self, @VALUE)};}
# Up to here Xcrypt's header.  From here your script.
&jobsched::invoke_abort_check();
&jobsched::invoke_left_message_check();
if (defined $xcropt::options{rhost}) { if (defined $xcropt::options{rwd}) { $builtin::env_d = &add_host({"host" => $xcropt::options{rhost}, "wd" => $xcropt::options{rwd}, "location" => "remote"}); } else { $builtin::env_d = &add_host({"host" => $xcropt::options{rhost}, "location" => "remote"}); } }
use base qw(core);
use jobsched;
use File::Spec;
use xcropt;
use builtin;
use common;
use Net::OpenSSH;

my $Inventory_Path = $xcropt::options{inventory_path}; # The directory that system administrative files are created in.
my $Logfile = File::Spec->catfile($Inventory_Path, 'transitions.log');

foreach my $id (@ARGV) {
    &abort($id);
}

sub abort {
    my ($id) = @_;
    print "$id is aborted by user.\n";
    my $last_stat = &read_log_stat($id);
    if (($last_stat eq 'queued') || ($last_stat eq 'running')) {
	unless ($last_stat eq 'done') {
	    &qdel($id);
	}
    }
}

=comment
sub abort {
    my ($self) = @_;
    print "$self->{id} is aborted by user.\n";
    jobsched::set_signal ($self, 'sig_abort');
    if ($self->qdel_if_queued_or_running()) {
        jobsched::set_job_status_according_to_signal ($self);
    }
}
=cut

# リモート実行未対応
sub qdel {
    my ($id) = @_;
    # qdelコマンドをconfigから獲得
    my $qdel_command = $jsconfig::jobsched_config{$ENV{XCRJOBSCHED}}{qdel_command};
    unless ( defined $qdel_command ) {
        die "qdel_command is not defined in $ENV{XCRJOBSCHED}.pm";
    }
    my ($request_id, $userhost, $sched) = &read_log_reqID_userhost_sched($id);
    if ($request_id) {
        # execute qdel
        my $command_string = any_to_string_spc ("$qdel_command ", $request_id);
	if ($host eq 'local') {
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

sub read_log_stat {
    my ($arg) = @_;
    open (my $LOG, '<', $Logfile);
    unless ($LOG) {
	warn "Failed to open the log file $Logfile in read mode.";
	return 0;
    }
    my $last_stat = 'unintialized';
    while (<$LOG>) {
	chomp;
	if ($_ =~ /^:transition\s+(\S+)\s+(\S+)\s+([0-9]+)/ ) {
	    my ($id, $stat, $time) = ($1, $2, $3);
	    if ($id eq $arg) {
		$last_stat = $stat;
	    }
	}
    }
    close ($LOG);
    return $last_stat;
}

sub read_log_reqID_userhost_sched {
    my ($arg) = @_;
    open (my $LOG, '<', $Logfile);
    unless ($LOG) {
	warn "Failed to open the log file $Logfile in read mode.";
	return 0;
    }
    while (<$LOG>) {
	chomp;
	if ($_ =~ /^:reqID\s+(\S+)\s+([0-9]+)\s+(\S+)\s+(\S+)/ ) {
	    my ($id, $req_id, $userhost, $sched) = ($1, $2, $3, $4);
	    if ($id eq $arg) {
		return ($req_id, $userhost, $sched);
	    }
	}
    }
    close ($LOG);
}

# リモート実行未対応
=comment
sub qdel {
    my ($self) = @_;
    # qdelコマンドをconfigから獲得
    my $qdel_command = $jsconfig::jobsched_config{$ENV{XCRJOBSCHED}}{qdel_command};
    unless ( defined $qdel_command ) {
        die "qdel_command is not defined in $ENV{XCRJOBSCHED}.pm";
    }
    my $req_id = $self->{request_id};
    if ($req_id) {
        # execute qdel
        my $command_string = any_to_string_spc ("$qdel_command ", $req_id);
        if (cmd_executable ($command_string, $self->{env})) {
            print "Deleting $self->{id} (request ID: $req_id)\n";
            exec_async ($command_string);
        } else {
            warn "$command_string not executable.";
        }
    }
}
=cut
# Up to here your script.  From here Xcrypt's footer.
