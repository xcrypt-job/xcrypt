package n_section_method;

use jobsched;
use builtin;
use threads;
use threads::shared;

&addkeys('x','y','partition','x_left','y_left','x_right','y_right','epsilon');

our $del_extra_jobs = 0;
our %result : shared;

my $interval_check_done_or_ignored = 3;
sub n_section_method {
    my %arg = @_;
    my $num = $arg{'partition'};
    my $x_left = $arg{'x_left'};
    my $y_left = $arg{'y_left'};
    my $x_right = $arg{'x_right'};
    my $y_right = $arg{'y_right'};
    my $inc_or_dec = $y_right - $y_left;
    my $x;
    my $y;
    my %done_or_ignored;
    my $count = -1;
    do {
	$count++;
	%result = ();
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
		sleep $interval_check_done_or_ignored;
		foreach my $j (@jobs) {
		    my $jx = $j->{'x'};
		    my $jid = $j->{'id'};
		    my $status = &jobsched::get_job_status($jid);
		    if ($status eq 'done' && ($done_or_ignored{"$jid"} == 0)) {
			&sync($j);
			$done_or_ignored{"$jid"} = 1;
			foreach my $k (@jobs) {
			    my $kid = $k->{'id'};
			    if (0 < $result{"$jx"} * $inc_or_dec * ($k->{'x'} - $j->{'x'}) && ($done_or_ignored{"$kid"} == 0)) {
				if ($kid) {
				    system("xcryptdel $kid");
#				    &jobsched::qdel($jobid);
				    $done_or_ignored{"$kid"} = 1;
				}
			    }
			}
		    }
		}
		$flag = 1;
		foreach my $j (@jobs) {
		    my $jid = $j->{'id'};
		    if ($done_or_ignored{"$jid"} == 0) {
			$flag = 0 * $flag;
		    }
		}
	    }
	} else {
	    &sync(@jobs);
	}
#	foreach(%result) {
#	    print $_, "\n";
#	}
	($x_left, $y_left, $x_right, $y_right)
	    = &across_zero($x_left, $y_left, $x_right, $y_right, %result);
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

sub before {}
sub after {}

1;
