package UI;

use File::Copy;
use function;

use base qw(Exporter);
@EXPORT = qw(killall pickup prepare_submit_sync prepare_submit submit_sync prepare submit repickup sync);

my @args = ();
for ( my $i = 0; $i < $MAXARG; $i++ ) { push(@args, "arg$i"); }
my @allmembers = ('exe', 'ifile', 'ofile', 'oclmn', 'odlmtr', 'queue', 'option', 'stdofile', 'stdefile', 'proc', 'cpu', @args);

my $MAXRANGE = 16;
my $MAXARG = 256;


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

sub rm_nil {
    my @hoge = @_;
    if ($hoge[$#hoge] eq 'nil') {
	pop(@hoge);
	&rm_nil(@hoge);
    } else {
	return @hoge;
    }
}

sub generate {
    my %job = %{$_[0]};
    shift;

    my @ranges = rm_nil(@_);
    $job{'id'} = $job{'id'} . '_' . join($user::separation_symbol, @ranges);
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($job{"$members"}) eq 'CODE') {
	    $job{"$_"} =  &{$job{"$members"}}(@ranges);
	} elsif (ref($job{"$members"}) eq 'ARRAY') {
	    my @tmp = @{$job{"$members"}};
	    $job{"$_"} = $tmp[$_[0]];
	} else {
	    die "X must be a reference of a function or an array at \&prepare(\.\.\. \'$members\'\=\> X)";
	}
    }
    return user->new(\%job);
}

sub times {
    if (@_ == ()) { return (); }
    my $head = shift;
    my @tail = &times(@_);
    my @result;
    foreach my $i (@{$head}) {
	if (@tail == ()) {
	    push(@result, [$i]);
	} else {
	    foreach my $j (@tail) {
		push(@result, [$i, @{$j}]);
	    }
	}
    }
    return @result;
}

sub prepare {
    my %jobs = @_;
    foreach (@allmembers) {
	my $members = "$_" . 's';
	unless ($jobs{"$members"}) {$jobs{"$members"} = sub {$jobs{"$_"};};}
    }
    my @objs;

    for ( my $i = 0; $i < $MAXRANGE; $i++ ) {
	if (@{$jobs{"range$i"}} eq ()) {
	    push(@{$jobs{"range$i"}}, 'nil');
	}
    }
    my $count = 0;
    for ( my $i = 0; $i < $MAXRANGE; $i++ ) {
	$tmp = @{$jobs{"range$i"}};
	$count = $count + $tmp;
    }
    if ($count) {
	my @ranges = ();
	for ( my $i = 0; $i < $MAXRANGE; $i++ ) {
	    push(@ranges, $jobs{"range$i"});
	}
	my @range = &times(@ranges);
	foreach my $r (@range) {
	    my $obj = &generate(\%jobs, @{$r});
	    push(@objs , $obj);
	}
    } elsif ($jobs{'dir'}) {
	opendir(DIR, $jobs{'dir'});
	my @params = grep { !m/^(\.|\.\.)$/g } readdir(DIR);
	closedir(DIR);
	foreach (@params) {
	    my $obj = &generate(\%jobs, $_);
	    push(@objs , $obj);
	}
    } elsif (&max(\%jobs)) {
	my @params = (0..(&min(\%jobs)-1));
	foreach (@params) {
	    my $obj = &generate(\%jobs, $_);
	    push(@objs , $obj);
	}
    } else {}
    return @objs;
}

sub max {
    my $hoge = 0;
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($_[0]{"$members"}) eq 'ARRAY') {
	    my $tmp = @{$_[0]{"$members"}};
	    $hoge = $tmp + $hoge;
	}
    }
    return $hoge;
}

sub min {
    my $hoge = 0;
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($_[0]{"$members"}) eq 'ARRAY') {
	    my $tmp = @{$_[0]{"$members"}};
	    if ($tmp <= $hoge) {
		$hoge = $tmp;
	    } elsif ($hoge == 0) {
		$hoge = $tmp;
	    }
	}
    }
    return $hoge;
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

sub repickup {
    my @outputs = ();
    foreach (@_) {
	if ($_->{ofile}) {
	    my @stdlist = &pickup(File::Spec->catfile($_->{id}, $_->{ofile}),
				  $_->{odlmtr});
	    push (@stdouts, $stdlist[$self->{oclmn}]);
	}
	return @stdouts;
    }
}

1;
