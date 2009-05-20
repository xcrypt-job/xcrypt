package limit;

use Thread::Semaphore;

use base qw(process);

$smph;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    my $obj = shift;
    $self->{limit} = $obj->{limit};
    return bless $self, $class;
}

sub start {
    my $self = shift;
#    $smph = Thread::Semaphore->new($self->{limit});
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    print "The semaphore is down.\n";
    $smph->down;
    $self->SUPER::before();
}

sub after {
    my $self = shift;
    $self->SUPER::after();
    $smph->up;
    print "The semaphore is up.\n";
}

1;
