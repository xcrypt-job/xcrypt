package builtin;

use base qw(Exporter);
our @EXPORT = qw(expand_and_make
prepare submit sync
prepare_submit submit_sync prepare_submit_sync
add_env add_key add_keys
repeat
);

use strict;
use NEXT;
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

# id, exe$i and arg$i_$j are built-in.
my @allkeys = ('exe', 'before', 'before_in_job', 'after_in_job', 'after', 'env');
my @premembers = ('exe');

my $nilchar = 'nil';
my $argument_name = 'R';

my $current_directory=Cwd::getcwd();
my $inventory_path=File::Spec->catfile($current_directory, 'inv_watch');
=comment
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

sub check_and_alert_elapsed {
    my @job_ids = &jobsched::get_all_job_ids();

    my $sum = 0;
    my %elapseds = ();
    my $length = 0;
    foreach my $i (@job_ids) {
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
    foreach (@job_ids) {
        if (defined $elapseds{$_}) {
            if ( $elapseds{$_} - $average > 300 ) {
                print "Warning: $_ takes more time than the other jobs.\n";
            }
        }
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
=cut

my $default_period = 10;
my @periodic_threads = ();
sub repeat {
    my $new_coro = undef;
    my $sub_or_str = $_[0];
    my $slp = $_[1];
    unless ($slp) { $slp = $default_period; }
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

sub add_env {
    my ($env) = @_;
    unless (defined $env->{location}) {
	$env->{location} = 'remote';
    }
    if ($env->{location} eq 'remote') {
	unless (exists $common::Host_Ssh_Hash{$env->{host}}) {
	    my ($user, $host) = split(/@/, $env->{host});
	    my $ssh = Net::OpenSSH->new($host, (user => $user));
	    $common::Host_Ssh_Hash{$env->{host}} = $ssh;
#	    $ssh->error and die "Unable to establish SFTP connection: " . $ssh->error;
	}
    }
    unless (defined $env->{wd}) {
	my @wd = &xcr_qx($env, 'echo $HOME');
	chomp($wd[0]);
	print $wd[0], "\n";
	unless ($wd[0] eq '') {
	    $env->{wd} = $wd[0];
	} else {
	    die "Set the key wd at $env->{host}\n";
	}
    }
    if ($env->{location} eq 'remote') {
	unless ($xcropt::options{shared}) {
	    &rmt_mkdir($env, $xcropt::options{inventory_path});
	}
    }
    unless (defined $env->{p5l}) {
	my @p5l = &xcr_qx($env, 'echo $PERL5LIB');
	chomp($p5l[0]);
	unless ($p5l[0] eq '') {
	    $env->{p5l} = $p5l[0];
	} else {
	    die "Set the environment varialble \$PERL5LIB at $env->{host}\n";
	}
    }
    unless (defined $env->{sched}) {
	my @sched = &xcr_qx($env, 'echo $XCRJOBSCHED');
	chomp($sched[0]);
	unless ($sched[0] eq '') {
	    $env->{sched} = $sched[0];
	} else {
	    die "Set the environment varialble \$XCRJOBSCHED at $env->{host}\n";
	}
    }
    unless (defined $env->{xd}) {
	    my @xd = &xcr_qx($env, 'echo $XCRYPT');
	    chomp($xd[0]);
	    unless ($xd[0] eq '') {
		$env->{xd} = $xd[0];
	    } else {
		die "Set the environment varialble \$XCRYPT at $env->{host}\n";
	    }
    }
    push(@common::Env, $env);
    return $env;
}

sub add_key {
    my $exist = 0;
    foreach my $i (@_) {
        foreach my $j ((@allkeys, 'id')) {
            if (($i eq $j)
                || ($i =~ /\Aexe[0-9]*/)
                || ($i =~ /\Aarg[0-9]*/)
                || ($i =~ /\Aarg[0-9]*_[0-9]*/)
                ) {
                $exist = 1;
            }
        }
        if ($exist == 1) {
            die "$i has already been added or reserved.\n";
        } elsif ($i =~ /"$user::expanding_char"\Z/) {
            die "Can't use $i as key since $i has $user::expanding_char at its tail.\n";
        } else {
            push(@allkeys, $i);
        }
        $exist = 0;
    }
}

sub add_keys {
    my $exist = 0;
    foreach my $i (@_) {
        foreach my $j ((@allkeys, 'id')) {
            if (($i eq $j)
                || ($i =~ /\Aexe[0-9]*/)
                || ($i =~ /\Aarg[0-9]*/)
                || ($i =~ /\Aarg[0-9]*_[0-9]*/)
                ) {
                $exist = 1;
            }
        }
        if ($exist == 1) {
            die "$i has already been added or reserved.\n";
        } elsif ($i =~ /"$user::expanding_char"\Z/) {
            die "Can't use $i as key since $i has $user::expanding_char at its tail.\n";
        } else {
            push(@premembers, $i);
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
    for ( my $i = 0; $i <= $user::max_exe; $i++ ) {
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
            if ($key =~ /"$user::expanding_char"\Z/) {
                $/ = $user::expanding_char;
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
        my $members = "$_" . $user::expanding_char;
        if ( exists($job{"$members"}) ) {
            # 「ジョブ定義ハッシュ@」の値がスカラである時
            unless ( ref($job{"$members"}) ) {
                for ( my $i = 0; $i < $user::max_range; $i++ ) {
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
    &jobsched::entry_job_id ($self);
    &jobsched::set_job_initialized($self);
    # &jobsched::load_inventory ($self->{id});
    return $self;
}

sub rm_tail {
    my @args = @_;
  JUMP: until ($#args == 0) {
      my $tmp = $args[$#args];
      if ($tmp eq $nilchar) {
	  pop(@args);
      } else {
	  last JUMP;
      }
  }
    return @args;
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
        my $members = "$_" . $user::expanding_char;
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
        my $members = "$_" . $user::expanding_char;
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
    if ($job{"exe$user::expanding_char"}) {
	$job{"exe0$user::expanding_char"} = $job{"exe$user::expanding_char"};
    }
    foreach my $i (0..$user::max_arg) {
	if ($job{"arg$i"}) {
	    $job{"arg0_$i"} = $job{"arg$i"};
#	    delete($job{"arg$i"});
	}
    }
    foreach my $i (0..$user::max_arg) {
	if ($job{"arg$i$user::expanding_char"}) {
	    $job{"arg0_$i$user::expanding_char"} = $job{"arg$i$user::expanding_char"};
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
            if ($key =~ /^JS_/) {
		my ($before_exp_char , $after_exp_char) = split(/@/, $key);
		push(@allkeys, $before_exp_char);
	    }
        }
        $exist = 0;
    }

    my $exist_of_RANGE = 0;
    for ( my $i = 0; $i < $user::max_range; $i++ ) {
        if ( exists($job{"RANGE$i"}) ) {
            if ( ref($job{"RANGE$i"}) eq 'ARRAY' ) {
                my $tmp = @{$job{"RANGE$i"}};
                $exist_of_RANGE = $exist_of_RANGE + $tmp;
            } else {
                warn "X must be an ARRAY reference at \&prepare(\.\.\.\, \'RANGE$i\'\=\> X\,\.\.\.)";
            }
        }
    }
    for ( my $i = 0; $i < $user::max_range; $i++ ) {
        unless ( exists($job{"RANGE$i"}) ) {
            my @tmp = ($nilchar);
            $job{"RANGE$i"} = \@tmp;
        }
    }

    my @objs;
    if ( $exist_of_RANGE ) {
        my @ranges = ();
        for ( my $i = 0; $i < $user::max_range; $i++ ) {
            if ( exists($job{"RANGE$i"}) ) {
                if ( ref($job{"RANGE$i"}) eq 'ARRAY' ) {
                    push(@ranges, $job{"RANGE$i"});
                } else {
                    warn "X must be an ARRAY reference at \&prepare(\.\.\.\, \'RANGE$i\'\=\> X\,\.\.\.)";
                }
            }
        }
        my @tmp = &rm_tail(@ranges);
        my @range = &times(@tmp);
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

sub do_prepared {
    my @jobs = @_;
    foreach my $self (@jobs) {
        &jobsched::set_job_prepared($self);
    }
}

sub prepare{
    my @objs = &expand_and_make(@_);
    &do_prepared(@objs);
    return @objs;
}

sub submit {
    my @array = @_;
#    foreach (@array) {print $_->{host}, "\n";}
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
            ## before()
            unless ( jobsched::job_proceeded_last_time ($self, "submitted") ) {
                $self->EVERY::before();
            }

            ## start()
            unless ( jobsched::job_proceeded_last_time ($self, "queued")
                     && jobsched::request_id_last_time ($self) ) {
                $self->{request_id} = $self->start();
            } else {
                # skip the start() method invocation
                print "$self->{id}: skip the start() method invocation\n";
                &jobsched::set_job_submitted($self);
                $self->{request_id} = jobsched::request_id_last_time ($self);
            }
            &jobsched::write_log (":reqID $self->{id} $self->{request_id}\n");
            &jobsched::set_job_queued($self);

            ## Waiting for the job "done"
            unless ( jobsched::job_proceeded_last_time ($self, "done") ) {
                &jobsched::wait_job_done ($self);
            } else {
                # skip the wait_job_done()
                print "$self->{id}: skip the wait_job_done()\n";
                &jobsched::set_job_running ($self);
                &jobsched::set_job_done ($self);
            }

            ## after()
	    # ジョブスクリプトの最終行の処理を終えたからといってafter()をしてよいとは限らないが，
	    # さすがに念の入れすぎかもしれない．
=comment
	    my $flag0 = 0;
	    my $flag1 = 0;
	    until ($flag0 && $flag1) {
		Coro::AnyEvent::sleep 0.1;
		    $flag0 = &xcr_exist('-f', $self->{JS_stdout}, $self->{env});
		    $flag1 = &xcr_exist('-f', $self->{JS_stdout}, $self->{env});
	    }
=cut

            unless ( jobsched::job_proceeded_last_time ($self, "finished") ) {
                $self->EVERY::LAST::after();
            } else {
                # skip the after() methods invocation
                print "$self->{id}: the after() methods invocation.\n";
            }
	    &jobsched::set_job_finished($self);
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
	&jobsched::exit_job_id($_);
    }
    return @_;
}

sub belong {
    my $a = shift;
    my @b = @_;
    my $c = 0;
    foreach (@b) {
        if (($a eq $_) ||
            ($a eq ("$_" . "$user::expanding_char")) ||
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
        &do_prepared ($_);
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
