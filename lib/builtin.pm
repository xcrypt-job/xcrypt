package builtin;

#use strict;
use NEXT;
use threads ();
use threads::shared;
use Coro;
use Coro::Signal;
use Coro::AnyEvent;
use Cwd;
use Data::Dumper;
use File::Basename;
use Net::OpenSSH;

use jobsched;
use xcropt;
use Cwd;
use common;

use base qw(Exporter);
our @EXPORT = qw(expand_and_make prepare_directory submit sync
prepare prepare_submit submit_sync prepare_submit_sync
add_key add_host repeat get_elapsed_time
);

# id, exe$i, arg$i_$j, linkedfile$i, copiedfile$i, and copieddir$i are built-in.
our @allkeys = ('exe', 'before', 'before_in_job', 'after_in_job', 'after', 'rhost', 'rwd', 'scheduler');

my $nilchar = 'nil';
my $argument_name = 'R';
my $before_after_slp = 1;

our %rhost_object;

my $current_directory=Cwd::getcwd();
my $inventory_path=File::Spec->catfile($current_directory, 'inv_watch');
my $time_running : shared = undef;
my $time_done_now = undef;
sub get_elapsed_time {
    my $inventoryfile = File::Spec->catfile ($inventory_path, "$_[0]");
    $time_done_now = time();
    &update_running_and_done_now("$inventoryfile");
    if (defined $time_running) {
        my $elapsed = $time_done_now - $time_running;
        return $elapsed;
    }
}

sub update_running_and_done_now {
    open( INV, "$_[0]" ) or die "$!";
    while (<INV>) {
        if ($_ =~ /^time_running\:\s*([0-9]*)/) {
            $time_running = $1;
        }
        if ($_ =~ /^time_done\:\s*([0-9]*)/) {
            $time_done_now = $1;
        }
    }
    close( INV );
}

sub check_and_alert_elapsed {
    my @jobids = keys(%jobsched::initialized_nosync_jobs);

    my $sum = 0;
    my %elapseds = ();
    my $length = 0;
    foreach my $i (@jobids) {
        $elapseds{"$i"} = undef;
        my $inventoryfile = File::Spec->catfile ($inventory_path, "$i");
        $time_done_now = time();
        &update_running_and_done_now($inventoryfile);
        if (defined $time_running) {
            my $elapsed = $time_done_now - $time_running;
            $sum = $sum + $elapsed;
            $elapseds{"$i"} = $elapsed;
            $length = $length + 1;
        }
        $time_running = undef;
    }
    my $average = 0;
    unless ($length == 0) {
        $average = $sum / $length;
    }
    foreach (@jobids) {
        if (defined $elapseds{$_}) {
            if ( $elapseds{$_} - $average > 300 ) {
                print "Warning: $_ takes more time than the other jobs.\n";
            }
        }
    }
}

my $default_period = 10;
my $periodic_threads = ();
sub repeat {
    my $new_coro = undef;
    my $sub_or_str = $_[0];
    my $slp = $_[1];
    unless ($slp) { $slp = 10; }
    if ( ref($_[0]) eq 'CODE' ) {
        $new_coro = Coro::async_pool {
            while (1) {
                Coro::AnyEvent::sleep $slp;
                &{$sub_or_str};
            }
        };
    } elsif (!(ref $_[0])) {
        $new_coro = Coro::async_pool {
            while (1) {
                Coro::AnyEvent::sleep $slp;
                eval $sub_or_str;
            }
        };
    } else {
        warn '&repeat accepts code or eval-string.';
    }
    if ($new_coro) {
        push (@periodic_threads, $new_coro);
    }
    if ( $xcropt::options{verbose} >= 2 ) {
        print "periodic = (";
        foreach (@periodic_threads) {
            print "$_ "
        }
        print ")\n";
    }
    return $new_coro;
}

sub add_host {
    foreach my $i (@_) {
	unless (exists $rhost_object{$i}) {
	    my ($user, $host) = split(/@/, $i);
#	    my %args = (host => $host, user => $user);
#	    our $sftp = Net::SFTP::Foreign->new(%args);
	    our $sftp = Net::OpenSSH->new($host, (user => $user));
	    $sftp->error and die "Unable to stablish SFTP connection: " . $sftp->error;
	    $rhost_object{$i} = $sftp;
	    push(@jobsched::rhost_for_watch, $i);
	}
    }
}

sub add_key {
    my $exist = 0;
    foreach my $i (@_) {
        foreach my $j ((@allkeys, 'id')) {
            if (($i eq $j)
                || ($i =~ /\Aexe[0-9]*/)
                || ($i =~ /\Aarg[0-9]*/)
                || ($i =~ /\Aarg[0-9]*_[0-9]*/)
                || ($i =~ /\Alinkedfile[0-9]*/)
                || ($i =~ /\Acopiedfile[0-9]*/)
                || ($i =~ /\Acopieddir[0-9]*/)
                ) {
                $exist = 1;
            }
        }
        if ($exist == 1) {
            die "$i has already been added or reserved.\n";
        } elsif ($i =~ /"$expandingchar"\Z/) {
            die "Can't use $i as key since $i has $expandingchar at its tail.\n";
        } else {
            push(@allkeys, $i);
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

sub add_user_customizable_core_members {
    my %job = @_;
    my @premembers = ('exe', 'linkedfile', 'copiedfile', 'copieddir');
    for ( my $i = 0; $i <= $user::max_exe_etc; $i++ ) {
        foreach (@premembers) {
            my $name = $_ . $i;
            push(@allkeys, "$name");
        }
    }
    for ( my $i = 0; $i <= $user::max_arg; $i++ ) {
            my $name = 'arg' . $i;
            push(@allkeys, "$name");
    }
    for ( my $i = 0; $i <= $user::max_arg; $i++ ) {
	for ( my $j = 0; $j <= $user::max_arg; $j++ ) {
            my $name = 'arg' . $i . '_' . $j;
            push(@allkeys, "$name");
	}
    }
    foreach my $key (keys(%job)) {
        if ($key =~ /\A:/) {
            if ($key =~ /"$expandingchar"\Z/) {
                $/ = $user::expandingchar;
                chomp $key;
                push(@allkeys, $key);
            } else {
                push(@allkeys, $key);
            }
        }
    }
}

sub generate {
    my %job = %{$_[0]};
    shift;

    unless ( $user::separator_nocheck) {
        unless ( $user::separator =~ /\A[!#+,-.@\^_~a-zA-Z0-9]\Z/ ) {
            die "Can't support $user::separator as \$separator.\n";
        }
    }
    my @ranges = &rm_tailnis(@_);

    $job{id} = join($user::separator, ($job{id}, @ranges));
    &add_user_customizable_core_members(%job);
    foreach (@allkeys) {
        my $members = "$_" . $user::expandingchar;
        if ( exists($job{"$members"}) ) {
            # 「ジョブ定義ハッシュ@」の値がスカラである時
            unless ( ref($job{"$members"}) ) {
                for ( my $i = 0; $i < $user::maxrange; $i++ ) {
                    my $arg = $argument_name . $i;
#                   no strict 'refs';
                    my $tmp = eval "$ranges[$i];";
                    eval "our \$$arg = $tmp;";
                }
                my $tmp = eval($job{"$members"}); # 「引数をとるものについては文字列をエバる」方式はR0のみをサポートしている（$_[0]は未サポート）
                $job{"$_"} = $tmp;
            } elsif ( ref($job{"$members"}) eq 'ARRAY' ) {
                my @tmp = @{$job{"$members"}};
                $job{"$_"} = $tmp[$_[0]];
            } elsif ( ref($job{"$members"}) eq 'CODE' ) {
                $job{"$_"} = &{$job{"$members"}}(@ranges);
            } else {
                die "Can't take " . ref($job{"$members"}) . " at prepare.\n";
            }
        }
    }

=comment
    foreach my $key (keys(%job)) {
        my $exist = 0;
        foreach my $ukey (@allkeys, 'id') {
            if (($key eq $ukey) || ($key eq ($ukey . '@'))) {
                $exist = 1;
            }
        }
        if ($exist == 0) {
            unless (($key =~ /\ARANGE[0-9]+\Z/)) {
                print "Warning: $key doesn't work.  Use :$key or &add_key(\'$key\').\n";
                delete $job{"$key"};
            }
        }
        $exist = 0;
    }
=cut
    my $self = user->new(\%job);
    &jobsched::inventory_write ($self->{id}, "initialized",
				$self->{rhost}, $self->{rwd});
    return $self;
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

    &add_user_customizable_core_members(%job);
    foreach (@allkeys) {
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

    &add_user_customizable_core_members(%job);
    foreach (@allkeys) {
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

sub expand_and_make {
    my %job = @_;

    # aliases
    if ($job{exe}) {
	$job{exe0} = $job{exe};
#	delete($job{exe});
    }
    if ($job{"exe$user::expandingchar"}) {
	$job{"exe0$user::expandingchar"} = $job{"exe$user::expandingchar"};
    }
    foreach my $i (0..$user::max_arg) {
	if ($job{"arg$i"}) {
	    $job{"arg0_$i"} = $job{"arg$i"};
#	    delete($job{"arg$i"});
	}
    }
    foreach my $i (0..$user::max_arg) {
	if ($job{"arg$i$user::expandingchar"}) {
	    $job{"arg0_$i$user::expandingchar"} = $job{"arg$i$user::expandingchar"};
	}
    }
    &add_user_customizable_core_members(%job);
=comment
    foreach my $key (keys(%job)) {
        unless (&belong($key, 'id', @allkeys)) {
            delete($job{"$key"});
        }
    }
=cut
    foreach my $key (keys(%job)) {
        my $exist = 0;
        foreach my $ukey (@allkeys, 'id') {
            if (($key eq $ukey) || ($key eq ($ukey . '@'))) {
                $exist = 1;
            }
        }
        if ($exist == 0) {
            unless (($key =~ /\ARANGE[0-9]+\Z/)
                    || ($key =~ /^JS_/))        # for jobscheduler options
            {
                print STDOUT "Warning: $key doesn't work.  Use :$key or &add_key(\'$key\').\n";
                delete $job{"$key"};
            }
        }
        $exist = 0;
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

    my @objs;
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
            my $self = &generate(\%job, @{$_});
            push(@objs, $self);
        }
    } elsif (&MAX(\%job)) { # when parameters except RANGE* exist
        my @params = (0..(&MIN(\%job)-1));
        foreach (@params) {
            my $self = &generate(\%job, $_);
            push(@objs, $self);
        }
    } else {
        my $self = &generate(\%job);
        push(@objs, $self);
    }
    return @objs;
}

sub prepare_directory {
    my @jobs = @_;
    foreach my $self (@jobs) {
	my $last_stat = &jobsched::get_job_status ($self->{id});
	if ( jobsched::is_signaled_job ($self->{id}) ) {
	    # If the job is 'xcryptdel'ed, make it 'aborted' and skip
	    &jobsched::inventory_write ($self->{id}, "aborted",
					$self->{rhost}, $self->{rwd});
	    &jobsched::delete_signaled_job ($self->{id});
	} elsif ( $last_stat eq 'done' || $last_stat eq 'finished' ) {
	    # Skip if the job is 'done' or 'finished'
	    if ( $last_stat eq 'finished' ) {
		&jobsched::inventory_write ($self->{id}, "done",
					    $self->{rhost}, $self->{rwd});
	    }
	} else {
	    # If the working directory already exists, delete it
	    if ( -e $self->{workdir} ) {
		print "Delete directory $self->{workdir}\n";
		File::Path::rmtree ($self->{workdir});
	    }
	    unless ($self->{rhost} eq '') {
		my $ex = &xcr_exist('-d', $self->{id},
				    $self->{rhost}, $self->{rwd});
		# If the working directory already exists, delete it
		if ($ex) {
		    print "Delete directory $self->{id}\n";
		    &xcr_qx('rm -rf', '.', $self->{rhost}, $self->{rwd});
		}
	    }
	    &xcr_mkdir($self->{id}, $self->{rhost}, $self->{rwd});
	    unless (-d "$self->{id}") {
		mkdir $self->{id}, 0755;
	    }
	    for ( my $i = 0; $i <= $user::max_exe_etc; $i++ ) {
		# リモート実行未対応
		if ($self->{"copieddir$i"}) {
		    my $copied = $self->{"copieddir$i"};
		    opendir(DIR, $copied);
		    my @params = grep { !m/^(\.|\.\.)/g } readdir(DIR);
		    closedir(DIR);
		    foreach (@params) {
			my $tmp = File::Spec->catfile($copied, $_);
			my $temp = File::Spec->catfile($self->{workdir}, $_);
			rcopy $tmp, $temp;
		    }
		}

		if ($self->{"copiedfile$i"}) {
		    my $copied = $self->{"copiedfile$i"};
		    my $ex = &xcr_exist('-f', $copied, $self->{rhost});
		    if ($ex) {
			&xcr_copy($copied, $self->{id},
				  $self->{rhost}, $self->{rwd});
		    } else {
			warn "Can't copy $copied\n";
		    }
		}
		if ($self->{"linkedfile$i"}) {
		    my $file = $self->{"linkedfile$i"};
		    &xcr_symlink($self->{id},
				 File::Spec->catfile($file),
				 File::Spec->catfile(basename($file)),
				 $self->{rhost}, $self->{rwd});
		}
	    }
	}
    }
}

sub do_prepared {
    my @jobs = @_;
    foreach my $self (@jobs) {
	my $last_stat = &jobsched::get_job_status ($self->{id});
	unless ( $last_stat eq 'done' ||
		 $last_stat eq 'finished' ||
		 $last_stat eq 'aborted' ) {
	    # xcryptdelされていたら状態をabortedにして処理をとばす
	    if (jobsched::is_signaled_job($self->{id})) {
		&jobsched::inventory_write($self->{id}, "aborted",
					   $self->{rhost}, $self->{rwd});
		    &jobsched::delete_signaled_job($self->{id});
		push (@coros, undef);
		next;
	    } else {
		if (defined $self->{rhost}) {
		    &jobsched::inventory_write($self->{id}, 'prepared',
					       $self->{rhost}, $self->{rwd});
		} else {
		    &jobsched::inventory_write($self->{id}, 'prepared');
		}
	    }
	}
    }
}

sub prepare{
    my @objs = &expand_and_make(@_);
    if ($xcropt::options{sandbox}) {
	&prepare_directory(@objs);
    }
    &do_prepared(@objs);
    return @objs;
}

sub submit {
    my @array = @_;
    my $slp = 0;
    # my @coros = ();
    foreach my $self (@array) {
        # ジョブスレッドを立ち上げる
        my $job_coro = Coro::async {
            my $self = $_[0];
            if ( $xcropt::options{verbose} >= 2 ) {
                Coro::on_enter {
                    print "enter ". $self->{id} .": nready=". Coro::nready ."\n";
                };
                Coro::on_leave {
                    print "leave ". $self->{id} .": nready=". Coro::nready ."\n";
                };
              }
            ## before(), start()
            $self->EVERY::before();
            $self->start();
            ## Waiting for the job "done"
            &jobsched::wait_job_done($self->{id});
            ## after()
	    my $status = &jobsched::get_job_status($self->{id});
	    if ($status eq 'done') {
		my $flag0 = 0;
		my $flag1 = 0;
		until ($flag0 && $flag1) {
		    Coro::AnyEvent::sleep 0.1;
		    if ($xcropt::options{sandbox}) {
			$flag0 = &xcr_exist('-f', "$self->{id}/$self->{JS_stdout}",
					    $self->{rhost}, $self->{rwd});
			$flag1 = &xcr_exist('-f', "$self->{id}/$self->{JS_stderr}",
					    $self->{rhost}, $self->{rwd});
		    } else {
			$flag0 = &xcr_exist('-f', $self->workdir_file($self->{JS_stdout}),
					    $self->{rhost}, $self->{rwd});
			$flag1 = &xcr_exist('-f', $self->workdir_file($self->{JS_stdout}),
					    $self->{rhost}, $self->{rwd});
		    }
		}
		$self->EVERY::LAST::after();
		&jobsched::inventory_write ($self->{id}, 'finished',
					    $self->{rhost}, $self->{rwd});
	    }
	} $self;
        # push (@coros, $job_coro);
        $self->{thread} = $job_coro;
	Coro::AnyEvent::sleep $slp;
    }
    return @array;
}

sub sync {
    my @jobs = @_;
    foreach (@jobs) {
        if ( $xcropt::options{verbose} >= 1 ) {
            print "Waiting for $_->{id}($_->{thread}) finished.\n";
        }
        $_->{thread}->join;
        if ( $xcropt::options{verbose} >= 1 ) {
            print "$_->{id} finished.\n";
        }
    }
    foreach (@jobs) {
	delete($jobsched::initialized_nosync_jobs{$_->{id}});
    }
    return @_;
}

sub belong {
    my $a = shift;
    my @b = @_;
    my $c = 0;
    foreach (@b) {
        if (($a eq $_) ||
            ($a eq ("$_" . "$user::expandingchar")) ||
            ($a =~ /\ARANGE[0-9]+\Z/)
            ) {
            $c = 1;
        }
    }
    return $c;
}

sub prepare_submit {
    my @objs = &expand_and_make(@_);
    foreach (@objs) {
	&prepare_directory($_);
	&submit($_);
    }
    return @objs;
}

sub submit_sync {
    my @objs = &submit(@_);
    return &sync(@objs);
}

sub prepare_submit_sync {
    my @objs = &prepare_submit(@_);
    return &sync(@objs);
}

1;
