package UI;

use function;

use base qw(Exporter);
@EXPORT = qw(pickup submit_sync submit kaishu sync);

sub pickup {
    open ( OUTPUT , "< $_[0]" );
    my $line;
    foreach (<OUTPUT>) {
	$line = $_;
    }
    $delimit = $_[1];
    my @list = split(/$delimit/, $line);
    close ( OUTPUT );
    return @list;
}

sub submit_sync {
    my @thrds = &submit(@_);
    return &sync(@thrds);
}

sub submit {
    my %jg_rng_amp = @_;
    my $id = $jg_rng_amp{'id'};
    my @outputs;
    my @thrds;
    if ($jg_rng_amp{'range1'} eq '') {
#	user->new(\%jg_rng_amp)->start;
	my $obj = user->new(\%jg_rng_amp);
	my $thrd = threads->new(\&user::start, $obj);
	push(@thrds , $thrd);
    } else {
	my @arg1s;
	foreach (@{$jg_rng_amp{'range1'}}) {
	    my $arg1;
	    if ($jg_rng_amp{'amp1'} eq '') {
		$arg1 = &identity($_);
	    } else {
		$arg1 = &{$jg_rng_amp{'amp1'}}($_);
	    }
	    push (@arg1s, $arg1);
	}
	foreach (@arg1s) {
	    my $jobgraph = \%jg_rng_amp;
	    $jobgraph->{id} = $id . '_' . $_;
	    $jobgraph->{arg1} = $_;
	    my $obj = user->new($jobgraph);
	    my $thrd = threads->new(\&user::start, $obj);
	    push(@thrds , $thrd);
	}
    }
    return @thrds;
}

sub sync {
    my @outputs;
    foreach (@_) {
	my $output = $_->join;
	push (@outputs , $output);
    }
    return @outputs;
}

sub kaishu {
    my %jg_rng_amp = @_;
    my $id = $jg_rng_amp{'id'};
    my @outputs;
    my @arg1s;
    foreach (@{$jg_rng_amp{'range1'}}) {
	my $arg1;
	if ($jg_rng_amp{'amp1'} eq '') {
	    $arg1 = &identity($_);
	} else {
	    $arg1 = &{$jg_rng_amp{'amp1'}}($_);
	}
	push (@arg1s, $arg1);
    }
    foreach (@arg1s) {
	my $outputfile = $id . '_' . $_ . '/' . $jg_rng_amp{'output_file'};
	my @list = &pickup($outputfile, $jg_rng_amp{'delimiter'});
	push (@outputs , $list[$jg_rng_amp{'output_column'}]);
    }
    return @outputs;
}

1;

