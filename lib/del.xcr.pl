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

my $Inventory_Path = $xcropt::options{inventory_path}; # The directory that system administrative files are created in.

foreach my $id (@ARGV) {
    &abort($id);
}

sub abort {
    my ($id) = @_;
    print "$id is aborted by user.\n";
    if ((-e File::Spec->catfile($Inventory_Path,
				$id,
				$id . '_is_queued')) ||
	(-e File::Spec->catfile($Inventory_Path,
				$id,
				$id . '_is_running'))) {
	unless (-e File::Spec->catfile($Inventory_Path,
				       $id,
				       $id . '_is_done')) {
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
    open(my $fh, File::Spec->catfile($Inventory_Path, $id, $id . '_is_queued')) or die "$!";
    my @request_ids = <$fh>;
    my $request_id = $request_ids[0];
	print $request_id, "\n";
    if ($request_id) {
        # execute qdel
        my $command_string = any_to_string_spc ("$qdel_command ", $request_id);
        if (cmd_executable ($command_string, $self->{env})) {
            print "Deleting $id (request ID: $request_id)\n";
            exec_async ($command_string);
        } else {
            warn "$command_string not executable.";
        }
    }
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
