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

sub after {
    my $self = shift;
    if ($self->{successor}) {
	my @jobs;
	foreach (@{$self->{successor}}) {
	    no strict 'refs';
	    my $tmp = 'user::' . $_;
	    my %template = %$tmp;
	    delete $template{successor};
	    my @job = &prepare_submit(%template);
	    push(@jobs, $job[0]);
	}
	&sync(@jobs);
    }
}

1;
