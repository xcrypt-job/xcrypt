package UI;

use File::Copy;
use function;

use base qw(Exporter);
@EXPORT = qw(killall pickup prepare_submit_sync prepare_submit submit_sync prepare submit repickup sync);

my @args = ();
for ( my $i = 0; $i <= 255; $i++ ) { push(@args, "arg$i"); }
my @allmembers = ('exe', 'ifile', 'ofile', 'oclmn', 'odlmtr', 'queue', 'option', 'stdofile', 'stdefile', 'proc', 'cpu', @args);

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
    my %job = %{$_[0]};
    if ($_[1] eq '') {
	$job{'id'} = $_[0]{'id'};
    } elsif ($_[2] eq '') {
	$job{'id'} = $_[0]{'id'} . '_' . $_[1];
    } elsif ($_[3] eq '') {
	$job{'id'} = $_[0]{'id'} . '_' . $_[1] .'-'. $_[2];
    } elsif ($_[4] eq '') {
	$job{'id'} = $_[0]{'id'} . '_' . $_[1] .'-'. $_[2] .'-'. $_[3];
    } else {
	$job{'id'} = $_[0]{'id'} . '_' . $_[1] .'-'. $_[2] .'-'. $_[3] .'-'. $_[4];
    }
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($_[0]{"$members"}) eq 'CODE') {
	    $job{"$_"} =  &{$_[0]{"$members"}}($_[1], $_[2], $_[3], $_[4]);
	} elsif (ref($_[0]{"$members"}) eq 'ARRAY') {
	    my @tmp = @{$_[0]{"$members"}};
	    $job{"$_"} = $tmp[$_[1]];
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

    for ( my $i = 0; $i <= 3; $i++ ) {
	my $range = 'range' . $i;
	if (@{$jobs{"$range"}} eq ()) {
	    push(@{$jobs{"$range"}}, 'nil');
	}
    }

    if ($jobs{'range0'}) {
	my @ranges = ();
	for ( my $i = 0; $i <= 3; $i++ ) {
	    my $range = 'range' . $i;
	    push(@ranges, $jobs{"$range"});
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
    } else {
	my $obj = &generate(\%jobs);
	push(@objs , $obj);
    }
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
