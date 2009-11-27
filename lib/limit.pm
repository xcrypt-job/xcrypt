package limit;

use strict;
use threads;
use threads::shared;

my $smph : shared = 100;

sub initialize {
    $smph= $_[0];
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

sub before_isready {
    return ($smph>0);
}

sub before {
    $smph--;
}

sub after {
    # my $self = shift;
    # $self->NEXT::after();
    $smph++;
}

1;
