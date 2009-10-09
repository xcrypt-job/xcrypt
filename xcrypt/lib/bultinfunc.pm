package builtinfunc;

use strict;
#use File::Copy;
use threads;
#use threads::shared;
#use Thread::Semaphore;
use jobsched;
#use xcropt;

use base qw(Exporter);
our @EXPORT = qw(prepare submit submit_noafter sync after_sync
prepare_submit_sync prepare_submit submit_sync
);

threads->set_stack_size($xcropt::options{stack_size});
if ( $xcropt::options{limit} > 0 ) {
    $user::smph = Thread::Semaphore->new($xcropt::options{limit});
}

my $nilchar = 'nil';
my @allmembers = ('exe', 'stdofile', 'stdefile', 'queue', 'proc', 'cpu');
my @premembers = ('arg', 'linkedfile', 'copiedfile', 'copieddir');

for ( my $i = 0; $i <= $user::max; $i++ ) {
    foreach (@premembers) {
	my $name = $_ . $i;
	push(@allmembers, "$name");
    }
}

sub rm_tailnis {
    my @str = @_;
    if ($str[$#str] eq $nilchar) {
	pop(@str);
	&rm_tailnis(@str);
    } else {
	return @str;
    }
}

sub generate {
    my %job = %{$_[0]};
    shift;

    my @ranges = &rm_tailnis(@_);
    unless ( $user::separator_nocheck) {
	unless ( $user::separator =~ /^[!#+,-.@\^_~a-zA-Z0-9]$/ ) {
	    die "Can't support $user::separator as \$separator.\n";
	}
    }
    $job{'id'} = join($user::separator, ($job{'id'}, @ranges));
    foreach (@allmembers) {
	my $members = "$_" . 'S';
	if ( exists($job{"$members"}) ) {
	    unless ( ref($job{"$members"}) ) {
		my $tmp = eval($job{"$members"});
		$job{"$_"} = $tmp;
	    } else {
		if ( ref($job{"$members"}) eq 'CODE' ) {
		    $job{"$_"} = &{$job{"$members"}}(@ranges);
		} elsif ( ref($job{"$members"}) eq 'ARRAY' ) {
		    my @tmp = @{$job{"$members"}};
		    $job{"$_"} = $tmp[$_[0]];
		} elsif ( ref($job{"$members"}) eq 'SCALAR' ) {
		    my $tmp = ${$job{"$members"}};
		    $job{"$_"} = $tmp;
		} elsif ( ref($job{"$members"}) eq 'GLOB' ) {
		    die "Can't take GLOB at prepare.\n";
		} else {
		    die "Can't take your format at prepare.\n";
		}
	    }
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
	my $members = "$_" . 'S';
	unless ( exists($jobs{"$members"}) ) {
	    if ( exists($jobs{"$_"}) ) {
		$jobs{"$members"} = sub {$jobs{"$_"};};
	    }
	}
    }

    my $existOfRANGE = 0;
    for ( my $i = 0; $i < $user::maxrange; $i++ ) {
	if ( exists($jobs{"RANGE$i"}) ) {
	    if ( ref($jobs{"RANGE$i"}) eq 'ARRAY' ) {
		my $tmp = @{$jobs{"RANGE$i"}};
		$existOfRANGE = $existOfRANGE + $tmp;
	    } else {
		warn "X must be an ARRAY reference at \&prepare(\.\.\.\, \'RANGE$i\'\=\> X\,\.\.\.)";
	    }
	}
    }
    for ( my $i = 0; $i < $user::maxrange; $i++ ) {
	unless ( exists($jobs{"RANGE$i"}) ) {
	    my @tmp = ($nilchar);
	    $jobs{"RANGE$i"} = \@tmp;
	}
    }

    my @objs;
    if ( $existOfRANGE ) {
	my @ranges = ();
	for ( my $i = 0; $i < $user::maxrange; $i++ ) {
	    if ( exists($jobs{"RANGE$i"}) ) {
		if ( ref($jobs{"RANGE$i"}) eq 'ARRAY' ) {
		    push(@ranges, $jobs{"RANGE$i"});
		} else {
		    warn "X must be an ARRAY reference at \&prepare(\.\.\.\, \'RANGE$i\'\=\> X\,\.\.\.)";
		}
	    }
	}
	my @range = &times(@ranges);
	foreach (@range) {
	    my $obj = &generate(\%jobs, @{$_});
	    push(@objs, $obj);
	}
    } elsif (&MAX(\%jobs)) { # when parameters except RANGE* exist
	my @params = (0..(&MIN(\%jobs)-1));
	foreach (@params) {
	    my $obj = &generate(\%jobs, $_);
	    push(@objs, $obj);
	}
    } else {
	my $obj = &generate(\%jobs);
	push(@objs, $obj);

    }
    return @objs;
}

sub MAX {
    my $num = 0;
    foreach (@allmembers) {
	my $members = "$_" . 'S';
	if ( exists($_[0]{"$members"}) ) {
	    if (ref($_[0]{"$members"}) eq 'ARRAY') {
		my $tmp = @{$_[0]{"$members"}};
		$num = $tmp + $num;
	    }
	}
    }
    return $num;
}

sub MIN {
    my $num = 0;
    foreach (@allmembers) {
	my $members = "$_" . 'S';
	if ( exists($_[0]{"$members"}) ) {
	    if ( ref($_[0]{"$members"} ) eq 'ARRAY') {
		my $tmp = @{$_[0]{"$members"}};
		if ($tmp <= $num) { $num = $tmp; }
		elsif ($num == 0) { $num = $tmp; }
		else {}
	    }
	}
    }
    return $num;
}

sub submit {
    my @thrds = ();
    foreach (@_) {
	my $thrd = threads->new(\&user::start, $_);
	$thrd->detach();
        # 書くとメモリを喰う？
        # $_->{_thread}=$thrd;
    }
    return @_;
}

sub submit_noafter {
    foreach (@_) {
        if ( defined $user::smph ) {
            $user::smph->down;
        }
	&user::start($_);
    }
    return @_;
}

sub sync {
    my @array = @_;

    # thread->syncを使うと同期が完了するまでスレッドオブジェクトが生き残る
    foreach (@array)
    {
        # print "Waiting for $_->{id} finished.\n";
        &jobsched::wait_job_finished ($_->{id});
        # print "$_->{id} finished.\n";
    }
    return @_;
}

sub after_sync {
    my @array = @_;

    my %hash;
    foreach (@array) {
	$hash{"$_->{'id'}"} = $_;
    }
    my $n = 1;
    until ($n == 0) {
	sleep 1;
	foreach my $i (keys(%hash)) {
	    my $stat = &jobsched::get_job_status($i);
	    if ($stat eq 'done') {
		my $self = $hash{"$i"};
		$self->after();
		print $i . "\'s after-processing finished.\n";
		delete($hash{"$i"});
		$n = keys(%hash);
		&jobsched::inventory_write($i, "finished");
	    }
	}
    }

    # thread->syncを使うと同期が完了するまでスレッドオブジェクトが生き残る
#    foreach (@array)
#    {
        # print "Waiting for $_->{id} finished.\n";
#        &jobsched::wait_job_finished ($_->{id});
        # print "$_->{id} finished.\n";
#    }
    return @_;
}

sub prepare_submit_sync {
    my @jobs = &prepare(@_);
    my @objs = &submit(@jobs);
    return &sync(@objs);
}

sub submit_sync {
    my @objs = &submit(@_);
    return &sync(@objs);
}

sub prepare_submit {
    my @jobs = &prepare(@_);
    return &submit(@jobs);
}

1;
