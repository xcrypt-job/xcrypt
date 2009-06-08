package UI;

use File::Copy;
use function;

use base qw(Exporter);
@EXPORT = qw(killall pickup prepare_submit_sync prepare_submit submit_sync prepare submit kaishu sync);

my @allmembers = ('exe', 'arg1', 'arg2', 'ifile', 'ofile', 'oclmn', 'odlmtr', 'queue', 'option', 'stdofile', 'stdefile', 'proc', 'cpu');

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
    } else {
	$job{'id'} = $_[0]{'id'} . '_' . $_[1] .'-'. $_[2] .'-'. $_[3];
    }
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($_[0]{"$members"}) eq 'CODE') {
	    $job{"$_"} =  &{$_[0]{"$members"}}($_[1], $_[2], $_[3]);
	} elsif (ref($_[0]{"$members"}) eq 'ARRAY') {
	    my @tmp = @{$_[0]{"$members"}};
	    $job{"$_"} = $tmp[$_[1]];
	} else {
	    die "X must be a reference of a function or an array at \&prepare(\.\.\. \'$members\'\=\> X)";
	}
    }
    return user->new(\%job);
}

sub prepare {
    my %jobs = @_;
    foreach (@allmembers) {
	my $members = "$_" . 's';
	unless ($jobs{"$members"}) {$jobs{"$members"} = sub {$jobs{"$_"};};}
    }
    my @objs;
    if ($jobs{'range1'}) {
	if ($jobs{'range2'}) {
	    if ($jobs{'range3'}) {
		foreach my $r1 (@{$jobs{'range1'}}) {
		    foreach my $r2 (@{$jobs{'range2'}}) {
			foreach my $r3 (@{$jobs{'range3'}}) {
			    my $obj = &generate(\%jobs, $r1, $r2, $r3);
			    push(@objs , $obj);
			}
		    }
		}
	    } else {
		foreach my $r1 (@{$jobs{'range1'}}) {
		    foreach my $r2 (@{$jobs{'range2'}}) {
			my $obj = &generate(\%jobs, $r1, $r2);
			push(@objs , $obj);
		    }
		}
	    }
	} else {
	    foreach my $r1 (@{$jobs{'range1'}}) {
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
    } elsif (&max(\%jobs)) {
	my @params = (0..(&min(\%jobs)-1));
	foreach (@params) {
	    print $_;
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
    my @objs = &prepare(@_);
    my @stdouts = ();
    foreach (@objs) {
	my $stdofile = File::Spec->catfile($_->{id}, 'stdout');
	if ($_->{stdofile}) { $stdofile = $_->{stdofile}; }
	my @stdlist = &pickup($stdofile, ',');
	push (@stdouts, $stdlist[0]);
    }
    return @stdouts;
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
