package GA;

use strict;
use NEXT;
use File::Spec;
use File::Path;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    $self->{exe0} = File::Spec->catfile($ENV{XCRYPT}, 'lib', 'algo', 'bin', 'GA');
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {
    # my $self = shift;
    # $self->NEXT::before();
}

sub after {
    # my $self = shift;
    # $self->NEXT::after();
}

1;
