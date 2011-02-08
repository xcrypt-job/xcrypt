package n_section_method;

use Coro;
use Coro::AnyEvent;
use jobsched;
use builtin;

&add_key('x','y','partition','x_left','y_left','x_right','y_right','epsilon');

my $del_extra_jobs = 0;
sub del_extra_job {
    $del_extra_jobs = 1;
}
my $interval_check_done_or_ignored = 3;
my $inf = (2 ** 31) - 1;
sub n_section_method {
    my %arg = @_;
    my $num = $arg{'partition'};
    my $x_left = $arg{'x_left'};
    my $y_left = $arg{'y_left'};
    my $x_right = $arg{'x_right'};
    my $y_right = $arg{'y_right'};
    my $sgn = $y_right - $y_left;
    my $x;
    my $y;
    my $count = -1;
    do {
	$count++;
#	%result = ();
	$seg = ($x_right - $x_left) / $num;
	my @jobs;
	foreach my $i (1..($num-1)) {
	    $x = $x_left + ($i * $seg);
	    my %job = %arg;
	    $job{'id'} = $arg{'id'} . '_' . $count . '_' . $x;
	    $job{'x'} = $x;
	    my @tmp = &prepare(%job);
	    push(@jobs, $tmp[0]);
	}
	&submit(@jobs);

	if ($del_extra_jobs == 1) {
	    my $flag = 0;
	    until ($flag == 1) {
#		sleep $interval_check_done_or_ignored;
                Coro::AnyEvent::sleep $interval_check_done_or_ignored;
		foreach my $j (@jobs) {
		    my $status = &jobsched::get_job_status($j);
		    if ($status eq 'finished') {
			foreach my $l (@jobs) {
			    if (0 < $j->{'y'} * $sgn * ($l->{'x'} - $j->{'x'})){
		    my $stat = &jobsched::get_job_status($l);
unless ($stat eq 'finished') {
    $l->invalidate();
}
			    }
			}
		    }
		}
		$flag = 1;
		foreach my $j (@jobs) {
		    my $status = &jobsched::get_job_status($j);
		    unless ($status eq 'finished') {
#			print "$j->{id}: $status\n";
			$flag = 0 * $flag;
		    }
		}
	    }
	}
	&sync(@jobs);
	($x_left, $y_left, $x_right, $y_right)
	    = &across_zero($x_left, $y_left, $x_right, $y_right, @jobs);
print $x_left, "\n";
print $y_left, "\n";
print $x_right, "\n";
print $y_right, "\n";
	if (abs($y_left) < abs($y_right)) {
	    $x = $x_left;
	    $y = $y_left;
	} else {
	    $x = $x_right;
	    $y = $y_right;
	}
    } until (abs($y) < $arg{'epsilon'});
    return ($x, $y);
}

sub after {}

sub across_zero {
    my $x_left = shift;
    my $y_left = shift;
    my $x_right = shift;
    my $y_right = shift;
    my @jobs = @_;
    foreach my $i (@jobs) {
	unless ($i->{'y'} eq '') {
	    if ($y_left * ($i->{'y'}) < 0) {
		if ($i->{'x'} < $x_right) {
		    $x_right = $i->{'x'};
		    $y_right = $i->{'y'};
		}
	    } else {
		if ($x_left < $i->{'x'}) {
		    $x_left = $i->{'x'};
		    $y_left = $i->{'y'};
		}
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

sub before {}
sub after {}

1;
