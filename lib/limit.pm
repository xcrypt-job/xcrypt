package limit;

use strict;
use Coro;
use Coro::Semaphore;

# my $smph : shared = 100;
my $smph = Coro::Semaphore->new(100);

sub initialize {
    # $smph= $_[0];
    $smph = Coro::Semaphore->new($_[0]);
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

# sub before_isready {
#     return ($smph>0);
# }

sub before {
    # $smph--;
    $smph->down;
}

sub after {
    # $smph++;
    $smph->up;
}

1;
