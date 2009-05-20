package dry;

use base qw(predecessor);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    my $obj = shift;
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    if ($xcrypt::opt_dry) {
	$self->{exe} = '';
	$self->{arg1} = '';
	$self->{arg2} = '';
	$self->{input_file} = '';
	$self->{output_file} = '';
	$self->{exit_cond} = sub { &function::tautology; };
    }
    $self->SUPER::before();
}

sub after {
  my $self = shift;
  $self->SUPER::after();
}

1;
