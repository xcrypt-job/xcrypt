package user;
use xcropt;
use builtin;
use Coro;
use jobsched;
use data_generator;
use data_extractor;
our @VALUE = ();
sub before {local ($self, @VALUE) = @_; if ($self->{before}) {&{$self->{before}}($self, @VALUE)};}
sub start  {my $self = shift;$self->SUPER::start();}
sub after  {local ($self, @VALUE) = @_; if ($self->{after} ) {&{$self->{after}}($self, @VALUE)};}
# Up to here Xcrypt's header.  From here your script.
&jobsched::read_log();
&jobsched::invoke_abort_check();
&jobsched::invoke_left_message_check();
$builtin::env_d = &add_host({"host" => $xcropt::options{host}, "wd" => $xcropt::options{wd}}, "sched" => $xcropt::options{sched}, "xd" => $xcropt::options{xd}, "p5l" => $xcropt::options{p5l});
use base qw(core);
use File::Spec;
use interactive;
use jobsched;
use xcropt;

my $Inventory_Path = $xcropt::options{inventory_path};
foreach my $id (@ARGV) {
    unlink File::Spec->catfile($Inventory_Path, $id . '_to_be_cancelled');
    system('touch ' . File::Spec->catfile($Inventory_Path, $id . '_to_be_invalidated'));
    &interactive::qdel($id);
    print "$id is invalidated by user.\n";
}
# Up to here your script.  From here Xcrypt's footer.
