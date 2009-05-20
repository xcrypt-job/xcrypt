package constructor;

use base qw(successor);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
#    my $self = $class->SUPER::new();
    my $obj = shift;
    $self->{id} = $obj->{id};
    $self->{exe} = $obj->{exe};
    $self->{arg1} = $obj->{arg1};
    $self->{arg2} = $obj->{arg2};
    $self->{trace} = $obj->{trace};
    $self->{after_process} = $obj->{after_process};
    if ($obj->{exit_cond} eq '') {
	$self->{exit_cond} = sub { &function::tautology; };
    }
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
    eval ($self->{after_process});
}

1;
