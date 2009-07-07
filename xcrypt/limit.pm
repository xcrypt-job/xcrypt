package limit;

use NEXT;
use Thread::Semaphore;

$smph;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    if ($self->{limit} eq '') { $self->{limit} = 100; }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
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
