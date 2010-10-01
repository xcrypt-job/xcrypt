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

open(my $fh, File::Spec->catfile($Inventory_Path, 'job_ids')) or die "$!";
my $line = <$fh>;
my @jobs = split(/ /, $line);
foreach (@jobs) {
    system("xcryptdel $_");
}
# Up to here your script.  From here Xcrypt's footer.
