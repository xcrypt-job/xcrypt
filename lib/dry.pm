package dry;

use strict;
use NEXT;
use builtin;

&add_key('dry');

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
    if ($self->{dry} == 1) {
	foreach my $key (keys(%$self)) {
            if ($key =~ /\Aexe[0-9]+\Z/) {
		$self->{$key} = ' ';
	    }
            if ($key =~ /\Aarg[0-9]+_[0-9]+\Z/) {
		$self->{$key} = ' ';
	    }
        }
    }
}

sub after {
}

1;
