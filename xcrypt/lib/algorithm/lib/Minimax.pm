package Minimax;

use strict;
use NEXT;
use jobsched;
use Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use UI;
use function;
use Data_Generation;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    $self->{exe} = $ENV{XCRYPT} . '/lib/algorithm/bin/Minimax ';
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {
    my $self = shift;
    $self->NEXT::before();
}

sub after {
    my $self = shift;
    $self->NEXT::after();
}

sub getChildren {
    my $self = shift;

}

1;
