package successor;

use threads;
use threads::shared;
use function;
use base qw(refinement);

my $traceslog_file = 'traces.log';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    my $obj = shift;
    $self->{successors} = $obj->{successors};
    $self->{trace} = $obj->{trace};
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    $self->SUPER::before();
}

sub after {
  my $self = shift;
  my $thrd;
  my $thrd_card : shared = 0;

  $self->SUPER::after();

  my $successor_card = @{$self->{successors}};
  if ($successor_card == 0) {
      open ( TRACE , ">> $traceslog_file" );
      print TRACE join (' ', @{$self->{trace}}), "\n";
      close ( TRACE );
  }
  foreach (@{$self->{successors}}) {
      my $foo = 'user::' . $_;
      my $bar = $$foo;
      my $obj = user->new($bar);
      $thrd[$thrd_card] = threads->new(\&start, $obj);
      $thrd_card++;
  }
  for (my $k = 0; $k < $thrd_card; $k++) {
      $thrd[$k]->join;
  }
}

1;
