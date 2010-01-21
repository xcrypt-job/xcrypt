package successor;

use strict;
use NEXT;
use builtin;

&addkeys('successors');

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

sub before {
    my $self = shift;
}

sub after {
    my $self = shift;
    if ($self->{'successors'}) {
	my @objs;
	foreach (@{$self->{'successors'}}) {
	    print "hoge\n";
	    no strict 'refs';
	    my $foo = 'user::' . $_;
	    my %bar = %$foo;
	    delete $bar{'successors'};
	    my @job = &prepare(%bar);
	    &submit(@job);
	    push(@objs, $job[0]);
	}
	&sync(@objs);
    }
}

1;
