package GA;

use NEXT;
use base qw(Exporter);
@EXPORT = qw(toplevel manyPointCrossover isCongruentMax selection);

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    $self->{exe} = $self->{exe} . ' ' . $self->{GA_count}
                                . ' ' . $self->{GA_lengthOfStr}
                                . ' ' . $self->{GA_howToCrossover}
                                . ' ' . $self->{GA_howToSelect};
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

1;
