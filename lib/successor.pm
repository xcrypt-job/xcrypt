package successor;

use strict;
use NEXT;
use builtin;

&addkeys('successors');

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {
    my $self = shift;
    $self->NEXT::before();
}

sub after {
    my $self = shift;
    my @objs;
    $self->NEXT::after();
    foreach (@{$self->{'successors'}}) {
	no strict 'refs';
	my $foo = 'user::' . $_;
	my %bar = %$foo;
	my @jobs = &prepare(%bar);
#	&submit(@jobs);
	# 自前でsubmit
	foreach my $job (@jobs) {
	    &jobsched::inventory_write($job->{'id'}, 'prepared');
	    &user::before($job);
	    &user::start($job);
	}
	push(@objs, @jobs);
    }

    # 自前でafter
    foreach my $job (@objs) {
	&jobsched::wait_job_done ($job->{'id'});
#		my $stat = &jobsched::get_job_status($job->{'id'});
#		if ($stat eq 'done') {
#		    print $job->{'id'} . "\'s post-processing finished.\n";
	$job->after();
	until ((-e "$job->{'id'}/$job->{'stdofile'}")
	       && (-e "$job->{'id'}/$job->{'stdefile'}")) {
	    sleep(1);
	}
	&jobsched::inventory_write($job->{'id'}, "finished");
#		}
    }
    # 自前でsync
    &sync(@objs);
}

1;
