# Job cheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use base qw(Exporter);
our @EXPORT = qw(inventory_write_cmdline get_job_status);

use strict;
use List::Util qw(min);
use Cwd;
use File::Basename;
use File::Spec;
use Coro;
use Coro::Semaphore;
use Coro::AnyEvent;
use Coro::Signal;
use Time::HiRes;
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Path;

use builtin;
use common;
#use xcropt;
use jsconfig;

##################################################

### Inventory
my $Inventory_Path = $xcropt::options{inventory_path}; # The directory that system administrative files are created in.

# Log File
my $Logfile = File::Spec->catfile($Inventory_Path, 'transitions.log');
# Hash table (key,val)=(job ID, the last state, request_id, signal, user@host, sched, prefix, workdir, script, stdout, and stderr in the previous Xcrypt execution)
my %Last_Job = ();
sub get_last_job_id         { return keys(%Last_Job);              }
sub get_last_job_state      { return $Last_Job{$_[0]}{state};      }
sub get_last_job_request_id { return $Last_Job{$_[0]}{request_id}; }
sub get_last_job_signal     { return $Last_Job{$_[0]}{signal};     }
sub get_last_job_userhost   { return $Last_Job{$_[0]}{userhost};   }
sub get_last_job_sched      { return $Last_Job{$_[0]}{sched};      }
sub get_last_job_prefix     { return $Last_Job{$_[0]}{prefix};     }
sub get_last_job_location   { return $Last_Job{$_[0]}{location};   }
sub get_last_job_workdir    { return $Last_Job{$_[0]}{workdir};    }
sub get_last_job_script     { return $Last_Job{$_[0]}{script};     }
sub get_last_job_stdout     { return $Last_Job{$_[0]}{stdout};     }
sub get_last_job_stderr     { return $Last_Job{$_[0]}{stderr};     }
sub get_last_job_savedval   { return $Last_Job{$_[0]}{savedval};   }

# Hash table (key,val)=(job ID, job objcect)
my %Job_ID_Hash = ();
# The signal to broadcast that a job status is updated.
my $Job_Status_Signal = new Coro::Signal;
# ジョブの状態→ランレベル
my %Status_Level = ("initialized"=>0, "prepared"=>1, "submitted"=>2, "queued"=>3, "running"=>4, "done"=>5, "finished"=>6, "aborted"=>7);
# "running"状態のジョブが登録されているハッシュ (key,value)=(request_id, job object)
my %Running_Jobs = ();
# Signalの種類
# A signal is set when a job is made aborted, cancelled, or invalidated
# to indicate that the job is deleted by a user (not accidentally).
my @Signals = ("sig_abort", "sig_cancel", "sig_invalidate");


# Interval of checking whether queued/running jobs are not aborted
# by invoking qstat command [sec]
my $Abort_Check_Interval_Max = $xcropt::options{abort_check_interval};
my $Abort_Check_Interval = $Abort_Check_Interval_Max;
# Interval of checking state transition files (*_is_running/done)
# and signal files (*_to_be_cancelled/uninitialized/invalidated/finished/aborted)
my $Left_Message_Check_Interval = $xcropt::options{left_message_check_interval};
# If true, a job does not become "done" while it remains in "qstat" list
my $Done_After_Queue = $xcropt::options{done_after_queue};
# The thread to perform the above mentioned checking.
my $Status_Check_Thread = undef;


# Warning option (can be bound dynamically using a local declaration)
our $Warn_job_not_found_by_id = 1;
our $Warn_illegal_transition = 1;

# 出力をバッファリングしない（STDOUT & STDERR）
$|=1;
select(STDERR); $|=1; select(STDOUT);

# qstatコマンドを実行して表示されたrequest IDの列を返す
sub qstat {
    my @ids;
    my @envs = &get_all_envs();
    foreach my $env (@envs) {
	my $qstat_command = $jsconfig::jobsched_config{$env->{sched}}{qstat_command};
	unless ( defined $qstat_command ) {
	    warn "qstat_command is not defined in $env->{sched}.pm";
	}
	my $extractor = $jsconfig::jobsched_config{$env->{sched}}{extract_req_ids_from_qstat_output};
	unless ( defined $extractor ) {
	    warn "extract_req_ids_from_qstat_output is not defined in $env->{sched}.pm";
	} elsif ( ref ($extractor) ne 'CODE' ) {
	    warn "Error in $env->{sched}.pm: extract_req_ids_from_qstat_output must be a function.";
	}
	my $command_string = any_to_string_spc ($qstat_command);
#	unless (cmd_executable ($command_string, $env)) {
#	    warn "$command_string not executable";
#	    return ();
#	}
	my @qstat_out = &xcr_qx($env, $command_string, '.');
	my @tmp_ids = &$extractor(@qstat_out);
	foreach (@tmp_ids) {
	    my $index = make_index_of_Running_Jobs($_, $env->{host});
	    push(@ids, $index);
	}
    }
    return @ids;
}

sub inventory_write_cmdline {
    my ($self, $stat) = @_;
    status_name_to_level ($stat); # Valid status name?
    my $cmdline = 'mkdir ' . $self->{id} . '_is_' . $stat;
    if ($jsconfig::jobsched_config{$self->{env}->{sched}}{'left_message_' . "$stat" . '_file_type'} eq 'file') {
	$cmdline = 'touch ' . $self->{id} . '_is_' . $stat;
    }
    return $cmdline;
}

##############################
# job_id_hash
sub entry_job_id {
    my ($self) = @_;
#    print "$self->{id} entried\n";
    $Job_ID_Hash{$self->{id}} = $self;
}

sub get_all_job_ids {
    return keys(%Job_ID_Hash)
}

sub exit_job_id {
    my ($self) = @_;
#    print "$self->{id} exit\n";
    delete($Job_ID_Hash{$self->{id}});
}

sub find_job_by_id {
    my ($id) = @_;
    if ( $Job_ID_Hash{$id} ) {
        return $Job_ID_Hash{$id};
    } else {
        if ($Warn_job_not_found_by_id) {
            warn "No job named $id found.";
        }
        return undef;
    }
}

##############################
# ジョブ状態名→状態レベル数
sub status_name_to_level {
    my ($name, $allow_invalid) = @_;
    if ( exists ($Status_Level{$name}) ) {
        return $Status_Level{$name};
    } else {
        if ($allow_invalid) {
            return -1;
        } else {
            die "status_name_to_level: unexpected status name \"$name\"\n";
        }
    }
}

# Get the status of job
sub get_job_status {
    my ($self) = @_;
    if ( exists $self->{status} ) {
        return $self->{status};
    } else {
        return "uninitialized";
    }
}
# Get the last time when the status of the job updated.
sub get_job_last_update {
    my ($self) = @_;
    if ( exists $self->{last_update} ) {
        return $self->{last_update};
    } else {
        return -1;
    }
}

# Update the status of the job, broadcast the signal
# and, if necessary, entry the job into the "running_job" hash table.
sub set_job_status {
    my ($self, $stat, $tim) = @_;
    status_name_to_level ($stat); # 有効な名前かチェック
    unless ($tim) { $tim = time(); }
    if ($Warn_illegal_transition) {
        warn_if_illegal_transition ($self, $stat, $tim);
    }
    write_log (":transition $self->{id} $stat $tim\n");
    if ($xcropt::options{verbose_transition}) { print STDERR "$self->{id} <= $stat\n"; }
    {
        $self->{status} = $stat;
        $self->{last_update} = $tim;
        $Job_Status_Signal->broadcast();
    }
    # 実行中ジョブ一覧に登録／削除
    if ( $stat eq "queued" ) {
        entry_running_job ($self);
    } elsif ( ($stat eq "aborted") || ($stat eq "done") || ($stat eq "finished")) {
        delete_running_job ($self);
    }
}
sub set_job_initialized  {
    my ($self, $tim) = @_;
    set_job_status ($self, "initialized", $tim);
}
sub set_job_prepared  {
    my ($self, $tim) = @_;
    set_job_status ($self, "prepared", $tim);
}
sub set_job_submitted {
    my ($self, $tim) = @_;
    set_job_status ($self, "submitted", $tim);
}
sub set_job_queued {
    my ($self, $tim) = @_;
    set_job_status ($self, "queued", $tim);
}
sub set_job_running  {
    my ($self, $tim) = @_;
    set_job_status ($self, "running", $tim);
}
sub set_job_done   {
    my ($self, $tim) = @_;
    set_job_status ($self, "done", $tim);
}
sub set_job_finished {
    my ($self, $tim) = @_;
    set_job_status ($self, "finished", $tim);
}
sub set_job_aborted  {
    my ($self, $tim) = @_;
    set_job_status ($self, "aborted", $tim);
}

# Set job's status to 'aborted' or 'finished' according to the job's signal status.
# Do nothing if the job is not signaled.
sub set_job_status_according_to_signal {
    my ($self, $tim) = @_;
    my $sig = get_signal_status ($self);
    my $stat = get_job_status ($self);
    if ($sig eq 'sig_abort') {
        unless ( $stat eq 'aborted' || $stat eq 'finished') {
            set_job_aborted ($self, $tim);
        }
    } elsif ($sig eq 'sig_cancel') {
        unless ( $stat eq 'aborted' ) {
            set_job_aborted ($self, $tim);
        }
        return 'aborted';
    } elsif ($sig eq 'sig_invalidate') {
        unless ( $stat eq 'finished' ) {
            local $Warn_illegal_transition = undef;
            set_job_finished ($self, $tim);
        }
        return 'finished';
    } else {
        return undef;
    }
}

# 更新時刻情報や状態遷移の順序をもとにsetを実行してよいかを判定
my %Expected_Previous_Status = (
    "initialized" => ["uninitialized"],
    "prepared" => ["initialized"],
    "submitted" => ["prepared"],
    "queued" => ["submitted"],
    "running" => ["queued"],
    "done" => ["running"],
    "finished" => ["done"],
    "aborted" => ["initialized", "prepared", "submitted", "queued", "running", "done", "finished"],
    );

sub warn_if_illegal_transition {
  my ($self, $stat, $tim) = @_;
  # check update time
  my $last_update = get_job_last_update ($self);
  if ( $tim < $last_update ) {
      warn "[$self->{id}] transition to $stat at $tim but the last_update is $last_update.";
  }
  # check whether the correct transition order
  my $ok=0;
  my $last_stat = get_job_status ($self);
  my @expect_stats = @{$Expected_Previous_Status{$stat}};
  foreach my $es (@expect_stats) {
      if ( $last_stat eq $es ) {
          $ok = 1; last;
      }
  }
  if ( $ok == 0 ) {
      warn "[$self->{id}] transition to $stat at $tim but the previous status is $last_stat (expects ".join(' or ', @expect_stats).").";
  }
}

# Logging
sub write_log {
    my ($str) = @_;
    open (my $LOG, '>>', $Logfile);
    unless ($LOG) {
        warn "Failed to open the log file $Logfile in write mode";
        return 0;
    } else {
        print $LOG "$str";
        close $LOG;
        return 1;
    }
}
# Invoked once initially (see bin/xcrypt)
sub read_log {
    if (-e $Logfile) {
        open (my $LOG, '<', $Logfile);
        unless ($LOG) {
            warn "Failed to open the log file $Logfile in read mode.";
            return 0;
        }
	if ($xcropt::options{verbose_readlog}) {
	    print STDERR "Reading the log file $Logfile\n";
	}
        while (<$LOG>) {
            chomp;
            if ($_ =~ /^:transition\s+(\S+)\s+(\S+)\s+([0-9]+)/ ) {
                my ($id, $stat, $time) = ($1, $2, $3);
                $Last_Job{$id}{state} = $stat;
            } elsif ($_ =~ /^:reqID\s+(\S+)\s+([0-9]+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ ) {
                $Last_Job{$1}{request_id} = $2;
                $Last_Job{$1}{userhost}   = $3;
                $Last_Job{$1}{sched}      = $4;
                $Last_Job{$1}{prefix}     = $5;
                $Last_Job{$1}{location}   = $6;
                $Last_Job{$1}{workdir}    = $7;
                $Last_Job{$1}{script}     = $8;
                $Last_Job{$1}{stdout}     = $9;
                $Last_Job{$1}{stderr}     = $10;
            } elsif ($_ =~ /^:signal\s+(\S+)\s+(\S+)/ ) {
                my ($id, $sig) = ($1, $2);
                if ( $sig eq 'unset' ) {
                    delete ($Last_Job{$id}{signal});
                } else {
                    $Last_Job{$id}{signal} = $sig;
                }
            } elsif ($_ =~ /^:savedval\s+(\S+)\s+(\S+)\s+(.*)$/ ) {
                my ($id, $mbname, $val) = ($1, $2, $3);
                $Last_Job{$1}{savedval}{$2} = eval ($3);
                print "readlog: \$Last_Job{$1}{savedval}{$2} <-- $Last_Job{$1}{savedval}{$2}\n";
            }
        }
        foreach my $id (keys %Last_Job) {
	    if ($xcropt::options{verbose_laststat}) {
		print STDERR "$id = $Last_Job{$id}{state}";
		if ( $Last_Job{$id}{state} ) {
		    print STDERR " (request_ID=$Last_Job{$id}{request_id})";
		}
		print STDERR "\n";
	    }
        }
        close ($LOG);
	if ($xcropt::options{verbose_readlog}) {
	    print STDERR "Finished reading the log file $Logfile\n";
	}
    }
}

# The job proceeded than (or to) $stat in the last Xcrypt execution?
sub job_proceeded_last_time {
    my ($job, $stat) = @_;
    return ( $Last_Job{$job->{id}}{state}
             && !($Last_Job{$job->{id}}{state} eq 'aborted')
             && status_name_to_level ($Last_Job{$job->{id}}{state}) >= status_name_to_level($stat) );
}

# Get the job's request ID in the last Xcrypt execution.
sub request_id_last_time {
    my ($job) = @_;
    if ( $Last_Job{$job->{id}}{request_id} ) {
        return $Last_Job{$job->{id}}{request_id};
    } else {
        return undef;
    }
}

# Delete the job's record in the last Xcrypt execution.
sub delete_record_last_time {
    my ($job) = @_;
    delete ($Last_Job{$job->{id}}{state});
    delete ($Last_Job{$job->{id}}{request_id});
}

# ジョブ$selfの状態が$stat以上になるまで待つ
sub wait_job_status {
    my ($self, $stat) = @_;
    my $stat_lv = status_name_to_level ($stat);
    # print "$self->{id}: wait for the status changed to $stat($stat_lv)\n";
    until ( &status_name_to_level (&get_job_status ($self))
            >= $stat_lv) {
        $Job_Status_Signal->wait;
    }
    # print "$self->id: exit wait_job_status\n";
}
sub wait_job_initialized    { wait_job_status ($_[0], "initialized"); }
sub wait_job_prepared  { wait_job_status ($_[0], "prepared"); }
sub wait_job_submitted { wait_job_status ($_[0], "submitted"); }
sub wait_job_queued    { wait_job_status ($_[0], "queued"); }
sub wait_job_running   { wait_job_status ($_[0], "running"); }
sub wait_job_done      { wait_job_status ($_[0], "done"); }
sub wait_job_finished  { wait_job_status ($_[0], "finished"); }
sub wait_job_aborted   { wait_job_status ($_[0], "aborted"); }

# Print all the jobs's statuses (for debugging)
sub print_all_job_status {
    foreach my $jn (keys %Job_ID_Hash) {
        print "$jn:" . get_job_status (find_job_by_id ($jn)) . " ";
    }
    print "\n";
}

sub make_index_of_Running_Jobs {
    my ($request_id, $host) = @_;
    return $request_id . '_at_' . $host;
}

##################################################
# "running"なジョブ一覧の更新
sub entry_running_job {
    my ($self) = @_;
    my $index = make_index_of_Running_Jobs($self->{request_id}, $self->{env}->{host});
    $Running_Jobs{$index} = $self;
    # print STDERR "entry_running_job: $jobname($req_id), #=" . (keys %Running_Jobs) . "\n";
}
sub delete_running_job {
    my ($self) = @_;
    my $index = make_index_of_Running_Jobs($self->{request_id}, $self->{env}->{host});
    if ($index) {
        delete ($Running_Jobs{$index});
    }
}

# Signal
sub check_signal_string {
    my $sig = shift;
    foreach (@Signals) {
        if ( $sig eq $_ ) {
            return 1;
        }
    }
    return 0;
}

sub set_signal {
    my ($self, $sig) = @_;
    unless ( check_signal_string ($sig) ) {
        warn "'$sig' is not available as a signal name.";
        return undef;
    }
    $self->{signal} = $sig;
    write_log (":signal $self->{id} $sig\n");
    return $sig;
}
sub unset_signal {
    my $self = shift;
    delete ($self->{signal});
    write_log (":signal $self->{id} unset\n");
}
sub get_signal_status {
    my $self = shift;
    my $sig = $self->{signal};
    if ( check_signal_string ($sig) ) {
        return $sig;
    } else {
        return undef;
    }
}

# Running_Jobsのジョブがabortedになってないかチェック
# 状態が "queued" または "running"にもかかわらず，qstatで当該ジョブが出力されないものを
# abortedとみなし，ジョブ状態ハッシュを更新する．
### Note:
# ジョブ終了後（done書き込みはスクリプト内なので終わっているはず．
# ただし，NFSのコンシステンシ戦略によっては危ないかも．
# *_is_done をジョブ側で生成してから，それがXcrypt実行ホストから認識できるまでの間に
# abort_checkが入ると，abortedを書き込んでしまうことがある）
sub check_and_write_aborted {
    my %unchecked;
    {
        # %unchecked <- ($job, $job_ID) that is included in %Running_Jobs but not displayed by qstat
        %unchecked = %Running_Jobs;
        if ($xcropt::options{verbose_abortcheck}) {
            print STDERR "check_and_write_aborted:\n";
        }
        my @ids = qstat();
        # print "ids: @ids\n";
        foreach (@ids) {
            my $job = $unchecked{$_};
            # Delete from %unchecked if the job is displayed by qstat.
	    # 実は異なるサイトの request_id を一緒くたにしているので
	    # done のジョブを running とするバグがある
            delete ($unchecked{$_});
            # If the job exists but is signaled, qdel it.
            # This is applied when the job is signaled before submitted.
            if ($job && get_signal_status($job)) {
                if ($job->qdel_if_queued_or_running()) {
                    # set to 'aborted' or 'finished'
                    set_job_status_according_to_signal ($job);
                }
            }
        }
    }
    # If sleep_after_qstat option is defined, sleep for a while
    # (typically for avoiding NFS consistency problems)
    { 
        my $slp = 0;
        foreach my $req_id ( keys %unchecked ) {
            my $aborted_job = $Running_Jobs{$req_id};
            my $env = $aborted_job->{env};
            my $slp0 = $jsconfig::jobsched_config{$env->{sched}}{sleep_after_qstat};
            if ($slp0 > $slp) { 
                $slp = $slp0;
            }
        }
        Coro::AnyEvent::sleep $slp;
    }
    # Invoke left_message_check(0) for %unchecked jobs because they may be going to be "done"
    foreach my $req_id ( keys %unchecked ) {
        if ( exists $Running_Jobs{$req_id} ) {
            my $job = $Running_Jobs{$req_id};
            left_message_check (0, $job);
        }
    }
    # Make %unchecked jobs "aborted"
    foreach my $req_id ( keys %unchecked ) {
        if ( exists $Running_Jobs{$req_id} ) {
            my $aborted_job = $Running_Jobs{$req_id};
	    my $status = get_job_status($aborted_job);
            my $env = $aborted_job->{env};
            my $is_alive = $jsconfig::jobsched_config{$env->{sched}}{is_alive};
	    unless (($status eq 'done') || ($status eq 'finished')
                    || xcr_exist ($env, left_message_file_name($aborted_job, 'done'))
                    # Configに関数is_aliveが定義されていて，それが真を返せばまだ生きているとみなす
                    || (ref $is_alive eq 'CODE') && (&{$is_alive}($aborted_job)) )
            {
                if ( get_signal_status($aborted_job) eq 'sig_invalidate' ) {
                    local $Warn_illegal_transition = undef;
                    set_job_finished ($aborted_job);
                } else {
                    if ($xcropt::options{verbose_abort}) {
                        print STDERR "aborted: $req_id: " . $aborted_job->{id} . "\n";
                    }
                    set_job_aborted ($aborted_job);
                }
	    }
        }
    }
}

# Check messages that a job script leaves when the job becomes 'running' or 'done'
# and when xcrypt{del,cancel,invalidate}[all] commands is executed by user.
sub left_message_file_name {   # Transition message file
    my ($job, $stat) = @_;
    return File::Spec->catfile($job->{workdir}, "$job->{id}_is_$stat");
}
sub left_message_file_name_inventory {   # Signal message file
    my ($job, $stat) = @_;
    return File::Spec->catfile($Inventory_Path, "$job->{id}_to_be_$stat");
}

sub left_transition_message_check {
    # If $done_check_only is true, a job does not become "done" even if *_is_done exists.
    # Instead, $Abort_Check_Interval shorten. Then, check_and_write_aborted() will invoke
    # left_transition_message_check(0) after the job does not appear in "qstat" list
    # and it will become "done".
    # If $job is given, check messages only for the job. Otherwise, check for all %Running_Jobs.
    my $done_check_only = shift;
    my $job = shift;
    my @jobs;
    if ($job) {
        @jobs = ($job);
    } else {
        foreach my $req_id (keys %Running_Jobs) {
            push (@jobs, $Running_Jobs{$req_id});
        }
    }
    foreach my $self (@jobs) {
        if ( get_job_status($self) eq 'queued') {
            if (defined $xcropt::options{verbose_leftmessage_all}) {
                print "check if ". left_message_file_name($self, 'running')
                    . " exists at $self->{env}->{host}\n";
            }
            if ( xcr_exist ($self->{env}, left_message_file_name($self, 'running')) ) {
                unless (get_signal_status($self)) {
                    set_job_running ($self);
                } else {
                    set_job_status_according_to_signal($self);
                    $self->qdel();
                }
                if ( $xcropt::options{delete_left_message_file} ) {
                    xcr_unlink ($self->{env}, left_message_file_name($self, 'running'));
                }
            }
        }
        if ( get_job_status($self) eq 'running') {
            if (defined $xcropt::options{verbose_leftmessage_all}) {
                print "check if ". left_message_file_name($self, 'done')
                    . " exists at $self->{env}->{host}.\n";
            }
            if ( xcr_exist ($self->{env}, left_message_file_name($self, 'done')) ) {
                if ( $done_check_only ) {
                    $Abort_Check_Interval = min (1, $Abort_Check_Interval);
                } else {
                    unless (get_signal_status($self)) {
                        set_job_done ($self);
                    } else {
                        set_job_status_according_to_signal($self);
                        $self->qdel();
                    }
                    if ( $xcropt::options{delete_left_message_file} ) {
                        xcr_unlink ($self->{env}, left_message_file_name($self, 'done'));
                    }
                }
            }
        }
    }
}
# Handle signal message file.
# If a job object is given, handle a message for the specified jobs.
# Otherwise, handle for all the signal messages.
sub left_signal_message_check {
    my $self_or_all = shift;
    my @checklist;
    if (ref ($self_or_all) eq 'user') {
	my $id = $self_or_all->{id};
        @checklist = glob File::Spec->catfile($Inventory_Path, $id .'_to_be_*');
    } else {
        @checklist = glob File::Spec->catfile($Inventory_Path, '*_to_be_*');
    }
    foreach my $sigmsg (@checklist) {
        my ($volume, $directories, $file) = File::Spec->splitpath($sigmsg);
        if ( $file =~ /^(\S+)_to_be_(\S+)$/ ) {
            my ($id, $sig) = ($1, $2);
            my $self = find_job_by_id ($id);
            print "$id $sig:\n";
            if ($self) {
                if ( $sig eq 'cancelled' || $sig eq 'uninitialized' ) {
                    $self->cancel();
                    File::Path::rmtree ($sigmsg);
                } elsif ( $sig eq 'invalidated' || $sig eq 'finished' ) {
                    $self->invalidate();
                    File::Path::rmtree ($sigmsg);
                } elsif ( $sig eq 'aborted' ) {
                    $self->abort();
                    File::Path::rmtree ($sigmsg);
		}
            }
        }
    }
}

sub left_message_check {
    # Arguments are just passed to left_transition_message_check() and left_signal_message_check()
    my $done_check_only = shift;
    my $job = shift;
    my $idmes = $job?", $job->{id}":'';
    if (defined $xcropt::options{verbose_leftmessage}) { print STDERR "left_message_check($done_check_only$idmes):\n"; }
    # Transition to running/done
    left_transition_message_check ($done_check_only, $job);
    # Signal
    left_signal_message_check ($job?$job:1);
}

# Create a thread to perform left_message_check() and check_and_write_aborted()
# repeatedly.
sub invoke_status_check {
    unless (-d "$Inventory_Path") {
        mkdir $Inventory_Path, 0755;
    }
    $Status_Check_Thread = Coro::async_pool {
        my $rem_lmsg = $Left_Message_Check_Interval;
        my $rem_abrt = $Abort_Check_Interval; 
        while (1) {
            my $slp = min($rem_lmsg, $rem_abrt);
            Coro::AnyEvent::sleep $slp;
            $rem_lmsg -= $slp; $rem_abrt -= $slp;
            if ( $rem_lmsg <= 0 ) {
                left_message_check($Done_After_Queue);
                $rem_lmsg += $Left_Message_Check_Interval;
            }
            if ( $rem_abrt <= 0 ) {
                check_and_write_aborted();
                $rem_abrt += $Abort_Check_Interval;
                $Abort_Check_Interval = min($Abort_Check_Interval*2, $Abort_Check_Interval_Max);
            }
        }
    };
    return $Status_Check_Thread;
}

1;
