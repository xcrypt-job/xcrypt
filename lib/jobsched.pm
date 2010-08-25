# Job cheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use base qw(Exporter);
our @EXPORT = qw(any_to_string_nl any_to_string_spc
inventory_write_cmdline inventory_write
);

use strict;
use Cwd;
use File::Basename;
use File::Spec;
#use IO::Socket;
use Coro;
use Coro::Socket;
use Coro::AnyEvent;
use Coro::Signal;
use Time::HiRes;
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use Net::OpenSSH;

#use builtin;
use common;
use xcropt;
use jsconfig;

##################################################

### Inventory
my $Inventory_Host = $xcropt::options{localhost};
my $Inventory_Port = $xcropt::options{port}; # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ
my $Inventory_Path = $xcropt::options{inventory_path}; # The directory that system administrative files are created in.

my $Inventory_Write_Cmd = 'inventory_write.pl';

# Administrative files for inventory_write.pl file communication mode.
# Relative path from working directories.
my $Reqfile = File::Spec->catfile($Inventory_Path, 'inventory_req');
my $Ackfile = File::Spec->catfile($Inventory_Path, 'inventory_ack');
my $Opened_File = $Reqfile . '.opened';
my $Ack_Tmpfile = $Ackfile . '.tmp';  # not required?
my $Lockdir = File::Spec->catfile($Inventory_Path, 'inventory_lock');

# Log File
my $Logfile = File::Spec->catfile($Inventory_Path, 'transitions.log');
# Hash table (key,val)=(job ID, the last state in the previous Xcrypt execution)
my %Last_State = (); 
# Hash table (key,val)=(job ID, the request ID saved in the $Logfile)
my %Last_Request_ID = ();

# Hash table (key,val)=(job ID, job objcect)
my %Job_ID_Hash = ();
# The signal to broadcast that a job status is updated.
my $Job_Status_Signal = new Coro::Signal;
# ����֤ξ��֢�����٥�
my %Status_Level = ("initialized"=>0, "prepared"=>1, "submitted"=>2, "queued"=>3,
                    "running"=>4, "done"=>5, "finished"=>6, "aborted"=>7);
# "running"���֤Υ���֤���Ͽ����Ƥ���ϥå��� (key,value)=(request_id, job object)
my %Running_Jobs = ();
# Signal�μ���
my @Signals = ("sig_abort", "sig_cancel", "sig_invalidate");

# ��������ξ����ѹ����Τ��Ԥ��������������륹��å�
my $Watch_Thread = undef;    # accessed from bin/xcrypt
# ����֤�aborted�ˤʤäƤʤ��������å����륹��å�
my $Abort_Check_Thread = undef;
my $Abort_Check_Interval = $xcropt::options{abort_check_interval};
# The thread that checks messages that inventory_write.pl leaves when communication failed
my $Left_Message_Check_Thread = undef;
my $Left_Message_Check_Interval = $xcropt::options{left_message_check_interval};
# �桼������Υ���������ߴؿ���¹Ԥ��륹��å�
# Now obsoleted because it is implemented in builtin.pm?
our $Periodic_Thread = undef; # accessed from bin/xcrypt

# ���Ϥ�Хåե���󥰤��ʤ���STDOUT & STDERR��
$|=1;
select(STDERR); $|=1; select(STDOUT);

# qstat���ޥ�ɤ�¹Ԥ���ɽ�����줿request ID������֤�
sub qstat {
    my @ids;
    my @envs = &get_all_envs();
    foreach my $env (@envs) {
	my $qstat_command = $jsconfig::jobsched_config{$env->{sched}}{qstat_command};
	unless ( defined $qstat_command ) {
	    die "qstat_command is not defined in $env->{sched}.pm";
	}
	my $extractor = $jsconfig::jobsched_config{$env->{sched}}{extract_req_ids_from_qstat_output};
	unless ( defined $extractor ) {
	    die "extract_req_ids_from_qstat_output is not defined in $env->{sched}.pm";
	} elsif ( ref ($extractor) ne 'CODE' ) {
	    die "Error in $env->{sched}.pm: extract_req_ids_from_qstat_output must be a function.";
	}
	my $command_string = any_to_string_spc ($qstat_command);
	unless (common::cmd_executable ($command_string, $env)) {
	    warn "$command_string not executable";
	    return ();
	}
	my @qstat_out = &xcr_qx($env, $command_string, '.');
	my @tmp_ids = &$extractor(@qstat_out);
	foreach (@tmp_ids) {
	    push(@ids, "$env->{host}"."$_");
#	    push(@ids, ($env->{host}, $_));
	}
    }
    return @ids;
}

##############################
# Set the status of job $jobname to $stat by executing an external process.
sub inventory_write {
    my ($self, $stat) = @_;
    my $cmdline = inventory_write_cmdline($self, $stat);
    if ( $xcropt::options{verbose} >= 2 ) { print "$cmdline\n"; }
    &xcr_system($self->{env}, "$cmdline", '.');

    ## Use the following when $Watch_Thread is a Coro.
    # {
    #     my $pid = common::exec_async ($cmdline);
    #     ## polling for checking the child process finished.
    #     ## DO NOT USE blocking waitpid(*,0) for Coros.
    #     # print "Waiting for $pid finished.\n";
    #     # until (waitpid($pid,1)) { Coro::AnyEvent::sleep 0.1; }
    #     # print "$pid finished.\n";
    # }
}

sub inventory_write_cmdline {
    my ($self, $stat) = @_;
    status_name_to_level ($stat); # Valid status name?
    my $write_command=File::Spec->catfile($self->{env}->{xd}, 'bin', $Inventory_Write_Cmd);
    my $timeout = $xcropt::options{comm_timeout};
    if ( $Inventory_Port > 0 ) {
        return "$write_command $self->{id} $stat sock $Inventory_Host $Inventory_Port $timeout";
    } else {
        my $dir = File::Spec->catfile($self->{env}->{wd}, $Lockdir);
        my $req = File::Spec->catfile($self->{env}->{wd}, $Reqfile);
        my $ack = File::Spec->catfile($self->{env}->{wd}, $Ackfile);
        return "$write_command $self->{id} $stat file $dir $req $ack $timeout";
    }
}

##############################
# watch�ν��ϰ�Ԥ����
# for scalar contexts: set_job_status��Ԥä���1�������Ǥʤ����0�����顼�ʤ�-1���֤�
# for list contexts: returns (status(the same to scalar contexts), last_job, last_jobname)
sub handle_inventory {
    my ($line) = @_;
    my ($flag, $job, $job_id);  # return values
    if ($line =~ /^:transition\s+(\S+)\s+(\S+)\s+([0-9]+)/) {
        $job_id = $1;
        my ($status, $tim) = ($2, $3);
        $job = find_job_by_id ($job_id);
        if ($job) {
            if ($status eq 'initialized') {
                set_job_initialized ($job, $tim); $flag=1;
            } elsif ($status eq 'prepared') {
                set_job_prepared ($job, $tim); $flag=1;
            } elsif ($status eq 'submitted') {
                set_job_submitted ($job, $tim); $flag=1;
            } elsif ($status eq 'queued') {
                set_job_queued ($job, $tim); $flag=1;
            } elsif ($status eq 'running') {
                # �ޤ�queued�ˤʤäƤ��ʤ���н񤭹��ޤ���-1���֤����ȤǺ�Ϣ���¥����
                # ������wait�����˺�Ϣ������Τϥǥåɥ�å��ɻߤΤ���
                my $cur_stat = get_job_status ($job);
                if ( $cur_stat eq 'queued' ) {
                    set_job_running ($job, $tim); $flag=1;
                } else {
                    $flag = -1;
                }
            } elsif ($status eq 'done') {
                # �ޤ�running�ˤʤäƤ��ʤ���н񤭹��ޤ���-1���֤����ȤǺ�Ϣ���¥����
                # ������wait�����˺�Ϣ������Τϥǥåɥ�å��ɻߤΤ���
                my $cur_stat = get_job_status ($job);
                if ( $cur_stat eq 'running' ) {
                    set_job_done ($job, $tim); $flag=1;
                } else {
                    $flag = -1;
                }
            } elsif ($status eq 'finished') {
                set_job_finished ($job, $tim); $flag=1;
            } elsif ($status eq 'aborted') {
                set_job_aborted ($job, $tim); $flag=1;
            }
        } else { # The job is not found
            # warn "Inventory \"$line\" is ignored because the job $job_id is not found.";
            $flag = -1;
        }
    } elsif ($line =~/^:del\s+(\S+)/) {         # ����ֺ������
        my $job = find_job_by_id ($1);
        $job->abort();
        $flag = 0;
    } elsif ($line =~/^:delall/) {              # ������ֺ������
        signal_all_jobs (); $flag = 0;
    } else {
        warn "unexpected inventory: \"$line\"\n";
        $flag = -1;
    }
    wantarray ? return ($flag, $job, $job_id) : return $flag;
}

# ����֤ξ����Ѳ���ƻ뤹�륹��åɤ�ư
sub invoke_watch {
    # ����٥�ȥ�ե�������֤����ǥ��쥯�ȥ�����
    unless (-d "$Inventory_Path") {
	mkdir $Inventory_Path, 0755;
    }
    # ��ư
    if ( $Inventory_Port > 0 ) {   # TCP/IP�̿������Τ������
        invoke_watch_by_socket ();
    } else {                       # NFS��ͳ�����Τ������
        invoke_watch_by_file ();
    }
}

# �����ץ����watch��ư��������ɸ����Ϥ�ƻ뤹�륹��åɤ�ư
my $slp = 1;
sub invoke_watch_by_file {
    # �ƻ륹��åɤν���
    $Watch_Thread = async_pool
    {
        my $interval = 1;
        while (1) {
            &wait_and_get_file ($interval);
            my $CLIENT_IN;
            open($CLIENT_IN, '<', $Opened_File) || next;
            my $inv_text = '';
            my $handle_inventory_ret = 0;
            my $handled_job; my $handled_jobname;
            # ���饤����Ȥ���Υ�å�������
            # (0�԰ʾ�Υ�å�������)+(":end"�ǻϤޤ��)
            while (<$CLIENT_IN>) {
                if ( $_ =~ /^:/ ) {
                    if ( $_ =~ /^:end/ ) {
                        # print STDERR "received :end\n";
                        last;
                    }
                } else {
                    # ':' �ǻϤޤ�Ԥ������inventory_file����¸����
                    $inv_text .= $_;
                }
                # ���٥��顼���Ǥ���ʹߤ�handle_inventory�ϤȤФ�
                if ( $handle_inventory_ret >= 0 ) {
                    ($handle_inventory_ret, $handled_job, $handled_jobname) = handle_inventory ($_, 1);
                }
            }
            close($CLIENT_IN);
            ###
            my $CLIENT_OUT = undef;
            until ($CLIENT_OUT) {
                open($CLIENT_OUT, '>', $Ack_Tmpfile) or die "Can't open\n";
                unless ($CLIENT_OUT) {
                    warn ("Failed to make ackfile $Ack_Tmpfile");
                    sleep $slp;
                }
            }
            if ($handle_inventory_ret >= 0) {
                # ���顼���ʤ����inventory�ե�����˥���񤭹����:ack���֤�
                my $inv_save = File::Spec->catfile($Inventory_Path, $handled_jobname);
                open(my $SAVE, '>>', "$inv_save") or die "Failed to write inventory_file $inv_save\n";
                print $SAVE $inv_text;
                close($SAVE);
                print $CLIENT_OUT ":ack\n";
                close($CLIENT_OUT);
            } else {
                # ���顼�������:failed���֤���inventory file�ˤϽ񤭹��ޤʤ���
                print $CLIENT_OUT ":failed\n";
                close($CLIENT_OUT);
            }
            if ($handled_job->{env}->{location} eq 'remote') {
                &put_into($handled_job->{env}, $Ack_Tmpfile, '.');
                &rmt_rename($handled_job->{env}, $Ack_Tmpfile, $Ackfile);
                unlink $Ack_Tmpfile;
            } elsif ($handled_job->{env}->{location} eq 'local') {
                rename $Ack_Tmpfile, $Ackfile;
            }
            unlink $Opened_File;
            Coro::AnyEvent::sleep ($interval);
        }
    };
    return $Watch_Thread;
}

# TCP/IP�̿��ˤ�ꥸ��־��֤��ѹ��������γ���������̿�������դ��륹��åɤ�ư

sub invoke_watch_by_socket {
    my $listen_socket = Coro::Socket->new (LocalAddr => $Inventory_Host,
                                           LocalPort => $Inventory_Port,
                                           Listen => 10,
                                           Proto => 'tcp',
                                           ReuseAddr => 1);
    unless ($listen_socket) { die "Can't bind : $@\n"; }
    $Watch_Thread = async_pool
    {
        my $socket;
        while (1) {
            # print "Waiting for connection.\n";
            $socket = $listen_socket->accept;
            # print "Connection accepted.\n";
            unless ($socket) {next;}
            $socket->autoflush();
            my $inv_text = '';
            my $handle_inventory_ret = 0;
            my ($handled_job, $handled_jobname);
            # ���饤����Ȥ���Υ�å�������
            # (0�԰ʾ�Υ�å�������)+(":end"�ǻϤޤ��)
            while (<$socket>) {
                if ( $_ =~ /^:/ ) {
                    if ( $_ =~ /^:end/ ) {
                        # print STDERR "received :end\n";
                        last;
                    }
                } else {
                    # ':' �ǻϤޤ�Ԥ������inventory_file����¸����
                    $inv_text .= $_;
                }
                # ���٥��顼���Ǥ���ʹߤ�handle_inventory�ϤȤФ�
                if ( $handle_inventory_ret >= 0 ) {
                    ($handle_inventory_ret, $handled_job, $handled_jobname) = handle_inventory ($_, 1);
                }
            }
            if ($handle_inventory_ret >= 0) {
                # ���顼���ʤ����inventory�ե�����˥���񤭹����:ack���֤�
                my $inv_save = File::Spec->catfile($Inventory_Path, $handled_jobname);
                open ( SAVE, ">> $inv_save") or die "Can't open $inv_save\n";
                print SAVE $inv_text;
                close (SAVE);
                $socket->print (":ack\n");
                # print STDERR "sent :ack\n";
            } else {
                # ���顼�������:failed���֤���inventory file�ˤϽ񤭹��ޤʤ���
                $socket->print (":failed\n");
                # print STDERR "sent :failed\n";
            }
            $socket->close();
       }
    };
    return $Watch_Thread;
}

# $jobname���б����륤��٥�ȥ�ե�������ɤ߹����ȿ��
sub load_inventory {
    my ($jobname) = @_;
    my $invfile = File::Spec->catfile($Inventory_Path, $jobname);
    if ( -e $invfile ) {
	open ( IN, "< $invfile" )
	    or warn "Can't open $invfile: $!\n";
	while (<IN>) {
	    handle_inventory ($_);
	}
	close (IN);
    }
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
        warn "No job named $id found.";
        return undef;
    }
}

##############################
# ����־���̾�����֥�٥��
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
our $Warn_illegal_transition = 1;
sub set_job_status {
    my ($self, $stat, $tim) = @_;
    status_name_to_level ($stat); # ͭ����̾���������å�
    unless ($tim) { $tim = time(); }
    if ($Warn_illegal_transition) {
        warn_if_illegal_transition ($self, $stat, $tim);
    }
    write_log (":transition $self->{id} $stat $tim\n");
    print "$self->{id} <= $stat\n";
    {
        $self->{status} = $stat;
        $self->{last_update} = $tim;
        $Job_Status_Signal->broadcast();
    }
    # �¹��楸��ְ�������Ͽ�����
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

# Set job's status to 'aborted' or 'finished' accordign to the job's signal status.
# Do nothing if the job is not signaled.
sub set_job_status_according_to_signal {
    my $self = shift;
    my $sig = $self->{signal};
    if ($sig eq 'sig_abort' || $sig eq 'sig_cancel') {
        set_job_aborted ($self);
        return 'aborted';
    } elsif ($sig eq 'sig_invalidate') {
        local $Warn_illegal_transition = 0;
        set_job_finished ($self);
        return 'finished';
    } else {
        return undef;
    }
}

# ������������������ܤν�����Ȥ�set��¹Ԥ��Ƥ褤����Ƚ��
my %Expected_Previous_Status = (
    "initialized" => ["uninitialized"],
    "prepared" => ["initialized"],
    "submitted" => ["prepared"],
    "queued" => ["submitted"],
    "running" => ["queued"],
    "done" => ["running"],
    "finished" => ["done"],
    "aborted" => ["initialized", "prepared", "submitted", "queued", "running"],
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
      warn "[$self->{id}] transition to $stat at $tim but the previous status is $last_stat (expects one of @expect_stats).";
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
        print "Reading the log file $Logfile\n";
        while (<$LOG>) {
            chomp;
            if ($_ =~ /^:transition\s+(\S+)\s+(\S+)\s+([0-9]+)/ ) {
                my ($id, $stat, $time) = ($1, $2, $3);
                my $prev_stat = $Last_State{$id};
                if ( !$prev_stat
                     || status_name_to_level ($stat) > status_name_to_level ($prev_stat)) {
                    $Last_State{$id} = $stat
                }
            } elsif ($_ =~ /^:reqID\s+(\S+)\s+([0-9]+)/ ) {
                my ($id, $req_id) = ($1, $2);
                $Last_Request_ID{$id} = $req_id;
            }
        }
        foreach my $id (keys %Last_State) {
            print "$id = $Last_State{$id}";
            if ( $Last_Request_ID{$id} ) {
                print " (request_ID=$Last_Request_ID{$id})";
            }
            print "\n";
        }
        close ($LOG);
        print "Finished reading the log file $Logfile\n";
    }
}

# The job proceeded than (or to) $stat in the last Xcrypt execution?
sub job_proceeded_last_time {
    my ($job, $stat) = @_;
    return ( $Last_State{$job->{id}}
             && status_name_to_level ($Last_State{$job->{id}}) >= status_name_to_level($stat) );
}

# Get the job's request ID in the last Xcrypt execution.
sub request_id_last_time {
    my ($job) = @_;
    if ( $Last_Request_ID{$job->{id}} ) {
        return $Last_Request_ID{$job->{id}};
    } else {
        return undef;
    }
}

# �����$self�ξ��֤�$stat�ʾ�ˤʤ�ޤ��Ԥ�
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

##################################################
# "running"�ʥ���ְ����ι���
sub entry_running_job {
    my ($self) = @_;
    my $req_id = $self->{env}->{host} . $self->{request_id};
#    my $req_id = $self->{request_id};
    $Running_Jobs{$req_id} = $self;
    # print STDERR "entry_running_job: $jobname($req_id), #=" . (keys %Running_Jobs) . "\n";
}
sub delete_running_job {
    my ($self) = @_;
    my $req_id = $self->{env}->{host} . $self->{request_id};
#    my $req_id = $self->{request_id};
    if ($req_id) {
        delete ($Running_Jobs{$req_id});
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
    return $sig;
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

# Running_Jobs�Υ���֤�aborted�ˤʤäƤʤ��������å�
# ���֤� "queued" �ޤ��� "running"�ˤ⤫����餺��qstat����������֤����Ϥ���ʤ���Τ�
# aborted�Ȥߤʤ�������־��֥ϥå���򹹿����롥
# �ޤ���signaled�ʥ���֤�qstat�˸��줿��qdel����
### Note:
# ����ֽ�λ���done�񤭹��ߤϥ�����ץ���ʤΤǽ���äƤ���Ϥ���
# ��������NFS�Υ��󥷥��ƥ���ά�ˤ�äƤϴ�ʤ������
# inventory_watch����done�񤭹��ߤ����Τ�Xcrypt���Ϥ��ޤǤδ֤�
# abort_check������ȡ�aborted��񤭹���Ǥ��ޤ���
# �� TCP/IP�Ǥϥ���־����ѹ����θ塤ack���ԤĤ褦�ˤ����ΤǾ嵭�ϵ�����ʤ��Ϥ���
# �� NFS�Ǥ⤽�����٤�
sub check_and_write_aborted {
    my %unchecked;
    {
        # %unchecked <- ($job, $job_ID) that is included in %Running_Jobs but not displayed by qstat
        %unchecked = %Running_Jobs;
        print "check_and_write_aborted:\n";
        my @ids = qstat();
        foreach (@ids) {
            my $job = $unchecked{$_};
            # Delete from %unchecked if the job is displayed by qstat.
            delete ($unchecked{$_});
            # If the job exists but is signaled, qdel it.
            if ($job && get_signal_status($job)) {
                if ($job->qdel_if_queued_or_running()) {
                    # set to 'aborted' or 'finished'
                    set_job_status_according_to_signal ($job);
                }
            }
        }
    }
    # %unchecked�˻ĤäƤ��른��֤�"aborted"�ˤ��롥
    foreach my $req_id ( keys %unchecked ) {
        if ( exists $Running_Jobs{$req_id} ) {
            my $aborted_job = $Running_Jobs{$req_id};
	    my $status = get_job_status($aborted_job);
	    unless (($status eq 'done') || ($status eq 'finished')
                    || common::xcr_exist ($aborted_job->{env}, left_message_file_name($aborted_job, 'done'))) {
		print STDERR "aborted: $req_id: " . $aborted_job->{id} . "\n";
                if ( get_signal_status($aborted_job) eq 'sig_invalidate' ) {
                    local $Warn_illegal_transition = 0;
                    set_job_finished ($aborted_job);
                } else {
                    set_job_aborted ($aborted_job);
                }
	    }
        }
    }
}

# ���Ū�¹�ʸ������Ͽ����Ƥ�������
# our %periodicfuns;
# sub invoke_periodic {
#     $Periodic_Thread = Coro::async_pool {
#        while (1) {
# # �桼����������Ū�¹�ʸ����
#            foreach my $i (keys(%periodicfuns)) {
#                Coro::AnyEvent::sleep $periodicfuns{"$i"};
#                eval "$i"
#            }
#            Coro::AnyEvent::sleep 0.1;
#         }
#    };
# }

sub invoke_abort_check {
    # print "invoke_abort_check.\n";
    $Abort_Check_Thread = Coro::async_pool {
        while (1) {
            Coro::AnyEvent::sleep $Abort_Check_Interval;
            check_and_write_aborted();

            # print_all_job_status();
            ## inv_watch/* ��open��handle_inventory�Ⱦ��ͤ��ƥ��顼�ˤʤ�Τ�
            ## �Ȥꤢ���������ȥ�����
            # &check_and_alert_elapsed();
        }
    };
    # print "invoke_abort_check done.\n";
    return $Abort_Check_Thread;
}

# Check messages that inventory_write.pl leaves when the communication failed.
sub left_message_file_name {
    my ($job, $stat) = @_;
    return "$job->{id}_is_$stat";   # must be eq to inventory_write.pl $Left_Message_File
}
sub invoke_left_message_check {
    $Left_Message_Check_Thread = Coro::async_pool {
        while (1) {
            print "left_message_check:\n";
            foreach my $req_id (keys %Running_Jobs) {
                my $job = $Running_Jobs{$req_id};
                if ( get_job_status($job) eq 'queued') {
                    print "check if ". left_message_file_name($job, 'running'). " exists at $job->{env}->{location}\n";
                    if ( common::xcr_exist ($job->{env}, left_message_file_name($job, 'running')) ) {
                        set_job_running ($job);
                    }
                } 
                if ( get_job_status($job) eq 'running') {
                    print "check if ". left_message_file_name($job, 'done'). " exists at $job->{env}->{location}.\n";
                    if ( common::xcr_exist ($job->{env}, left_message_file_name($job, 'done')) ) {
                        set_job_done ($job);
                    }
                }
            }
            Coro::AnyEvent::sleep $Left_Message_Check_Interval;
        }
    };
    return $Left_Message_Check_Thread;
}

##
sub wait_and_get_file {
    my ($interval) = @_;
    my @envs = &get_all_envs();
  LABEL: while (1) {
      foreach my $env (@envs) {
	  if ($env->{location} eq 'remote') {
	      my $tmp = &rmt_exist($env, $Reqfile);
	      if ($tmp) {
		  &rmt_rename($env, $Reqfile, $Opened_File);
		  &get_from($env, $Opened_File, '.');
		  &rmt_unlink($env, $Opened_File);
		  last LABEL;
	      }
	  } else {
	      if (-e $Reqfile) {
		  rename $Reqfile, $Opened_File;
		  last LABEL;
	      }
	  }
      }
      Coro::AnyEvent::sleep ($interval);
  }
}

1;
