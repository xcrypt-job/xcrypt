package builtin;

use strict;
use NEXT;
use threads;
use threads::shared;
use jobsched;
use usablekeys;

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

my $before_thread = undef;
my $after_thread = undef;
my $before_thread_status : shared = 'killed'; # one of 'killed', 'running', 'signaled'
my $after_thread_status : shared = 'killed' ; # one of 'killed', 'running', 'signaled'
my @jobs_for_before = ();
my @jobs_for_after = ();
my $nilchar = 'nil';

sub addkeys {
    my $exist = 0;
    foreach my $i (@_) {
	foreach my $j ((@usablekeys::allkeys, 'id')) {
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
	    die "$i has already been added or reserved.\n";
	} elsif ($i =~ /@\Z/) {
	    die "Can't use $i as key since $i has @ at its tail.\n";
	} else {
	    push(@usablekeys::allkeys, $i);
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
	    push(@usablekeys::allkeys, "$name");
	}
    }
    foreach my $key (keys(%job)) {
	if ($key =~ /\A:/) {
	    if ($key =~ /@\Z/) {
		$/ = $user::expandingchar;
		chomp $key;
		push(@usablekeys::allkeys, $key);
	    } else {
		push(@usablekeys::allkeys, $key);
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
    foreach (@usablekeys::allkeys) {
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

=comment
    my $exist = 0;
    foreach my $i (keys(%job)) {
	unless (($i =~ /\ARANGE[0-9]+\Z/) || ($i =~ /@\Z/)) {
	    foreach my $j ((@user::allkeys, 'id')) {
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
=cut
    foreach my $key (keys(%job)) {
	my $exist = 0;
	foreach my $ukey (@usablekeys::allkeys, 'id') {
	    if (($key eq $ukey) || ($key eq ($ukey . '@'))) {
		$exist = 1;
	    }
	}
	if ($exist == 0) {
	    unless (($key =~ /\ARANGE[0-9]+\Z/)) {
		print STDERR "Warning: $key doesn't work.  Use :$key or &addkeys(\'$key\').\n";
		delete $job{"$key"};
	    }
	}
	$exist = 0;
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
    foreach (@usablekeys::allkeys) {
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
    foreach (@usablekeys::allkeys) {
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

sub exit_if_sigaled {
    # $_[0]: ref to shared variable for thread status
    if ($$_[0] eq 'signaled') {
        lock ($$_[0]);
        if ($$_[0] eq 'signaled') {
            $$_[0] = 'killed';
            cond_signal ($$_[0]);
            thread->exit();
        }
    }
}

sub invoke_before {
    my @jobs = @_;
    $before_thread = threads->new( sub {
        while (1) {
            sleep (1);
            foreach my $self (@jobs) {
                my $stat = &jobsched::get_job_status($self->{'id'});
                if ($stat eq 'prepared') {
                    my $before_ready = $self->EVERY::before_isready();
                    my $failure=0;
                    foreach my $k (keys %{$before_ready}) {
                        unless ($before_ready->{$k}) {
                            $failure=1;
                        }
                    }
                    unless ($failure) {
                        $self->before();
                        $self->start();
                    }
                }
            }
            # signaledだったらスレッド終了
            exit_if_sigaled (\$before_thread_status);
        }
                                   });
    $before_thread->detach();
}

sub invoke_after {
    my @jobs = @_;
    $after_thread = threads->new( sub {
        while (1) {
            sleep(1);
            foreach my $self (@jobs) {
                {
                    my $stat = &jobsched::get_job_status($self->{'id'});
                    if ($stat eq 'done') {
#                       print $self->{'id'} . "\'s post-processing finished.\n";
                        &user::after($self);
                        until ((-e "$self->{'id'}/$self->{'stdofile'}")
                               && (-e "$self->{'id'}/$self->{'stdefile'}")) {
                            sleep(1);
                        }
                        &jobsched::inventory_write($self->{'id'}, 'finished');
                    }
                }
            }
            # signaledだったらスレッド終了
            exit_if_sigaled (\$after_thread_status);
        }
                                  });
    $after_thread->detach();
}

sub signal_and_wait_killed
{
    # $_[0]: ref to shared variable for thread status
    lock($$_[0]);
    $$_[0] = 'signaled';
    cond_wait ($$_[0]) until ($$_[0] eq 'killed');
}


sub submit {
    my @array = @_;

    # submit対象のジョブ状態を 'prepared' に
    foreach my $self (@array) {
        &jobsched::inventory_write($self->{'id'}, 'prepared');
    }
    # beforeスレッドを立ち上げ直し
    if ($before_thread) { signal_and_wait_killed (\$before_thread_status); }
    {
        my @jobs_for_before_new = @array;
        foreach my $j (@jobs_for_before) {
            my $stat = jobsched::get_job_status($j->{'id'});
            unless ( $stat eq 'finished' || $stat eq 'aborted' ) {
                push(@jobs_for_before_new, $j);
            }
        }
        @jobs_for_before = @jobs_for_before_new;
    }
    &invoke_before(@jobs_for_before);
    # afterスレッドを立ち上げ直し
    if ($after_thread)  { signal_and_wait_killed (\$after_thread_status); }
    {
        my @jobs_for_after_new = @array;
        foreach my $j (@jobs_for_after) {
            my $stat = jobsched::get_job_status($j->{'id'});
            unless ( $stat eq 'finished' || $stat eq 'aborted' ) {
                push(@jobs_for_after_new, $j);
            }
        }
        @jobs_for_after = @jobs_for_after_new;
    }
    &invoke_after(@jobs_for_after);

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
    foreach (@usablekeys::allkeys) {
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
