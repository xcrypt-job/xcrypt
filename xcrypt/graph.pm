package graph;

use threads;
use threads::shared;
use function;
use base qw(limit);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
#    if ($self->{successor} eq '') { $self->{successor} = []; }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->SUPER::start();
}

sub before {
    my $self = shift;
    foreach (@{$self->{predecessor}}) {
	&jobsched::wait_job_done($_);
    }
    $self->SUPER::before();
}

sub after {
  my $self = shift;
  $self->SUPER::after();
#  my $successor_card = @{$self->{successor}};
#  my $traceslog_file = 'traces.log';
#  if ($successor_card == 0) {
#      open ( TRACE , ">> $traceslog_file" );
#      print TRACE join (' ', @{$self->{trace}}), "\n";
#     close ( TRACE );
#  }
  my @thrds = ();
  foreach (@{$self->{successor}}) {
      my $foo = 'user::' . $_;
      my %bar = %$foo;
      my $obj = user->new(\%bar);
      my $thrd = threads->new(\&start, $obj);
      push(@thrds , $thrd);
  }
  foreach (@thrds) { $_->join; }
}

1;
