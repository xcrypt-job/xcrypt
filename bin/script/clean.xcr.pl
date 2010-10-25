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
