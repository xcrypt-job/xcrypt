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
    my %jobs = @_;
    if ($jobs{'arg1s'} eq '') {
	$jobs{'arg1s'} = sub { $jobs{'arg1'}; };
    }
    if ($jobs{'arg2s'} eq '') {
	$jobs{'arg2s'} = sub { $jobs{'arg2'}; };
    }
    if ($jobs{'ifiles'} eq '') {
	$jobs{'ifiles'} = sub { $jobs{'ifile'}; };
    }
    my @objs;
    foreach (@{$jobs{'range'}}) {
	my %job = %jobs;
	$job{'id'} = $jobs{'id'} . '_' . $_;
	$job{'arg1'} = &{$jobs{'arg1s'}}($_);
	$job{'arg2'} = &{$jobs{'arg2s'}}($_);
	$job{'ifile'} = &{$jobs{'ifiles'}}($_);
	my $obj = user->new(\%job);
	push(@objs , $obj);
    }
    return @objs;
}

sub prepare_directory {
    my %jobs = @_;
    opendir(DIR, $jobs{'arg1idir'});
    my @files = grep { !m/^(\.|\.\.)$/g } readdir(DIR);
    closedir(DIR);
    my @objs;
    foreach (@files) {
	my %job = %jobs;
	$job{'id'} = $jobs{'id'} . '_' . $_;
	$job{'arg1'} = $_;
	$job{'ifile'} = $_;
	my $obj = user->new(\%job);
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
