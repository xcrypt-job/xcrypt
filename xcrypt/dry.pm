package dry;

use strict;
use NEXT;

our $dry;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {
    my $self = shift;
    if ($dry) {
	$self->{exe} = '';
	for ( my $i = 0; $i <= $user::max; $i++ ) {
	    my $arg = 'arg' . $i;
	    $self->{$arg} = '';
	}
#	$self->{exit_cond} = sub { 1; };
    }
    $self->NEXT::before();
}

sub after {
  my $self = shift;
  $self->NEXT::after();
}

1;
