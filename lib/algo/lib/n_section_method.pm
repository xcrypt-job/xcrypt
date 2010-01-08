package n_section_method;

use base qw(Exporter);
use jobsched;
use builtin;
use threads;
use threads::shared;
our @EXPORT = qw(n_section_method);
our $del_extra_jobs = 0;
&addkeys('x','y','partition','x_left','y_left','x_right','y_right','epsilon');
my $infinity = (2 ** 31) + 1;
our %result : shared;
my $slp = 3;
sub n_section_method {
    my %obj = @_;
    my $num = $obj{'partition'};
    my $x_left = $obj{'x_left'};
    my $y_left = $obj{'y_left'};
    my $x_right = $obj{'x_right'};
    my $y_right = $obj{'y_right'};
    my $x;
    my $y;
    my %done_or_deleted;
    my $count = -1;
    do {
	$count++;
	%result = ();
	$seg = ($x_right - $x_left) / $num;
	my @jobs;
	foreach my $i (1..($num-1)) {
	    $x = $x_left + ($i * $seg);
	    $result{"$x"} = undef;
	    my %job = %obj;
	    $job{'id'} = $obj{'id'} . '_' . $count . '_' . $x;
	    $job{'x'} = $x;
	    my @tmp = &prepare(%job);
	    push(@jobs, $tmp[0]);
	}
	&submit(@jobs);

=comment
	    foreach (%result) {
		print $_, "\n";
	    }
=cut
	&sync(@jobs);
	($x_left, $y_left, $x_right, $y_right)
	    = across_zero($x_left, $y_left, $x_right, $y_right, %result);
	if (abs($y_left) < abs($y_right)) {
	    $x = $x_left;
	    $y = $y_left;
	} else {
	    $x = $x_right;
	    $y = $y_right;
	}
    } until (abs($y) < $obj{'epsilon'});
    return ($x, $y);
}

sub across_zero {
    my $x_left = shift;
    my $y_left = shift;
    my $x_right = shift;
    my $y_right = shift;
    my %arg = @_;
    foreach my $i (keys(%arg)) {
	if ($y_left * $arg{"$i"} < 0) {
	    if ($i < $x_right) {
		$x_right = $i;
		$y_right = $arg{"$i"};
	    }
	} else {
	    if ($x_left < $i) {
		$x_left = $i;
		$y_left = $arg{"$i"};
	    }
	}
    }
    return ($x_left, $y_left, $x_right, $y_right);
}

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
}

sub after {
}

1;
