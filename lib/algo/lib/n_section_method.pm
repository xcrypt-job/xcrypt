package n_section_method;

use base qw(Exporter);
our @EXPORT = qw(n_section_method);

my $infinity = (2 ** 31) + 1;
sub n_section_method {
    my ($num, $lt_k, $lt, $rt_k, $rt, $epsilon, $fun) = @_;
    my %values;
    my $pt_k;
    my $pt;
    do {
	$seg = ($rt_k - $lt_k) / $num;
	my @thrds;
	foreach (1..($num-1)) {
	    $pt_k = $lt_k + ($_ * $seg);
	    $thrds[$_] = threads->new( \&$fun, $pt_k );
	}
	foreach (1..($num-1)) {
	    $pt_k = $lt_k + ($_ * $seg);
	    $values{"$pt_k"} = $thrds[$_]->join;
	}
	($lt_k, $lt, $rt_k, $rt) = pair_near_zero($lt_k, $lt, $rt_k, $rt, %values);
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

sub pair_near_zero {
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
