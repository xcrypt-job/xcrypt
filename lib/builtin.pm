package builtin;

use strict;
#use File::Copy;
use threads;
use threads::shared;
#use Thread::Semaphore;
use jobsched;

#use xcropt;

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

our $after_thread;
my $lockvar_for_after : shared;
my @id_for_after = ();

my $nilchar = 'nil';

sub addkeys {
    my $exist = 0;
    foreach my $i (@_) {
	foreach my $j ((@user::allkeys, 'id', 'option')) {
	    if (($i eq $j)
		|| ($i =~ /^arg[0-9]*/)
		|| ($i =~ /^linkedfile[0-9]*/)
		|| ($i =~ /^copiedfile[0-9]*/)
		|| ($i =~ /^copieddir[0-9]*/)
		) {
		$exist = 1;
	    }
	}
	if ($exist == 1) {
	    die "$i is a reserved word in Xcrypt.\n";
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


    my @premembers = ('arg', 'linkedfile', 'copiedfile', 'copieddir');
    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
	foreach (@premembers) {
	    my $name = $_ . $i;
	    push(@user::allkeys, "$name");
	}
    }
    foreach (@user::allkeys) {
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

sub MAX {
    my $num = 0;
    my @premembers = ('arg', 'linkedfile', 'copiedfile', 'copieddir');
    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
	foreach (@premembers) {
	    my $name = $_ . $i;
	    push(@user::allkeys, "$name");
	}
    }
    foreach (@user::allkeys) {
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
    my @premembers = ('arg', 'linkedfile', 'copiedfile', 'copieddir');
    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
	foreach (@premembers) {
	    my $name = $_ . $i;
	    push(@user::allkeys, "$name");
	}
    }
    foreach (@user::allkeys) {
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

sub invoke_after {
    my @jobs = @_;
    $after_thread = threads->new( sub {
	while (1) {
	    sleep(1);
	    foreach my $i (@jobs) {
		{
		    # submitのスレッド分離部と排他的に
		    lock($lockvar_for_after);
		    my $stat = &jobsched::get_job_status($i->{'id'});
		    if ($stat eq 'done') {
			eval($i->{'after'});
			print $i->{'id'} . "\'s post-processing finished.\n";
			&jobsched::inventory_write($i->{'id'}, "finished");
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
	lock($lockvar_for_after);
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
    my %jobs = @_;
    my @premembers = ('arg', 'linkedfile', 'copiedfile', 'copieddir');
    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
	foreach (@premembers) {
	    my $name = $_ . $i;
	    push(@user::allkeys, "$name");
	}
    }
    foreach (@user::allkeys) {
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
	    if ($immediate_submit == 1) {
		&submit($obj);
	    }
	    push(@objs, $obj);
	}
    } elsif (&MAX(\%jobs)) { # when parameters except RANGE* exist
	my @params = (0..(&MIN(\%jobs)-1));
	foreach (@params) {
	    my $obj = &generate(\%jobs, $_);
	    if ($immediate_submit == 1) {
		&submit($obj);
	    }
	    push(@objs, $obj);
	}
    } else {
	my $obj = &generate(\%jobs);
	if ($immediate_submit == 1) {
	    &submit($obj);
	}
	push(@objs, $obj);
    }
    return @objs;
}

=comment

sub prepare_submit {
    my @jobs = &prepare(@_);
    return &submit(@jobs);
}
=cut
sub prepare_submit_sync {
    my @objs = &prepare_submit(@_);
    return &sync(@objs);
}

1;
