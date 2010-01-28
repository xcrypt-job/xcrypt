package dry;

use strict;
use NEXT;
use builtin;

&add_key('dry');

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
    if ($self->{'dry'} == 1) {
	$self->{'exe'} = '';
	for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
	    my $arg = 'arg' . $i;
	    $self->{$arg} = '';
	}
    }
    # $self->NEXT::before();
}

sub after {
  # my $self = shift;
  # $self->NEXT::after();
}

1;
