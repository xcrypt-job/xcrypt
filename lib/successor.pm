package successor;

use strict;
use NEXT;
use builtin;

&add_key('successor');

my $slp = 1;
sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {}

sub after {
    my $self = shift;
    if ($self->{successor}) {
	my @objs;
	foreach (@{$self->{successor}}) {
	    no strict 'refs';
	    my $foo = 'user::' . $_;
	    my %bar = %$foo;
	    delete $bar{successor};
	    my @job = &prepare(%bar);
	    push(@objs, $job[0]);
	}
	&submit(@objs);
	&sync(@objs);
    }
}

1;
