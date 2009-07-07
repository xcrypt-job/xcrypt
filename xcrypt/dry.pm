package dry;

use NEXT;

$dry;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
#    my $self = $class->NEXT::new();
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {
    my $self = shift;
    if ($user::opt_dry) {
	$self->{exe} = '';
	for ( my $i = 0; $i <= 255; $i++ ) {
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
