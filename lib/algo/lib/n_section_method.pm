package n_section_method;

use base qw(Exporter);
use threads;
use threads::shared;
use jobsched;
our @EXPORT = qw(n_section_method);

our %result : shared;
our %id : shared;

my $infinity = (2 ** 31) + 1;
sub n_section_method {
    my ($num, $lt_k, $lt, $rt_k, $rt, $epsilon, $fun) = @_;
    my $pt_k;
    my $pt;
    my %thrd;
    my %joined_or_detached;
    do {
	%result = ();
	$seg = ($rt_k - $lt_k) / $num;
	foreach (1..($num-1)) {
	    $pt_k = $lt_k + ($_ * $seg);
	    $result{"$pt_k"} = undef;
	}
	foreach (1..($num-1)) {
	    $pt_k = $lt_k + ($_ * $seg);
	    $thrd{"$pt_k"} = threads->new( \&$fun, $pt_k );
	}
	my $flag = 0;
	until ($flag == 1) {
	    sleep(3);
	    foreach my $k (keys(%result)) {
		if ((defined $result{"$k"})
		    && ($result{"$k"} != $infinity)
		    && ($result{"$k"} != 0 - $infinity)) {
		    foreach my $l (keys(%result)) {
			if (0 < $result{"$k"} * ($rt - $lt) * ($l - $k)) {
			    if ($joined_or_detached{"$l"} == 0) {
				my $jobid = $id{"$l"};
				if ($jobid) {
				    qx/xcryptdel $jobid/;
#				    &jobsched::qdel($jobid);
				    $thrd{"$l"}->detach;
				    $joined_or_detached{"$l"} = 1;
				    if (0 < $result{"$k"}) {
					$result{"$l"} = $infinity;
				    } else {
					$result{"$l"} = 0 - $infinity;
				    }
				}
			    }
			}
		    }
		    if ($joined_or_detached{"$k"} == 0) {
			$thrd{"$k"}->join;
			$joined_or_detached{"$k"} = 1;
		    }
		}
	    }
	    $flag = 1;
	    foreach my $k (keys(%result)) {
		if (defined $result{"$k"}) {
		} else {
		    $flag = 0 * $flag;
		}
	    }
	}

#	foreach my $k (keys(%result)) {
#	    print $k . '_' . $result{"$k"} . "\n";
#	}

	($lt_k, $lt, $rt_k, $rt) = across_zero($lt_k, $lt, $rt_k, $rt, %result);
	if (abs($lt) < abs($rt)) {
	    $pt_k = $lt_k;
	    $pt = $lt;
	} else {
	    $pt_k = $rt_k;
	    $pt = $rt;
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
