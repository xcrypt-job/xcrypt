package n_section_method;

use base qw(Exporter);
use jobsched;
use builtin;
our @EXPORT = qw(n_section_method);
our $del_extra_jobs = 0;
&addkeys('param');
my $infinity = (2 ** 31) + 1;
my %result;
my %jobs;
sub n_section_method {
    my ($obj, $num, $lt_k, $lt, $rt_k, $rt, $epsilon, $submit, $sync) = @_;
    my $pt_k;
    my $pt;
    my %finishded_or_deleted;
    my $count = -1;
    do {
	$count++;
	%result = ();
	$seg = ($rt_k - $lt_k) / $num;
	foreach my $i (1..($num-1)) {
	    $pt_k = $lt_k + ($i * $seg);
	    $result{"$pt_k"} = undef;
	    my %tmp = %$obj;
	    my %job = %tmp;
	    $job{'id'} = $obj->{'id'} . '_' . $count . '_' . $pt_k;
	    $job{'param'} = $pt_k;
	    $jobs{"$pt_k"} = \%job;
	    &$submit(\%job);
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
				my $hash = $jobs{"$l"};
				my %job = %$hash;
				my $jobid = $job{'id'};
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
		$pt_k = $lt_k + ($i * $seg);
		my $hash = $jobs{"$pt_k"};
		my %job = %$hash;
		$result{"$pt_k"} = &$sync(\%job);
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
    my $lt_k = shift;
    my $lt = shift;
    my $rt_k = shift;
    my $rt = shift;
    my %arg = @_;
    my $min = 0 - $infinity;
    my $max = $infinity;
    foreach (keys(%arg)) {
	if ($lt * $arg{"$_"} < 0) {
	    if ($_ < $rt_k) {
		$rt_k = $_;
		$rt = $arg{"$_"};
	    }
	} else {
	    if ($lt_k < $_) {
		$lt_k = $_;
		$lt = $arg{"$_"};
	    }
	}
    }
    return ($lt_k, $lt, $rt_k, $rt);
}

1;
