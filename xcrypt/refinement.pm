package refinement;

use function;
use base qw(dry);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    my $obj = shift;
    $self->{cnvg} = $obj->{cnvg};
    $self->{exit_cond} = $obj->{exit_cond};
    $self->{change_arg1} = $obj->{change_arg1};
    $self->{change_arg2} = $obj->{change_arg2};
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

  $self->SUPER::after();

  until (&{$self->{exit_cond}}(@{$self->{trace}})) {
      my $foo = 'user::' . $self->{cnvg};
      my $bar = $$foo;
      my $obj = user->new($bar);
      $obj->{id} = $obj->{id} . '_';
      $obj->{arg1} = &{$self->{change_arg1}}($obj->{arg1});
      $obj->{arg2} = &{$self->{change_arg2}}($obj->{arg2});
      $obj->{exit_cond} = sub { &function::tautology };
      $obj->{trace} = $self->{trace};
      #（未実装）change_input_file で input_file を更新
      &start($obj);
      $self->{trace} = $obj->{trace};
  }
}

1;
