package builtin;

use base qw(Exporter);
our @EXPORT = qw(expand_and_make
prepare submit sync
prepare_submit submit_sync prepare_submit_sync
add_env add_key
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
my @allkeys = ('id', 'before', 'before_in_job', 'after_in_job', 'after', 'env');

my $nil = 'nil';
#my $argument_name = 'R';

my $count = 0;

=comment
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
        foreach my $j ((@allkeys)) {
            if (($i eq $j)
                || ($i =~ /\Aexe[0-9]*\Z/)
                || ($i =~ /\Aarg[0-9]*\Z/)
                || ($i =~ /\Aarg[0-9]*_[0-9]*\Z/)
                || ($i =~ /\ARANGE[0-9]*\Z/)
                || ($i =~ /\ARANGES\Z/)
                ) {
                $exist = 1;
            }
        }
        if ($exist == 1) {
            die "$i has already been added or reserved.\n";
        } elsif ($i =~ /"$user::expander"\Z/) {
            die "Can't use $i as key since $i's tail is $user::expander.\n";
	} else {
	    push(@allkeys, $i);
        }
        $exist = 0;
    }
}

sub max {
    my @array = @_;
    my $max = -1;
    until (@array == ()) {
	my $tmp = shift(@array);
	if ($tmp > $max) {
	    $max = $tmp;
	}
    }
    return $max;
}
sub get_max_index {
    my $arg = shift;
    my %job = @_;
    my @ret;
    my $pat0;
    my $pat1;
    my $pat2;
    if ($arg eq 'range') {
	$pat0 = '\ARANGE[0-9]+\Z';
	$pat1 = '[0-9]+\Z';
    } elsif ($arg eq 'exe') {
	$pat0 = '\Aexe[0-9]+';
	$pat1 = '[0-9]+';
    } elsif ($arg eq 'arg') {
	$pat0 = '\Aarg[0-9]+';
	$pat1 = '[0-9]+';
    } elsif ($arg eq 'first') {
	$pat0 = '\Aarg[0-9]+_[0-9]+';
	$pat1 = '[0-9]+';
    } elsif ($arg eq 'second') {
	$pat0 = '\Aarg[0-9]+_[0-9]+';
	$pat1 = '[0-9]+_';
    }
    foreach my $key (keys(%job)) {
	if ($key =~ /$pat0/) {
	    if ($key =~ /$pat1/) {
		if ($arg eq 'second') {
		    push(@ret, $'); #'
		} else {
		    push(@ret, $&);
		}
	    }
	}
    }
    my $max = &max(@ret);
    return $max;
}
sub get_max_index_of_range             { return &get_max_index('range',  @_); }
sub get_max_index_of_exe               { return &get_max_index('exe',    @_); }
sub get_max_index_of_arg               { return &get_max_index('arg',    @_); }
sub get_max_index_of_first_arg_of_arg  { return &get_max_index('first',  @_); }
sub get_max_index_of_second_arg_of_arg { return &get_max_index('second', @_); }

sub do_initialized {
    my %job = %{$_[0]};
    shift;
    unless ( $user::separator_nocheck) {
        unless ( $user::separator =~ /\A[!#+,-.@\^_~a-zA-Z0-9]\Z/ ) {
            die "Can't support $user::separator as \$separator.\n";
        }
    }

    # generate job objects
    unless (defined $job{"id$user::expander"}) {
	$job{id} = join($user::separator, ($job{id}, @_));
    }
    foreach (@allkeys) {
        my $members = "$_" . $user::expander;
        if ( exists($job{"$members"}) ) {
            unless ( ref($job{"$members"}) ) {
		warn "Can't dereference $members";
=comment
		foreach my $i (0..($#ranges)) {
                    my $arg = $argument_name . $i;
                    my $tmp = eval "$ranges[$i];";
                    eval "our \$$arg = $tmp;";
                }
=cut
#		$job{"$_"} = eval($job{$members});
            } elsif ( ref($job{"$members"}) eq 'CODE' ) {
                $job{"$_"} = &{$job{"$members"}}(@_);
            } elsif ( ref($job{"$members"}) eq 'ARRAY' ) {
                my @tmp = @{$job{"$members"}};
                $job{"$_"} = $tmp[$count];
            } elsif ( ref($job{"$members"}) eq 'SCALAR' ) {
		$job{"$_"} = ${$job{"$members"}};
            } else {
                die "Can't interpre the value of $members \n";
            }
        }
    }
    my $self = user->new(\%job);
    &jobsched::entry_job_id ($self);
    &jobsched::set_job_initialized($self);
    # &jobsched::load_inventory ($self->{id});
    return $self;
}

sub times_loop {
    if (@_ == ()) { return (); }
    my @arg = @_;
    my @ret;
    until (@arg == ()) {
	my $head = shift(@arg);
	if (@ret == ()) {
	    foreach my $k (@$head) {
		push(@ret, [$k]);
	    }
	} else {
	    my @tmp;
	    foreach my $i (@ret) {
		foreach my $j (@$head) {
		    my @foo = @$i;
		    push(@foo, $j);
		    push(@tmp, \@foo);
		}
	    }
	    @ret = @tmp;
	}
    }
    return @ret;
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

=comment
sub MAX {
    my %job = @_;
    my $num = 0;

    foreach (@allkeys) {
        my $members = "$_" . $user::expander;
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

    foreach (@allkeys) {
        my $members = "$_" . $user::expander;
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
=cut

sub expand_and_make {
    my %job = @_;

    # aliases
    if ($job{exe}) {
	$job{exe0} = $job{exe};
	delete($job{exe});
    }
    if ($job{"exe$user::expander"}) {
	$job{"exe0$user::expander"} = $job{"exe$user::expander"};
	delete($job{"exe$user::expander"});
    }
    my $max_of_arg = &get_max_index_of_arg(%job);
    foreach my $i (0..$max_of_arg) {
	if ($job{"arg$i"}) {
	    $job{"arg0_$i"} = $job{"arg$i"};
	    delete($job{"arg$i"});
	}
    }
    foreach my $i (0..$max_of_arg) {
	if ($job{"arg$i$user::expander"}) {
	    $job{"arg0_$i$user::expander"} = $job{"arg$i$user::expander"};
	    delete($job{"arg$i$user::expander"});
	}
    }

    # add_key for built-in keys "exe*", "arg*" and ":*"
    my $max_of_exe    = &get_max_index_of_exe(%job);
    my $max_of_first  = &get_max_index_of_first_arg_of_arg(%job);
    my $max_of_second = &get_max_index_of_second_arg_of_arg(%job);
    for ( my $i = 0; $i <= $max_of_exe; $i++ )   { push(@allkeys, "exe$i"); }
    for ( my $i = 0; $i <= $max_of_first; $i++ ) {
	push(@allkeys, "arg$i");
	for ( my $j = 0; $j <= $max_of_second; $j++ ) {
            push(@allkeys, "arg$i".'_'."$j");
	}
    }
    foreach my $key (keys(%job)) {
        if ($key =~ /\A:/) {
            if ($key =~ /"$user::expander"\Z/) {
                $/ = $user::expander;
                chomp $key;
            }
	    push(@allkeys, $key);
        }
    }

    # disble keys without by add_key
    foreach my $key (keys(%job)) {
        my $exist = 0;
        foreach my $ukey (@allkeys) {
            if (($key eq $ukey) || ($key eq ($ukey . "$user::expander"))) {
                $exist = 1;
            }
        }
        if ($exist == 0) {
            unless (($key =~ /\ARANGE[0-9]+\Z/)
                    || ($key =~ /\ARANGES\Z/)
                    || ($key =~ /^JS_/))        # for jobscheduler options
            {
		print $key, "\n";
                warn "$key doesn't work.  Use :$key or &add_key(\'$key\').\n";
                delete $job{"$key"};
            }
            if ($key =~ /^JS_/) {
		my ($before_exp_char , $after_exp_char) = split(/@/, $key);
		push(@allkeys, $before_exp_char);
	    }
        }
        $exist = 0;
    }

    # expand
    my $max_of_range = &get_max_index_of_range(%job);
    my @objs;
    my @range;
    my $self;
    if (defined $job{'RANGES'}) {
	@range = &times(@{$job{'RANGES'}});
    } elsif ( $max_of_range != -1 ) {
        my @ranges = ();
        for ( my $i = 0; $i <= $max_of_range; $i++ ) {
            if ( exists($job{"RANGE$i"}) ) {
                if ( ref($job{"RANGE$i"}) eq 'ARRAY' ) {
                    push(@ranges, $job{"RANGE$i"});
                } else {
                    warn "The value of RANGE$i must be an ARRAY reference";
                }
            } else {
		my @temp = ($nil);
		$job{"RANGE$i"} = \@temp;
		push(@ranges, $job{"RANGE$i"});
	    }
        }
        @range = &times(@ranges);
=comment
    } elsif (&MAX(\%job)) { # when parameters except RANGE* exist
        my @params = (0..(&MIN(\%job)-1));
        foreach (@params) {
            my $self = &do_initialized(\%job, $_);
            push(@objs, $self);
        }
=cut
    } else {
        @range = ([]);
    }
    foreach (@range) {
	$self = &do_initialized(\%job, @{$_});
	$count++;
	push(@objs, $self);
    }
    return @objs;
}

sub do_prepared {
    my @jobs = @_;
    foreach my $self (@jobs) {
=comment
	my $last_stat = &jobsched::get_job_status ($self);

	if ( jobsched::is_signaled_job ($self) ) {
	    # If the job is 'xcryptdel'ed, make it 'aborted' and skip
	    &jobsched::inventory_write ($self, "aborted");
	    &jobsched::delete_signaled_job ($self);
	} elsif ( $last_stat eq 'finished' ) {
	    # Skip if the job is 'done' or 'finished'
	    &jobsched::inventory_write ($self, "done");
	} elsif ( $last_stat eq 'done') {
	} else {
	    unless ( $last_stat eq 'aborted' ) {
		# xcryptdelされていたら状態をabortedにして処理をとばす
		if (jobsched::is_signaled_job($self)) {
		    &jobsched::inventory_write($self, "aborted");
		    &jobsched::delete_signaled_job($self);
#		push (@coros, undef);
		    next;
		} else {
		    &jobsched::set_job_prepared($self);
		}
	    }
	}
=cut
        &jobsched::set_job_prepared($self);
    }
}

sub prepare{
    my @objs = &expand_and_make(@_);
    $count = 0;
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
            ## before()
            unless ( jobsched::job_proceeded_last_time ($self, 'submitted') ) {
                $self->EVERY::before();
            } else {
                print "$self->{id}: skip the before() method invocation\n";
            }

            ## start()
            unless ( jobsched::job_proceeded_last_time ($self, 'queued')
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

            # If the job was 'running' in the last execution, set it's status to 'running'.
            if ( jobsched::job_proceeded_last_time ($self, 'running') ) {
                &jobsched::set_job_running($self);
            }

            ## Waiting for the job "done"
            unless ( jobsched::job_proceeded_last_time ($self, 'done') ) {
                &jobsched::wait_job_done ($self);
            } else {
                # skip the wait_job_done()
                print "$self->{id}: skip the wait_job_done()\n";
                &jobsched::set_job_done ($self);
            }

            ## after()
	    # ジョブスクリプトの最終行の処理を終えたからといって
	    # after()をしてよいとは限らないが念の入れすぎかもしれない．
=comment
	    my $flag0 = 0;
	    my $flag1 = 0;
	    until ($flag0 && $flag1) {
		Coro::AnyEvent::sleep 0.1;
		    $flag0 = &xcr_exist('-f', $self->{JS_stdout}, $self->{env});
		    $flag1 = &xcr_exist('-f', $self->{JS_stdout}, $self->{env});
	    }
=cut
            unless ( jobsched::job_proceeded_last_time ($self, 'finished') ) {
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
