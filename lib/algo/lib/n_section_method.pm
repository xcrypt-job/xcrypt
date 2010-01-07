package n_section_method;

use base qw(Exporter);
use jobsched;
use builtin;
our @EXPORT = qw(n_section_method);
our $del_extra_jobs = 0;
&addkeys('x','partition','x_left','y_left','x_right','y_right','epsilon','pre','post');
my $infinity = (2 ** 31) + 1;
my %result;
my %jobs;
my $slp = 3;
sub n_section_method {
    my %hoge = @_;
    my $num = $hoge{'partition'};
    my $lt_k = $hoge{'x_left'};
    my $lt = $hoge{'y_left'};
    my $rt_k = $hoge{'x_right'};
    my $rt = $hoge{'y_right'};
    my $pt_k;
    my $pt;
    my %finished_or_deleted;
    my $count = -1;
    do {
	$count++;
	%result = ();
	$seg = ($rt_k - $lt_k) / $num;
	foreach my $i (1..($num-1)) {
	    $pt_k = $lt_k + ($i * $seg);
	    $result{"$pt_k"} = undef;
	    my %job = %hoge;
	    $job{'id'} = $hoge{'id'} . '_' . $count . '_' . $pt_k;
	    $job{'x'} = $pt_k;
	    $jobs{"$pt_k"} = \%job;
	    &{$hoge{'pre'}}(%job);
	}
	if ($del_extra_jobs == 1) {
	    my $flag = 0;
	    until ($flag == 1) {
		sleep $slp;
		foreach my $k (keys(%result)) {
		    my $hash = $jobs{"$k"};
		    my %job = %$hash;
#print "job" . %job, "\n";
		    my $status = &jobsched::get_job_status($job{'id'});
		    if (($status eq 'finished') &&
			($finished_or_deleted{"$k"} == 0)) {
			$result{"$k"} = &{$hoge{'post'}}(%job);
			foreach my $l (keys(%result)) {
			    if (0 < $result{"$k"} * ($rt - $lt) * ($l - $k) &&
				($finished_or_deleted{"$l"} == 0)) {
				my $hash = $jobs{"$l"};
				my %job = %$hash;
				my $jobid = $job{'id'};
				if ($jobid) {
				    qx/xcryptdel $jobid/;
#				&jobsched::qdel($jobid);
				    $finished_or_deleted{"$l"} = 1;
				    if (0 < $result{"$k"}) {
					$result{"$l"} = $infinity;
				    } else {
					$result{"$l"} = 0 - $infinity;
				    }
				}
			    }
			}
			$finished_or_deleted{"$k"} = 1;
		    }
		}
		$flag = 1;
		foreach my $k (keys(%result)) {
		    if ($finished_or_deleted{"$k"} == 0) {
			$flag = 0 * $flag;
		    }
		}
	    }
	} else {
	    foreach my $k (keys(%result)) {
		my $hash = $jobs{"$k"};
		my %job = %$hash;
		$result{"$k"} = &{$hoge{'post'}}(%job);
	    }
	}
	foreach (%result) {
	    print $_, "\n";
	}
	($lt_k, $lt, $rt_k, $rt) = across_zero($lt_k, $lt, $rt_k, $rt, %result);
	if (abs($lt) < abs($rt)) {
	    $pt_k = $lt_k;
	    $pt = $lt;
	} else {
	    $pt_k = $rt_k;
	    $pt = $rt;
	}
    } until (abs($pt) < $hoge{'epsilon'});
    return ($pt_k, $pt);
}

sub across_zero {
    my $lt_k = shift;
    my $lt = shift;
    my $rt_k = shift;
    my $rt = shift;
    my %arg = @_;
    foreach my $i (keys(%arg)) {
	if ($lt * $arg{"$i"} < 0) {
	    if ($i < $rt_k) {
		$rt_k = $i;
		$rt = $arg{"$i"};
	    }
	} else {
	    if ($lt_k < $i) {
		$lt_k = $i;
		$lt = $arg{"$i"};
	    }
	}
    }
    return ($lt_k, $lt, $rt_k, $rt);
}

1;
