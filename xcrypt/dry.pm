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
	$self->{arg1} = '';
	$self->{arg2} = '';
	$self->{input_filename} = '';
	$self->{output_filename} = '';
	$self->{exit_cond} = sub { 1; };
    }
    $self->SUPER::before();
}

sub after {
  my $self = shift;
  $self->SUPER::after();
}

1;
