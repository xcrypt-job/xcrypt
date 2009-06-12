package predecessor;

use base qw(limit);
use jobsched;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    foreach (@{$self->{predecessor}}) {
	&jobsched::wait_job_done($_);
    }
    $self->SUPER::before();
}

sub after {
    my $self = shift;
    $self->SUPER::after();
}

1;
