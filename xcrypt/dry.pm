package dry;

use base qw(predecessor);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    if ($user::opt_dry) {
	$self->{exe} = '';
	for ( my $i = 0; $i <= 255; $i++ ) {
	    my $arg = 'arg' . $i;
	    $self->{$arg} = '';
	}
#	$self->{copiedfile} = '';
	$self->{ofile} = '';
	$self->{exit_cond} = sub { 1; };
    }
    $self->SUPER::before();
}

sub after {
  my $self = shift;
  $self->SUPER::after();
}

1;
