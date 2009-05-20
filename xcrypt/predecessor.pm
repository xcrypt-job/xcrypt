package predecessor;

use base qw(limit);
use jobsched;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    my $obj = shift;
    $self->{predecessors} = $obj->{predecessors};
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    foreach (@{$self->{predecessors}}) {
	&jobsched::wait_job_done($_);
    }
    $self->SUPER::before();
}

sub after {
    my $self = shift;
    $self->SUPER::after();
}

1;
