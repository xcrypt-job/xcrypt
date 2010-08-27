package builtin;

use base qw(Exporter);
our @EXPORT = qw(expand_and_make
prepare submit sync
prepare_submit submit_sync prepare_submit_sync
get_local_env add_host add_key add_prefix_of_key
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
my @allprefixes = ('JS_');

my $nil = 'nil';

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

sub get_local_env { return $common::env_d; }

sub add_host {
    my ($env) = @_;
    unless (defined $env->{location}) {	$env->{location} = 'remote'; }
    if ($env->{location} eq 'remote') {
	unless (exists $common::Host_Ssh_Hash{$env->{host}}) {
	    my ($user, $host) = split(/@/, $env->{host});
	    my $ssh = Net::OpenSSH->new($host, (user => $user));
	    $ssh->error and die "Unable to establish SSH connection: " . $ssh->error;
	    $common::Host_Ssh_Hash{$env->{host}} = $ssh;
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

sub add_key           { foreach my $i (@_) { push(@allkeys,     $i); } }
sub add_prefix_of_key { foreach my $i (@_) { push(@allprefixes, $i); } }

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

sub do_initialized {
    my %job = %{$_[0]};
    shift;
    my @range = @_;
    $job{'VALUES'} = \@range;
    my $count_tmp = 0;
    foreach (@range) {
	$job{"VALUE$count_tmp"} = $_;
	$count_tmp++;
    }
    unless ( $user::separator_nocheck) {
        unless ( $user::separator =~ /\A[!#+,-.@\^_~a-zA-Z0-9]\Z/ ) {
            die "Can't support $user::separator as \$separator.\n";
        }
    }

    # generate job objects
    unless (defined $job{"id$user::expander"}) {
	$job{id} = join($user::separator, ($job{id}, @_));
    }
#    foreach my $k (@allkeys) {
    foreach my $tmp_k (keys(%job)) {
	my ($k , $after_k) = split(/@/, $tmp_k);
        my $members = "$k" . $user::expander;

        if ( exists($job{"$members"}) ) {
            unless ( ref($job{"$members"}) ) {
		warn "Can't dereference $members.  Instead evaluate $members";
		@_ = @range;
		$job{"$k"} = eval($job{$members});
            } elsif ( ref($job{"$members"}) eq 'CODE' ) {
                $job{"$k"} = &{$job{"$members"}}(@range);
            } elsif ( ref($job{"$members"}) eq 'ARRAY' ) {
                my @tmp = @{$job{"$members"}};
                $job{"$k"} = $tmp[$count];
            } elsif ( ref($job{"$members"}) eq 'SCALAR' ) {
		$job{"$k"} = ${$job{"$members"}};
            } else {
                die "Can't interpret $members\n";
            }
        }


    }
    my $self = user->new(\%job);

    # aliases
    if (defined $self->{exe0}) {
	$self->{exe} = $self->{exe0};
    }
    my $max_of_arg = &get_max_index_of_arg(%job);
    foreach my $i (0..$max_of_arg) {
	if (defined $self->{"arg0_$i"}) {
	    $self->{"arg$i"} = $self->{"arg0_$i"};
	}
    }

    &jobsched::entry_job_id ($self);
    &jobsched::set_job_initialized($self);
    # &jobsched::load_inventory ($self->{id});
    return $self;
}

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
        foreach my $ukey (@allprefixes) {
            if ($key =~ $ukey) {
                $exist = 1;
            }
        }
        if ($exist == 0) {
            unless (($key =~ /\ARANGE[0-9]+\Z/)
#		    || ($key =~ /\ARANGE[0-9]+:[a-zA-Z_0-9]+\Z/)
                    || ($key =~ /\ARANGES\Z/)
                    || ($key =~ /\AVALUES\Z/))
            {
		print $key, "\n";
                warn "$key doesn't work.  Use :$key or &add_key(\'$key\').\n";
                delete $job{"$key"};
            }
=comment
            if ($key =~ /^JS_/) {
		my ($before_exp_char , $after_exp_char) = split(/@/, $key);
		push(@allkeys, $before_exp_char);
	    }
=cut
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
        &jobsched::set_job_prepared($self);
    }
}

sub prepare{
    my @objs = &expand_and_make(@_);
    $count = 0;
    &do_prepared(@objs);
    return @objs;
}

sub check_status_for_initially {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    unless ($sig) {
        if (jobsched::job_proceeded_last_time ($self, 'finished')) {
            local $jobsched::Warn_illegal_transition = undef;
            &jobsched::set_job_finished($self);
            return 0;
        } else {
            return 1;
        }
    } elsif ( $sig eq 'sig_abort'
              && jobsched::job_proceeded_last_time ($self, 'finished')) {
        jobsched::unset_signal($self);
        local $jobsched::Warn_illegal_transition = undef;
        &jobsched::set_job_finished($self);
        return 0;
    } elsif ( $sig eq 'sig_abort' || $sig eq 'sig_cancel' ) {
        jobsched::delete_record_last_time($self);
        jobsched::unset_signal($self);
        return 1;
    } elsif ($sig eq 'sig_invalidate') {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    }
    warn "Unexpected program path in check_status_for_initially($self->{id}).";
    return 1;
}

sub check_status_for_before {    
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif ( jobsched::job_proceeded_last_time ($self, 'submitted') ) {
        print "$self->{id}: skip the before() method invocation\n";
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_start {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif ( jobsched::job_proceeded_last_time ($self, 'queued')
              && jobsched::request_id_last_time ($self) ) {
        print "$self->{id}: skip the start() method invocation\n";
        &jobsched::set_job_submitted($self);
        $self->{request_id} = jobsched::request_id_last_time ($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_set_job_queued {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_set_job_running {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::job_proceeded_last_time ($self, 'running')) {
        &jobsched::set_job_running($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_wait_job_done {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::job_proceeded_last_time ($self, 'done')) {
        print "$self->{id}: skip the wait_job_done()\n";
        &jobsched::set_job_done($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_after {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::job_proceeded_last_time ($self, 'finished')) {
        print "$self->{id}: the after() methods invocation.\n";
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_set_job_finished {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } else (jobsched::get_job_status ($self) eq 'aborted') {
        return 0;
    } else {
        return 1;
    }
}

sub submit {
    my @array = @_;
    my $slp = 0;
    # my @coros = ();

    foreach my $self (@array) {
        # Create a job thread.
        my $job_coro = Coro::async {
            my $self = $_[0];
            # Output message on entering/leaving the Coro thread.
            if ( $xcropt::options{verbose} >= 2 ) {
                Coro::on_enter {
                    print "enter ". $self->{id} .": nready=". Coro::nready ."\n";
                };
                Coro::on_leave {
                    print "leave ". $self->{id} .": nready=". Coro::nready ."\n";
                };
              }
            ## Resume signal
            jobsched::resume_signal_last_time ($self);
            ## initially()
            unless (check_status_for_initially ($self)) {
                Coro::terminate();
            }
            $self->EVERY::initially(@{$self->{VALUES}});
            ## before()
            if (check_status_for_before ($self)) {
                $self->EVERY::before(@{$self->{VALUES}});
            }
            ## start()
            if (check_status_for_start ($self)) {
                $self->{request_id} = $self->start();
            }
            ## set_job_queued()
            if (check_status_for_set_job_queued ($self)) {
                &jobsched::write_log (":reqID $self->{id} $self->{request_id}\n");
                &jobsched::set_job_queued($self);
            }
            ## If the job was 'running' in the last execution, set it's status to 'running'.
            check_status_for_set_job_running ($self);
            ## Waiting for the job "done"
            if (check_status_for_wait_job_done ($self)) {
                &jobsched::wait_job_done ($self);
            }

	    ## ジョブスクリプトの最終行の処理を終えたからといって
	    ## after()をしてよいとは限らないが念の入れすぎかもしれない．
=comment
	    my $flag0 = 0;
	    my $flag1 = 0;
	    until ($flag0 && $flag1) {
		Coro::AnyEvent::sleep 0.1;
		    $flag0 = &xcr_exist($self->{env}, $self->{JS_stdout});
		    $flag1 = &xcr_exist($self->{env}, $self->{JS_stdout});
	    }
=cut

            ## after()
            if (check_status_for_after ($self)) {
                $self->EVERY::LAST::after(@{$self->{VALUES}});
            }
            $self->EVERY::LAST::finally(@{$self->{VALUES}});
            if (check_status_for_set_job_finished ($self)) {
                &jobsched::set_job_finished($self);
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
