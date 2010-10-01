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
use xcropt;

my $Inventory_Path = $xcropt::options{inventory_path};
my $Logfile = File::Spec->catfile($Inventory_Path, 'transitions.log');

my @jobs;
open (my $LOG, '<', $Logfile);
unless ($LOG) {
    warn "Failed to open the log file $Logfile in read mode.";
}
while (<$LOG>) {
    chomp;
    if ($_ =~ /^:reqID\s+(\S+)\s+([0-9]+)/ ) {
	my $id = $1;
	system("xcryptdel $id");
    }
}
close ($LOG);
# Up to here your script.  From here Xcrypt's footer.
