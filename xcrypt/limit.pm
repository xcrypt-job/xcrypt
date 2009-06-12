package limit;

use Thread::Semaphore;

use base qw(top);

$smph;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    if ($self->{limit} eq '') { $self->{limit} = 100; }
    return bless $self, $class;
}

sub start {
    my $self = shift;
#    $smph = Thread::Semaphore->new($self->{limit});
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    $smph->down;
#    print "The semaphore is down.\n";
    $self->SUPER::before();
}

sub after {
    my $self = shift;
    $self->SUPER::after();
    $smph->up;
#    print "The semaphore is up.\n";
}

1;
