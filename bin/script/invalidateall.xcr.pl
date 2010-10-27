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
unless ($xcropt::options{scratch}) { &jobsched::read_log(); }
&jobsched::invoke_abort_check();
&jobsched::invoke_left_message_check();
$builtin::env_d = &add_host({"host" => $xcropt::options{host}, "wd" => $xcropt::options{wd}}, "sched" => $xcropt::options{sched}, "xd" => $xcropt::options{xd}, "p5l" => $xcropt::options{p5l});
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
my @ids;
while (<$LOG>) {
    chomp;
    if ($_ =~ /^:reqID\s+(\S+)/ ) {
	my $id = $1;
	push(@ids, $1);
    }
}
system("$ENV{XCRYPT}/bin/xcryptinvalidate @ids" . join(' ', @ARGV) . ' --scratch');
close ($LOG);
# Up to here your script.  From here Xcrypt's footer.
