package builtin;

use strict;
use threads;
use threads::shared;
use jobsched;

use base qw(Exporter);
our @EXPORT = qw(prepare submit sync
prepare_submit_sync prepare_submit submit_sync
addkeys
);

=comment
threads->set_stack_size($xcropt::options{stack_size});
if ( $xcropt::options{limit} > 0 ) {
    $user::smph = Thread::Semaphore->new($xcropt::options{limit});
}
=cut

our $after_thread; # used in bin/xcrypt
my $lock_for_after : shared;
my @id_for_after = ();
my $nilchar = 'nil';

sub addkeys {
    my $exist = 0;
    foreach my $i (@_) {
	foreach my $j ((@user::allkeys, 'id', 'option')) {
	    if (($i eq $j)
		|| ($i =~ /\Aarg[0-9]*/)
		|| ($i =~ /\Alinkedfile[0-9]*/)
		|| ($i =~ /\Acopiedfile[0-9]*/)
		|| ($i =~ /\Acopieddir[0-9]*/)
		) {
		$exist = 1;
	    }
	}
	if ($exist == 1) {
	    die "$i is a reserved word in Xcrypt.\n";
	} elsif ($i =~ /@\Z/) {
	    die "Can't use $i as key since $i has @ at its tail.\n";
	} else {
	    push(@user::allkeys, $i);
	}
	$exist = 0;
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

sub addmembers {
    my %job = @_;
    my @premembers = ('arg', 'linkedfile', 'copiedfile', 'copieddir');
    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
	foreach (@premembers) {
	    my $name = $_ . $i;
	    push(@user::allkeys, "$name");
	}
    }
    foreach my $key (keys(%job)) {
	if ($key =~ /\A:/) {
	    if ($key =~ /@\Z/) {
		$/ = $user::expandingchar;
		chomp $key;
		push(@user::allkeys, $key);
	    } else {
		push(@user::allkeys, $key);
	    }
	}
    }
}

sub generate {
    my %job = %{$_[0]};
    shift;

    my @ranges = &rm_tailnis(@_);
    unless ( $user::separator_nocheck) {
	unless ( $user::separator =~ /\A[!#+,-.@\^_~a-zA-Z0-9]\Z/ ) {
	    die "Can't support $user::separator as \$separator.\n";
	}
    }
    $job{'id'} = join($user::separator, ($job{'id'}, @ranges));

    &addmembers(%job);
    foreach (@user::allkeys) {
	my $members = "$_" . $user::expandingchar;
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

    my $exist = 0;
    foreach my $i (keys(%job)) {
	unless (($i =~ /\ARANGE[0-9]+/) || ($i =~ /@\Z/)) {
	    foreach my $j ((@user::allkeys, 'id', 'option')) {
		if ($i eq $j) {
		    $exist = 1;
		}
	    }
	    if ($exist == 0) {
		warn "Warning: $i is given, but not defined by addkeys.\n";
	    }
	    $exist = 0;
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

sub MAX {
    my %job = @_;
    my $num = 0;

    &addmembers(%job);
    foreach (@user::allkeys) {
	my $members = "$_" . $user::expandingchar;
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
    my %job = @_;
    my $num = 0;

    &addmembers(%job);
    foreach (@user::allkeys) {
	my $members = "$_" . $user::expandingchar;
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

sub invoke_after {
    my @jobs = @_;
    $after_thread = threads->new( sub {
	while (1) {
	    sleep(1);
	    foreach my $self (@jobs) {
		{
		    # submitのスレッド分離部と排他的に
		    lock($lock_for_after);
		    my $stat = &jobsched::get_job_status($self->{'id'});
		    if ($stat eq 'done') {
			print $self->{'id'} . "\'s post-processing finished.\n";
			&user::after($self);
			&jobsched::inventory_write($self->{'id'}, "finished");
		    }
		    # ここまで
		}
	    }
	}
				  });
}


sub submit {
    my @array = @_;

    # invoke_afterの処理部と排他的に
    {
	lock($lock_for_after);
	$after_thread->detach();
    }
    # ここまで
    $after_thread = 0;
    foreach my $i (@array) {
	push(@id_for_after, $i);
    }
    &invoke_after(@id_for_after);

    foreach (@array) {
# after 処理をメインスレッド以外ですることになり limit.pm が復活したので
#        if ( defined $user::smph ) {
#            $user::smph->down;
#        }
#
#	my $thread = threads->new( sub {
#	print "$self->{id}\'s pre-processing finished.\n";
	&user::before($_);
	&user::start($_);
#				   } );
#	$thread->detach();
    }
    return @array;
}

sub sync {
    my @array = @_;
    # thread->syncを使うと同期が完了するまでスレッドオブジェクトが生き残る
    my %hash;
    foreach my $i (@array) {
	$hash{"$i->{id}"} = $i;
    }
    foreach (keys(%hash)) {
        # print "Waiting for $_->{id} finished.\n";
        &jobsched::wait_job_finished ($_);
        # print "$_->{id} finished.\n";
    }
    return @_;
}

sub submit_sync {
    my @objs = &submit(@_);
    return &sync(@objs);
}

sub prepare {
    &prepare_or_prepare_submit(0, @_);
}

sub prepare_submit {
    &prepare_or_prepare_submit(1, @_);
}

sub prepare_or_prepare_submit {
    my $immediate_submit = shift(@_);
    my @objs;
    my %job = @_;

    &addmembers(%job);
    foreach (@user::allkeys) {
	my $members = "$_" . $user::expandingchar;
	unless ( exists($job{"$members"}) ) {
	    if ( exists($job{"$_"}) ) {
		$job{"$members"} = sub {$job{"$_"};};
	    }
	}
    }

    my $existOfRANGE = 0;
    for ( my $i = 0; $i < $user::maxrange; $i++ ) {
	if ( exists($job{"RANGE$i"}) ) {
	    if ( ref($job{"RANGE$i"}) eq 'ARRAY' ) {
		my $tmp = @{$job{"RANGE$i"}};
		$existOfRANGE = $existOfRANGE + $tmp;
	    } else {
		warn "X must be an ARRAY reference at \&prepare(\.\.\.\, \'RANGE$i\'\=\> X\,\.\.\.)";
	    }
	}
    }
    for ( my $i = 0; $i < $user::maxrange; $i++ ) {
	unless ( exists($job{"RANGE$i"}) ) {
	    my @tmp = ($nilchar);
	    $job{"RANGE$i"} = \@tmp;
	}
    }

    if ( $existOfRANGE ) {
	my @ranges = ();
	for ( my $i = 0; $i < $user::maxrange; $i++ ) {
	    if ( exists($job{"RANGE$i"}) ) {
		if ( ref($job{"RANGE$i"}) eq 'ARRAY' ) {
		    push(@ranges, $job{"RANGE$i"});
		} else {
		    warn "X must be an ARRAY reference at \&prepare(\.\.\.\, \'RANGE$i\'\=\> X\,\.\.\.)";
		}
	    }
	}
	my @range = &times(@ranges);
	foreach (@range) {
	    my $obj = &generate(\%job, @{$_});
	    if ($immediate_submit == 1) {
		&submit($obj);
	    }
	    push(@objs, $obj);
	}
    } elsif (&MAX(\%job)) { # when parameters except RANGE* exist
	my @params = (0..(&MIN(\%job)-1));
	foreach (@params) {
	    my $obj = &generate(\%job, $_);
	    if ($immediate_submit == 1) {
		&submit($obj);
	    }
	    push(@objs, $obj);
	}
    } else {
	my $obj = &generate(\%job);
	if ($immediate_submit == 1) {
	    &submit($obj);
	}
	push(@objs, $obj);
    }
    return @objs;
}

sub prepare_submit_sync {
    my @objs = &prepare_submit(@_);
    return &sync(@objs);
}

1;
