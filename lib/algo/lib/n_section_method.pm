package n_section_method;

use base qw(Exporter);
use jobsched;
our @EXPORT = qw(n_section_method);

our %result;
our %id;
our $del_extra_jobs = 0;

my $infinity = (2 ** 31) + 1;
sub n_section_method {
    my ($num, $lt_k, $lt, $rt_k, $rt, $epsilon, $submit, $sync) = @_;
    my $pt_k;
    my $pt;
    my %finishded_or_deleted;
    my $count = -1;
    do {
	$count++;
	%result = ();
	$seg = ($rt_k - $lt_k) / $num;
	foreach (1..($num-1)) {
	    $pt_k = $lt_k + ($_ * $seg);
	    $result{"$pt_k"} = undef;
	}
	foreach my $i (1..($num-1)) {
	    my $lpt_k = $lt_k + ($i * $seg);
	    &$submit($lpt_k, $count);
	}

	if ($del_extra_jobs == 1) {
	    my $flag = 0;
	    until ($flag == 1) {
		sleep(3);
		foreach my $k (keys(%result)) {
		    if ((defined $result{"$k"}) &&
			($finishded_or_deleted{"$k"} == 0)) {
			foreach my $l (keys(%result)) {
			    if (0 < $result{"$k"} * ($rt - $lt) * ($l - $k) &&
				($finishded_or_deleted{"$l"} == 0)) {
				my $jobid = $id{"$l"};
				if ($jobid) {
				    qx/xcryptdel $jobid/;
#				&jobsched::qdel($jobid);
				    $finishded_or_deleted{"$l"} = 1;
				    if (0 < $result{"$k"}) {
					$result{"$l"} = $infinity;
				    } else {
					$result{"$l"} = 0 - $infinity;
				    }
				}
			    }
			}
			if ($finishded_or_deleted{"$k"} == 0) {
			    $finishded_or_deleted{"$k"} = 1;
			}
		    }
		}
		$flag = 1;
		foreach my $k (keys(%result)) {
		    if ($finishded_or_deleted{"$k"} == 0) {
			$flag = 0 * $flag;
		    }
		}
	    }
	} else {
	    foreach my $i (1..($num-1)) {
		my $lpt_k = $lt_k + ($i * $seg);
		&$sync($lpt_k, $count);
	    }
	    ($lt_k, $lt, $rt_k, $rt) = across_zero($lt_k, $lt, $rt_k, $rt, %result);
	    if (abs($lt) < abs($rt)) {
		$pt_k = $lt_k;
		$pt = $lt;
	    } else {
		$pt_k = $rt_k;
		$pt = $rt;
	    }
	}
    } until (abs($pt) < $epsilon);
    return ($pt_k, $pt);
}

sub across_zero {
    my %arg = @_;
    my $min_k;
    my $max_k;
    my $min = 0 - $infinity;
    my $max = $infinity;
    foreach (keys(%arg)) {
	if ($arg{"$_"} < 0) {
	    if ($min < $arg{"$_"}) {
		$min_k = $_;
		$min = $arg{"$_"};
	    }
	} else {
	    if ($arg{"$_"} < $max) {
		$max_k = $_;
		$max = $arg{"$_"};
	    }
	}
    }
    if ($min_k < $max_k) {
	return ($min_k, $min, $max_k, $max);
    } else {
	return ($max_k, $max, $min_k, $min);
    }
}

1;
