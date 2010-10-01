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
&jobsched::read_log();
&jobsched::invoke_abort_check();
&jobsched::invoke_left_message_check();
&jobsched::invoke_watch();
if (defined $xcropt::options{rhost}) { if (defined $xcropt::options{rwd}) { $builtin::env_d = &add_host({"host" => $xcropt::options{rhost}, "wd" => $xcropt::options{rwd}, "location" => "remote"}); } else { $builtin::env_d = &add_host({"host" => $xcropt::options{rhost}, "location" => "remote"}); } }
use base qw(core);

=comment
my @postfixes = ('after_in_job.pl',
		 'before_in_job.pl',
		 'invwrite.log',
		 'sh.sh',
		 'stderr',
		 'stdout');
my @tmp = &jobsched::get_last_ids();
foreach my $file (@tmp) {
    foreach my $postfix (@postfixes) {
#    print "$file" . '_' . "$postfix\n";
	if (-e "$file" . '_' . "$postfix") {
	    unlink "$file" . '_' . "$postfix";
	}
    }
}
=cut

my $count = 0;
while (-e "$xcropt::options{inventory_path}.$count") {
    $count++;
}
rename $xcropt::options{inventory_path}, "$xcropt::options{inventory_path}.$count";
# Up to here your script.  From here Xcrypt's footer.
&jobsched::check_and_write_aborted();
