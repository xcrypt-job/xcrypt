package elapsed_time;

use strict;
use jobsched;
use builtin;

&add_key('kill_at_time');

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

my $time_init = undef;
my $time_now = undef;
my $slp = 0;
my $cycle = 5;
sub start {
    my $self = shift;

    if (defined $self->{kill_at_time}) {
	Coro::async {
	    &jobsched::wait_job_running ($self);
	    $time_init = time();
	    my $stat = 'running';
	    until ($stat eq 'done') {
		Coro::AnyEvent::sleep $cycle;
		$stat = &jobsched::get_job_status ($self);
		$time_now = time();
		my $elapsed = $time_now - $time_init;
		print $elapsed, "\n";
		if ($self->{kill_at_time} < $elapsed) {
		    $self->invalidate();
		    $stat = 'done';
		}
	    }
	} $self;
	Coro::AnyEvent::sleep $slp;
    }

    $self->NEXT::start();
}

1;
