package UI;

use File::Copy;
use function;

use base qw(Exporter);
@EXPORT = qw(killall pickup prepare_submit_sync prepare_submit submit_sync prepare prepare_directory submit kaishu sync);

sub killall {
    my $prefix = shift;
    foreach (@_) {
	my $id = $prefix . '_' . $_;
	my @list = &pickup("$id/request_id", ' ');
	my @revlist = reverse(@list);
#	system("qdel -k $revlist[4]");
	system("qdel $revlist[4]");
	system("pjo_inventory_write.pl inv_watch/$id \"done\" \"spec: $id\"");
    }
}

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

sub prepare_submit_sync {
    my @objs = &prepare(@_);
    my @thrds = &submit(@objs);
    return &sync(@thrds);
}

sub submit_sync {
    my @thrds = &submit(@_);
    return &sync(@thrds);
}

sub prepare_submit {
    my @objs = &prepare(@_);
    return &submit(@objs);
}

sub prepare {
    my %jg_rng_amp = @_;
    my $id = $jg_rng_amp{'id'};
    my @objs;
    if ($jg_rng_amp{'arg1s'} eq '') {
	$jg_rng_amp{'arg1s'} = sub { $jg_rng_amp{'arg1'}; };
    }
    if ($jg_rng_amp{'arg2s'} eq '') {
	$jg_rng_amp{'arg2s'} = sub { $jg_rng_amp{'arg2'}; };
    }
    if ($jg_rng_amp{'ifiles'} eq '') {
	$jg_rng_amp{'ifiles'} = sub { $jg_rng_amp{'ifile'}; };
    }
    foreach (@{$jg_rng_amp{'range'}}) {
	my %jobgraph = %jg_rng_amp;
	$jobgraph{'id'} = $id . '_' . $_;
	$jobgraph{'arg1'} = &{$jg_rng_amp{'arg1s'}}($_);
	$jobgraph{'arg2'} = &{$jg_rng_amp{'arg2s'}}($_);
	$jobgraph{'ifile'} = &{$jg_rng_amp{'ifiles'}}($_);
	my $obj = user->new(\%jobgraph);
	push(@objs , $obj);
    }
    return @objs;
}

sub prepare_directory {
    my %jg_rng_amp = @_;
    my $id = $jg_rng_amp{'id'};
    my @objs;
    opendir(DIR, $jg_rng_amp{'input_arg_dirname'});
    my @files = grep { !m/^(\.|\.\.)$/g } readdir(DIR);
    closedir(DIR);
    foreach (@files) {
	my %jobgraph = %jg_rng_amp;
	$jobgraph{'id'} = $id . '_' . $_;
	$jobgraph{'arg1'} = $_;
	$jobgraph{'ifile'} = $_;
	my $obj = user->new(\%jobgraph);
	    push(@objs , $obj);
    }
    return @objs;
}


sub submit {
    my @thrds = ();
    foreach (@_) {
	$_->{thrds} = \@thrds;
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
	my $outputfile = File::Spec->catfile($id . '_' . $_, $jg_rng_amp{'ofile'});
	my @list = &pickup($outputfile, $jg_rng_amp{'odelimiter'});
	push (@outputs , $list[$jg_rng_amp{'ocolumn'}]);
    }
    return @outputs;
}

1;
