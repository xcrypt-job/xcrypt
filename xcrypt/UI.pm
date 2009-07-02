package UI;

use File::Copy;
use function;

use base qw(Exporter);
@EXPORT = qw(pickup prepare_submit_sync prepare_submit submit_sync prepare submit repickup sync);

my $MAXRANGE = 16;
my $MAX = 256;
my $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'pjo_inventory_write.pl');
my $nilchar = 'nil';

my @allmembers = ('exe', 'ofile', 'oclmn', 'odlmtr', 'queue', 'stdofile', 'stdefile', 'proc', 'cpu');

for ( my $i = 0; $i < $MAX; $i++ ) {
    foreach (('arg', 'linkedfile', 'copiedfile', 'copieddir')) {
	my $name = $_ . $i;
	push(@allmembers, "$name");
    }
}

$separation_symbol = '!';

=comment
sub killall {
    my $prefix = shift;
    foreach (@_) {
	my $id = $prefix . '_' . $_;
	my @list = &pickup("$id/request_id", ' ');
	my @revlist = reverse(@list);
	system("qdel -k $revlist[4]");
#	system("qdel $revlist[4]");
	system("$write_command inv_watch/$id \"done\" \"spec: $id\"");
    }
}
=cut

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

sub rm_nilchar {
    my @str = @_;
    if ($str[$#str] eq $nilchar) {
	pop(@str);
	&rm_nilchar(@str);
    } else {
	return @str;
    }
}

sub generate {
    my %job = %{$_[0]};
    shift;

    my @ranges = &rm_nilchar(@_);
    $job{'id'} = join($separation_symbol, ($job{'id'}, @ranges));
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($job{"$members"}) eq 'CODE') {
	    $job{"$_"} =  &{$job{"$members"}}(@ranges);
	} elsif (ref($job{"$members"}) eq 'ARRAY') {
	    my @tmp = @{$job{"$members"}};
	    $job{"$_"} = $tmp[$_[0]];
	} elsif (ref($job{"$members"}) eq 'SCALAR') {
	    my $tmp = ${$job{"$members"}};
	    $job{"$_"} = $tmp;
	} else {
	    die "X must be a reference at \&prepare(\.\.\.\, \'$members\'\=\> X\,\.\.\.)";
	}
    }
=comment
    my $dir = $job{'id'};
    $job{'stdofile'} = File::Spec->catfile($dir, 'stdout');
    $job{'stdefile'} = File::Spec->catfile($dir, 'stderr');
=cut
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

    my $count = 0;
    for ( my $i = 0; $i < $MAXRANGE; $i++ ) {
	$tmp = @{$jobs{"range$i"}};
	$count = $count + $tmp;
    }
    for ( my $i = 0; $i < $MAXRANGE; $i++ ) {
	if (@{$jobs{"range$i"}} eq ()) {
	    push(@{$jobs{"range$i"}}, $nilchar);
	}
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
    } elsif ($jobs{'copieddir'}) {
	opendir(DIR, $jobs{'copieddir'});
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
    my $num = 0;
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($_[0]{"$members"}) eq 'ARRAY') {
	    my $tmp = @{$_[0]{"$members"}};
	    $num = $tmp + $num;
	}
    }
    return $num;
}

sub min {
    my $num = 0;
    foreach (@allmembers) {
	my $members = "$_" . 's';
	if (ref($_[0]{"$members"}) eq 'ARRAY') {
	    my $tmp = @{$_[0]{"$members"}};
	    if ($tmp <= $num) {	$num = $tmp; }
	    elsif ($num == 0) { $num = $tmp; }
	    else {}
	}
    }
    return $num;
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
