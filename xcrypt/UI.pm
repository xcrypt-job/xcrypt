package UI;

use function;

use base qw(Exporter);
@EXPORT = qw(pickup generate_submit_sync generate submit kaishu sync);

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

sub generate_submit_sync {
    my @objs = &generate(@_);
    my @thrds = &submit(@objs);
    return &sync(@thrds);
}

sub generate {
    my %jg_rng_amp = @_;
    my $id = $jg_rng_amp{'id'};
    my @outputs;
    my @objs;
    if ($jg_rng_amp{'range1'} eq '') {
#	user->new(\%jg_rng_amp)->start;
	my $obj = user->new(\%jg_rng_amp);
	push(@objs , $obj);
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
#	    my $jobgraph = \%jg_rng_amp;
	    my $jobgraph = {};
	    $jobgraph->{id} = $id . '_' . $_;
	    $jobgraph->{exe} = $jg_rng_amp{'exe'};
	    $jobgraph->{arg1} = $_;
	    $jobgraph->{input_filename} = $jg_rng_amp{'input_filename'};
	    $jobgraph->{output_filename} = $jg_rng_amp{'output_filename'};
	    $jobgraph->{output_column} = $jg_rng_amp{'output_column'};
	    $jobgraph->{delimiter} = $jg_rng_amp{'delimiter'};
	    $jobgraph->{queue} = $jg_rng_amp{'queue'};
	    $jobgraph->{option} = $jg_rng_amp{'option'};
	    $jobgraph->{before} = $jg_rng_amp{'before'};
	    $jobgraph->{after} = $jg_rng_amp{'after'};
	    my $obj = user->new($jobgraph);
	    push(@objs , $obj);
	}
    }
    return @objs;
}

sub submit {
    my @thrds;
    foreach (@_) {
	my $thrd = threads->new(\&user::start, $_);
	push(@thrds , $thrd);
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
	my $outputfile = $id . '_' . $_ . '/' . $jg_rng_amp{'output_filename'};
	my @list = &pickup($outputfile, $jg_rng_amp{'delimiter'});
	push (@outputs , $list[$jg_rng_amp{'output_column'}]);
    }
    return @outputs;
}

1;

