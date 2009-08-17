package limit;

use strict;
use NEXT;
use Thread::Semaphore;

our $smph;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    if ($self->{limit} eq '') { $self->{limit} = 100; }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->before();
    $self->NEXT::start();
    $self->after();
}

sub before {
    my $self = shift;
    $smph->down;
    $self->NEXT::before();
}

sub after {
    my $self = shift;
    $self->NEXT::after();
    $smph->up;
}

1;
