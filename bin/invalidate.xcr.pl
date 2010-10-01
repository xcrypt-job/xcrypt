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
use File::Spec;
use interactive_command;

my $Inventory_Path = $xcropt::options{inventory_path};
foreach my $id (@ARGV) {
    print "$id is invalidated by user.\n";
    unlink File::Spec->catfile($Inventory_Path,
			       $id . '_to_be_cancelled');
    system('touch ' . File::Spec->catfile($Inventory_Path,
					  $id . '_to_be_invalidated'));
    my ($last_stat, $request_id, $userhost, $sched)
	= &interactive_command::read_log($id);
    &interactive_command::qdel($last_stat, $request_id, $userhost, $sched);
}
# Up to here your script.  From here Xcrypt's footer.
