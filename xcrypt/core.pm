package core;

use base qw(graph);

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
    $self->SUPER::before();
}

sub after {
    my $self = shift;
    $self->SUPER::after();
}

1;
