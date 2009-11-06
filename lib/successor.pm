package successor;

use strict;
use NEXT;
use builtin;

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
    foreach (@{$self->{':successors'}}) {
	no strict 'refs';
	my $foo = 'user::' . $_;
	my %bar = %$foo;
	my @jobs = &prepare(%bar);
#	&submit(@jobs);
	# 自前でsubmit
	foreach (@jobs) {
	    &user::before($_);
	    &user::start($_);
	}
	push(@objs, @jobs);
    }

    # 自前でafter
    foreach my $self (@objs) {
	&jobsched::wait_job_done ($self->{'id'});
#		my $stat = &jobsched::get_job_status($self->{'id'});
#		if ($stat eq 'done') {
#		    print $self->{'id'} . "\'s post-processing finished.\n";
	$self->after();
	until ((-e "$self->{'id'}/$self->{'stdofile'}")
	       && (-e "$self->{'id'}/$self->{'stdefile'}")) {
	    sleep(1);
	}
	&jobsched::inventory_write($self->{'id'}, "finished");
#		}
    }

    &sync(@objs);
    $self->NEXT::after();
}

1;
