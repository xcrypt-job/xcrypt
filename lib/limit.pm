package limit;

use strict;
use Coro;
use Coro::Semaphore;
use Coro::AnyEvent;

### Global variables (class members)
my $N_submitted_jobs = 0;
my $N_finished_jobs = 0;

# Guard by limitation of simultaneous running jobs
my $Use_simul_guard = 0;
my $Smph = Coro::Semaphore->new(100);

# Rest guard: After every submission of $N_rest_count jobs,
# wait for $Rest_interval seconds after all the submitted jobs finished.
my $Use_rest_guard = 0;
my $Rest_count = 200;
my $Rest_interval = 300;
my $Rest_activated = 0;
my $Rest_signal = new Coro::Signal();

sub activate_rest_guard_if_needed {
    if ($N_submitted_jobs % $Rest_count == 0) {
        print "Rest guard is activated (#submitted=$N_submitted_jobs)\n";
        activate_rest_guard();
    }
}
sub activate_rest_guard {
    $Rest_activated = 1;
}

sub spawn_deactivate_timer_if_needed {
    if ($N_finished_jobs % $Rest_count == 0 ) {
        Coro::async_pool {
            print "All the job finished. Wait for $Rest_interval seconds until rest guard is deactivated\n";
            Coro::AnyEvent::sleep ($Rest_interval);
            deactivate_rest_guard();
            print "Rest guard is deactivated\n";
        }
    }
}
sub deactivate_rest_guard {
    $Rest_activated = 0;
    $Rest_signal->broadcast();
}

sub wait_rest_guard {
    while ($Rest_activated) {
        $Rest_signal->wait();
    }
}

### Public methods
# Uses of "limit" must call this once before submitting a job.
# $n_simul: If >0, simultaneous running jobs are limited to the given value.
# $rest_count, $rest_interval: If $rest_count>0, job submission is guarded after every $rest_count
#  job submission. The guard is deactivated again when all the submitted jobs completed and
#  $rest_interval2 seconds passed. ($rest_interval2 is set to $rest_interval if $rest_interval>0,
#  otherwise it is set to the default value)
sub initialize {
    my ($n_simul, $rest_count, $rest_interval) = @_; 
    if ($n_simul > 0 ) {
        $Use_simul_guard = 1;
        $Smph = Coro::Semaphore->new($_[0]);
    }
    if ($rest_count > 0) {
        $Use_rest_guard = 1;
        $Rest_activated = 0;
        $Rest_signal = new Coro::Signal();
        $Rest_count = $rest_count;
        if ($rest_interval > 0 ) {
            $Rest_interval = $rest_interval;
        }
    }
    $N_submitted_jobs = 0;
    $N_finished_jobs = 0;
}

### Private methods
## Xcrypt special methods
sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub initially {
    if ($Use_simul_guard) { $Smph->down; }
    if ($Use_rest_guard) { wait_rest_guard(); }
    $N_submitted_jobs++;
    if ($Use_rest_guard) { activate_rest_guard_if_needed(); }
}

sub finally {
    if ($Use_simul_guard) { $Smph->up; }
    $N_finished_jobs++;
    if ($Use_rest_guard) { spawn_deactivate_timer_if_needed(); }
}

1;
