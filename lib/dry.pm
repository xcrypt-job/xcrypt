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
	for ( my $i = 0; $i <= $user::max_exe_etc; $i++ ) {
            $self->{"exe$i"} = '';
            for ( my $j = 0; $j <= $user::max_arg; $j++ ) {
                my $arg = "arg$i_$j";
                $self->{$arg} = '';
            }
        }
    }
}

sub after {
}

1;
