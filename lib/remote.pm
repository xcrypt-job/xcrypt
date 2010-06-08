package remote;

use strict;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);

    if (defined $xcropt::options{rhost}) {
	$self->{host} = $xcropt::options{rhost};
    }
    if (defined $xcropt::options{rwd}) {
	$self->{wd} = $xcropt::options{rwd};
    }

    my $sched = qx/$xcropt::options{rsh} $self->{host} 'echo \$XCRJOBSCHED'/;
    chomp($sched);
    unless ($sched eq '') {
	$self->{scheduler} = $sched;
    } else {
	die "Set the environment varialble \$XCRJOBSCHED at $self->{host}\n";
    }

    my $tmp = qx/$xcropt::options{rsh} $self->{host} 'echo \$XCRYPT'/;
    chomp($tmp);
    unless ($tmp eq '') {
	$self->{xd} = $tmp;
    } else {
	die "Set the environment varialble \$XCRYPT at $self->{host}\n";
    }

    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {}
sub after {}

1;
