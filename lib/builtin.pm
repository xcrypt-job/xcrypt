package builtin;

#use strict;
use NEXT;
use threads;
use threads::shared;
use jobsched;
use usablekeys;
use Cwd;

use base qw(Exporter);
our @EXPORT = qw(prepare submit sync
prepare_submit_sync prepare_submit submit_sync
addkeys addperiodic getelapsedtime
);

my $before_thread = undef;
my $after_thread = undef;
my $before_thread_status : shared = 'killed'; # one of 'killed', 'running', 'signaled'
my $after_thread_status : shared = 'killed' ; # one of 'killed', 'running', 'signaled'
my @jobs_for_before = ();
my @jobs_for_after = ();
my $nilchar = 'nil';
my $argument_name = 'R';
my $before_after_slp = 1;

my $current_directory=Cwd::getcwd();
my $inventory_path=File::Spec->catfile($current_directory, 'inv_watch');
my $reqids_file=File::Spec->catfile($inventory_path, '.request_ids');
my $time_running : shared = undef;
my $time_done_now = undef;
sub getelapsedtime {
    unless ( -e $reqids_file ) { return; }

    my $inventoryfile = File::Spec->catfile ($inventory_path, "$_[0]");
    $time_done_now = time();
    &update_running_and_done_now("$inventoryfile");
    if (defined $time_running) {
        my $elapsed = $time_done_now - $time_running;
        return $elapsed;
    }
}

sub update_running_and_done_now {
    open( INV, "$_[0]" );
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
    unless ( -e $reqids_file ) { return; }
    my @jobids = &getjobids($reqids_file);

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
sub addperiodic {
    if (defined $_[1]) {
	$jobsched::periodicfuns{"$_[0]"} = $_[1];
    } else {
	$jobsched::periodicfuns{"$_[0]"} = $default_period;
    }
}

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

sub addusercustomizablecoremembers {
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

    unless ( $user::separator_nocheck) {
        unless ( $user::separator =~ /\A[!#+,-.@\^_~a-zA-Z0-9]\Z/ ) {
            die "Can't support $user::separator as \$separator.\n";
        }
    }
    my @ranges = &rm_tailnis(@_);
    $job{'id'} = join($user::separator, ($job{'id'}, @ranges));
    &addusercustomizablecoremembers(%job);
    foreach (@usablekeys::allkeys) {
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
                my $tmp = eval($job{"$members"});
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

    &addusercustomizablecoremembers(%job);
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

    &addusercustomizablecoremembers(%job);
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

sub invoke_before {
    my @jobs = @_;
    $before_thread = threads->new( sub {
        while (1) {
            sleep $before_after_slp;
            foreach my $self (@jobs) {
                my $jobname = $self->{id};
                my $stat = &jobsched::get_job_status($jobname);
                if ($stat eq 'prepared') {
                    if (jobsched::is_signaled_job ($jobname)) {
                        &jobsched::inventory_write ($jobname, "aborted");
                        jobsched::delete_signaled_job ($jobname);
                    } else {
                        my $before_ready = $self->EVERY::before_isready();
                        my $failure=0;
                        foreach my $k (keys %{$before_ready}) {
                            unless ($before_ready->{$k}) {
                                $failure=1;
                            }
                        }
                        unless ($failure) {
                            $self->EVERY::before();
                            $self->start();
                        }
                    }
                }
            }
            # signaledだったらスレッド終了
            if ($before_thread_status eq 'signaled') {
                lock ($before_thread_status);
                if ($before_thread_status eq 'signaled') {
                    $before_thread_status = 'killed';
                    cond_signal ($before_thread_status);
                    threads->exit();
                }
            }
        }
                                   });
    $before_thread->detach();
}

sub invoke_after {
    my @jobs = @_;
    $after_thread = threads->new( sub {
        while (1) {
            sleep $before_after_slp;
            foreach my $self (@jobs) {
                my $stat = &jobsched::get_job_status($self->{'id'});
                if ($stat eq 'done') {
                    if ((-e "$self->{'id'}/$self->{'stdofile'}")
                        && (-e "$self->{'id'}/$self->{'stdefile'}")) {
                        my $after_ready = $self->EVERY::LAST::after_isready();
                        my $failure=0;
                        foreach my $k (keys %{$after_ready}) {
                            unless ($after_ready->{$k}) {
                                $failure=1;
                            }
                        }
                        unless ($failure) {
                            $self->EVERY::LAST::after();
                            &jobsched::inventory_write($self->{'id'}, 'finished');
                        }
                    }
                }
            }
            # signaledだったらスレッド終了
            if ($after_thread_status eq 'signaled') {
                lock ($after_thread_status);
                if ($after_thread_status eq 'signaled') {
                    $after_thread_status = 'killed';
                    cond_signal ($after_thread_status);
                    threads->exit();
                }
            }
        }
                                  });
    $after_thread->detach();
}

sub submit {
    my @array = @_;

    # submit対象のジョブ状態を 'prepared' に
    foreach my $self (@array) {
        my $jobname = $self->{id};
        my $stat = &jobsched::get_job_status($jobname);
        # すでに done, finished, abortedなら無視
        unless ( $stat eq 'done' || $stat eq 'finished' || $stat eq 'aborted' ) {
            # xcryptdelされていたら状態をabortedにして処理をとばす
            if (jobsched::is_signaled_job($self->{id})) {
                &jobsched::inventory_write ($jobname, "aborted");
                jobsched::delete_signaled_job ($jobname);
            } else {
                &jobsched::inventory_write($self->{'id'}, 'prepared');
            }
        }
    }
    # beforeスレッドを立ち上げ直し
    if ($before_thread) {
        lock($before_thread_status);
        $before_thread_status = 'signaled';
        cond_wait ($before_thread_status) until ($before_thread_status eq 'killed');
        # print "before_thread killed.\n";
    }
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
    if ($after_thread) {
        lock($after_thread_status);
        $after_thread_status = 'signaled';
        cond_wait ($after_thread_status) until ($after_thread_status eq 'killed');
        # print "after_thread killed.\n";
    }
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

sub prepare_submit {
    my @jobs = &prepare(@_);
    &submit(@jobs);
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

sub prepare {
    my %job = @_;

    &addusercustomizablecoremembers(%job);
    foreach my $key (keys(%job)) {
        unless (&belong($key, 'id', @usablekeys::allkeys)) {
            delete($job{"$key"});
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
            my $obj = &generate(\%job, @{$_});
            push(@objs, $obj);
        }
    } elsif (&MAX(\%job)) { # when parameters except RANGE* exist
        my @params = (0..(&MIN(\%job)-1));
        foreach (@params) {
            my $obj = &generate(\%job, $_);
            push(@objs, $obj);
        }
    } else {
        my $obj = &generate(\%job);
        push(@objs, $obj);
    }
    return @objs;
}

sub prepare_submit_sync {
    my @objs = &prepare_submit(@_);
    return &sync(@objs);
}

1;
