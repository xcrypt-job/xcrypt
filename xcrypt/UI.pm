package UI;

use File::Copy;
use function;

use base qw(Exporter);
@EXPORT = qw(killall pickup prepare_submit_sync prepare_submit submit_sync prepare submit kaishu sync);


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

sub generate {
    my %tmp = %{$_[0]};
    my %job = %tmp;
    unless ($_[2]) {
	$job{'id'} = $_[0]{'id'} . '_' . $_[1];
    } else {
	$job{'id'} = $_[0]{'id'} . '_' . $_[1] . '-' . $_[2];
    }
    $job{'exe'}      = &{$_[0]{'exes'}}($_[1], $_[2]);
    $job{'arg1'}     = &{$_[0]{'arg1s'}}($_[1], $_[2]);
    $job{'arg2'}     = &{$_[0]{'arg2s'}}($_[1], $_[2]);
    $job{'ifile'}    = &{$_[0]{'ifiles'}}($_[1], $_[2]);
    $job{'ofile'}    = &{$_[0]{'ofiles'}}($_[1], $_[2]);
    $job{'oclmn'}    = &{$_[0]{'oclmns'}}($_[1], $_[2]);
    $job{'odlmtr'}   = &{$_[0]{'odlmtrs'}}($_[1], $_[2]);
    $job{'queue'}    = &{$_[0]{'queues'}}($_[1], $_[2]);
    $job{'option'}   = &{$_[0]{'options'}}($_[1], $_[2]);
    $job{'stdofile'} = &{$_[0]{'stdofiles'}}($_[1], $_[2]);
    $job{'stdefile'} = &{$_[0]{'stdefiles'}}($_[1], $_[2]);
    $job{'proc'}     = &{$_[0]{'procs'}}($_[1], $_[2]);
    $job{'cpu'}      = &{$_[0]{'cpus'}}($_[1], $_[2]);
    return user->new(\%job);
}

sub prepare {
    my %jobs = @_;
    unless ($jobs{'exes'})      {$jobs{'exes'}      = sub {$jobs{'exe'};};}
    unless ($jobs{'arg1s'})     {$jobs{'arg1s'}     = sub {$jobs{'arg1'};};}
    unless ($jobs{'arg2s'})     {$jobs{'arg2s'}     = sub {$jobs{'arg2'};};}
    unless ($jobs{'ifiles'})    {$jobs{'ifiles'}    = sub {$jobs{'ifile'};};}
    unless ($jobs{'ofiles'})    {$jobs{'ofiles'}    = sub {$jobs{'ofile'};};}
    unless ($jobs{'oclmns'})    {$jobs{'oclmns'}    = sub {$jobs{'oclmn'};};}
    unless ($jobs{'odlmtrs'})   {$jobs{'odlmtrs'}   = sub {$jobs{'odlmtr'}};}
    unless ($jobs{'queues'})    {$jobs{'queues'}    = sub {$jobs{'queue'};};}
    unless ($jobs{'options'})   {$jobs{'options'}   = sub {$jobs{'option'};};}
    unless ($jobs{'stdofiles'}) {$jobs{'stdofiles'} = sub {$jobs{'stdofile'};};}
    unless ($jobs{'stdefiles'}) {$jobs{'stdefiles'} = sub {$jobs{'stdefile'};};}
    unless ($jobs{'procs'})     {$jobs{'procs'}     = sub {$jobs{'proc'};};}
    unless ($jobs{'cpus'})      {$jobs{'cpus'}      = sub {$jobs{'cpu'};};}
    my @objs;
    if ($jobs{'range1'}) {
	foreach my $r1 (@{$jobs{'range1'}}) {
	    if ($jobs{'range2'}) {
		foreach my $r2 (@{$jobs{'range2'}}) {
		    my $obj = &generate(\%jobs, $r1, $r2);
		    push(@objs , $obj);
		}
	    } else {
		my $obj = &generate(\%jobs, $r1);
		push(@objs , $obj);
	    }
	}
    } elsif ($jobs{'dir'}) {
	opendir(DIR, $jobs{'dir'});
	my @params = grep { !m/^(\.|\.\.)$/g } readdir(DIR);
	closedir(DIR);
	foreach (@params) {
	    my $obj = &generate(\%jobs, $_);
	    push(@objs , $obj);
	}
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
	my @list = &pickup($outputfile, $jg_rng_amp{'odlmtr'});
	push (@outputs , $list[$jg_rng_amp{'oclmn'}]);
    }
    return @outputs;
}

1;
