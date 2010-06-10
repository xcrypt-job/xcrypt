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

my $rsh_command = $xcropt::options{rsh};
##################################################

### Inventory
my $inventory_host = $xcropt::options{localhost};
my $inventory_port = $xcropt::options{port}; # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ
my $inventory_path = $xcropt::options{inventory_path};

my $Inventory_Write_Cmd = 'inventory_write.pl';

# for inventory_write_file
my $REQFILE = File::Spec->catfile($inventory_path, 'inventory_req');
my $ACKFILE = File::Spec->catfile($inventory_path, 'inventory_ack');
my $REQ_TMPFILE = $REQFILE . '.tmp';
my $ACK_TMPFILE = $ACKFILE . '.tmp';  # not required?
my $LOCKDIR = File::Spec->catfile($inventory_path, 'inventory_lock');

# Hash table (key,val)=(job ID, job objcect)
my %Job_ID_Hash = ();
# The signal to broadcast that a job status is updated.
my $Job_Status_Signal = new Coro::Signal;
# ����֤ξ��֢�����٥�
my %Status_Level = ("initialized"=>0, "prepared"=>1, "submitted"=>2, "queued"=>3,
                    "running"=>4, "done"=>5, "finished"=>6, "aborted"=>7);
# "running"���֤Υ���֤���Ͽ����Ƥ���ϥå��� (key,value)=(request_id, job object)
my %Running_Jobs = ();
# delete��������������֤���Ͽ����Ƥ���ϥå��� (key,value)=(jobname,signal_val)
my %Signaled_Jobs = ();
my $All_Jobs_Signaled = undef;

# ��������ξ����ѹ����Τ��Ԥ��������������륹��å�
my $watch_thread = undef;    # accessed from bin/xcrypt
# ����֤�aborted�ˤʤäƤʤ��������å����륹��å�
my $abort_check_thread = undef;
my $abort_check_interval = $xcropt::options{abort_check_interval};
# �桼������Υ���������ߴؿ���¹Ԥ��륹��å�
our $periodic_thread = undef; # accessed from bin/xcrypt

# ���Ϥ�Хåե���󥰤��ʤ���STDOUT & STDERR��
$|=1;
select(STDERR); $|=1; select(STDOUT);

##################################################
# qdel���ޥ�ɤ�¹Ԥ��ƻ��ꤵ�줿����֤򻦤�
# ��⡼�ȼ¹�̤�б�
sub qdel {
    my ($self) = @_;
    # qdel���ޥ�ɤ�config�������
    my $qdel_command = $jsconfig::jobsched_config{$ENV{XCRJOBSCHED}}{qdel_command};
    unless ( defined $qdel_command ) {
        die "qdel_command is not defined in $ENV{XCRJOBSCHED}.pm";
    }
    my $req_id = $self->{request_id};
    if ($req_id) {
        # execute qdel
        my $command_string = any_to_string_spc ("$qdel_command ", $req_id);
        if (common::cmd_executable ($command_string, $self)) {
            print "Deleting $self->{id} (request ID: $req_id)\n";
            common::exec_async ($command_string);
        } else {
            warn "$command_string not executable.";
        }
    }
}

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
	unless (common::cmd_executable ($command_string, $_)) {
	    warn "$command_string not executable";
	    return ();
	}
	my @qstat_out = &xcr_qx($command_string, '.',  $env);
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
    &xcr_qx("$cmdline", '.', $self->{env});

    ## Use the following when $watch_thread is a Coro.
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
    if ( $inventory_port > 0 ) {
        return "$write_command $self->{id} $stat sock $inventory_host $inventory_port";
    } else {
	my $dir = File::Spec->catfile($self->{env}->{wd}, $LOCKDIR);
	my $req = File::Spec->catfile($self->{env}->{wd}, $REQFILE);
	my $ack = File::Spec->catfile($self->{env}->{wd}, $ACKFILE);
	return "$write_command $self->{id} $stat file $dir $req $ack";
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
                set_job_done ($job, $tim); $flag=1;
            } elsif ($status eq 'finished') {
                set_job_finished ($job, $tim); $flag=1;
            } elsif ($status eq 'aborted') {
                set_job_aborted ($job, $tim); $flag=1;
            }
        } else {
            warn "Inventory \"$line\" is ignored because the job $job_id is not found.";
            $flag = 0;
        }
    } elsif ($line =~/^:del\s+(\S+)/) {         # ����ֺ������
        my $job = find_job_by_id ($1);
        entry_signaled_job ($1); $flag = 0;
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
    unless (-d "$inventory_path") {
	mkdir $inventory_path, 0755;
    }
    # ��ư
    if ( $inventory_port > 0 ) {   # TCP/IP�̿������Τ������
        invoke_watch_by_socket ();
    } else {                       # NFS��ͳ�����Τ������
        invoke_watch_by_file ();
    }
}

# �����ץ����watch��ư��������ɸ����Ϥ�ƻ뤹�륹��åɤ�ư
my $slp = 1;
sub invoke_watch_by_file {
    # �ƻ륹��åɤν���
    $watch_thread = async_pool
    {
        my $interval = 0.5;
        while (1) {
	    &wait_and_get_file ($REQFILE, $interval);
	    my $CLIENT_IN;
	    open($CLIENT_IN, '<', $REQFILE) || next;
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
		open($CLIENT_OUT, '>', $ACK_TMPFILE) or die "Can't open\n";
		unless ($CLIENT_OUT) {
		    warn ("Failed to make ackfile $ACK_TMPFILE");
		    sleep $slp;
		}
	    }
	    if ($handle_inventory_ret >= 0) {
		# ���顼���ʤ����inventory�ե�����˥���񤭹����:ack���֤�
		my $inv_save = File::Spec->catfile($inventory_path, $handled_jobname);
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
	    &rmt_put($ACK_TMPFILE, $handled_job->{env});
	    &xcr_rename($ACK_TMPFILE, $ACKFILE, $handled_job->{env});
	    unlink $ACK_TMPFILE;
	    unlink $REQFILE;
	    Coro::AnyEvent::sleep ($interval);
	}
    }
}

my %ssh_opts = (
    copy_attrs => 1,     # -p��Ʊ�������ꥸ�ʥ�ξ�����ݻ�
    recursive => 1,       # -r��Ʊ�����Ƶ�Ū�˥��ԡ�
    bwlimit => 40000,  # -l��Ʊ����ž���̤Υ�ߥåȤ�Kbitñ�̤ǻ���
    glob => 1,               # �ե�����̾�ˡ�*�פ�Ȥ���褦�ˤ��롣
    quiet => 1,              # ��Ľ��ɽ������
    );

# TCP/IP�̿��ˤ�ꥸ��־��֤��ѹ��������γ���������̿�������դ��륹��åɤ�ư

sub invoke_watch_by_socket {
    my $listen_socket = Coro::Socket->new (LocalAddr => $inventory_host,
                                           LocalPort => $inventory_port,
                                           Listen => 10,
                                           Proto => 'tcp',
                                           ReuseAddr => 1);
    unless ($listen_socket) { die "Can't bind : $@\n"; }
    $watch_thread = async_pool
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
                my $inv_save = File::Spec->catfile($inventory_path, $handled_jobname);
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
}

# $jobname���б����륤��٥�ȥ�ե�������ɤ߹����ȿ��
sub load_inventory {
    my ($jobname) = @_;
    my $invfile = File::Spec->catfile($inventory_path, $jobname);
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
    my ($name) = @_;
    if ( exists ($Status_Level{$name}) ) {
        return $Status_Level{$name};
    } else {
        die "status_name_to_runlevel: unexpected status name \"$name\"\n";
    }
}

# Get the status of job
sub get_job_status {
    my ($self) = @_;
    if ( exists $self->{status} ) {
        return $self->{status};
    } else {
        return "initialized";
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
    status_name_to_level ($stat); # ͭ����̾���������å�
    print "$self->{id} <= $stat\n";
    {
        $self->{status} = $stat;
        $self->{last_update} = $tim;
        $Job_Status_Signal->broadcast();
    }
    # �¹��楸��ְ�������Ͽ�����
    if ( $stat eq "running" ) {
        entry_running_job ($self);
    } else {
        delete_running_job ($self);
    }
}
sub set_job_initialized  {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    if (do_set_p ($self, $tim, "initialized", "initialized", "submitted", "queued", "running", "aborted") ) {
        set_job_status ($self, "initialized", $tim);
    }
}
sub set_job_prepared  {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    if (do_set_p ($self, $tim, "prepared", "initialized") ) {
        set_job_status ($self, "prepared", $tim);
    }
}
sub set_job_submitted {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    if (do_set_p ($self, $tim, "submitted", "prepared") ) {
        set_job_status ($self, "submitted", $tim);
    }
}
sub set_job_queued {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    if (do_set_p ($self, $tim, "queued", "submitted" ) ) {
        set_job_status ($self, "queued", $tim);
    }
}
sub set_job_running  {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    if (do_set_p ($self, $tim, "running", "queued" ) ) {
        set_job_status ($self, "running", $tim);
    }
}
sub set_job_done   {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    # finished��done �ϥ�ȥ饤�ΤȤ���ͭ������
    if (do_set_p ($self, $tim, "done", "running", "finished" ) ) {
        set_job_status ($self, "done", $tim);
    }
}
sub set_job_finished {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    if (do_set_p ($self, $tim, "finished", "done" ) ) {
        set_job_status ($self, "finished", $tim);
    }
}
sub set_job_aborted  {
    my ($self, $tim) = @_;
    unless ($tim) { $tim = time(); }
    my $curstat = get_job_status ($self);
    if (do_set_p ($self, $tim, "aborted", "initialized", "prepared", "submitted", "queued", "running" )
        && $curstat ne "done" && $curstat ne "finished" ) {
        set_job_status ($self, "aborted", $tim);
    }
}
# ������������������ܤν�����Ȥ�set��¹Ԥ��Ƥ褤����Ƚ��
sub do_set_p {
  my ($self, $tim, $stat, @e_stats) = @_;
  my $who = "set_job_$stat";
  my $last_update = get_job_last_update ($self);
  # print "$self->{id}: cur=$tim, last=$last_update\n";
  if ( $tim > $last_update ) {
      expect_job_stat ($who, $self, 1, @e_stats);
      return 1;
  } elsif ( $tim == $last_update ) {
      if ( $stat eq get_job_status($self) ) {
          return 0;
      } else {
          return expect_job_stat ($who, $self, 0, @e_stats);
      }
  } else {
      return 0;
  }
}
# �����$self�ξ��֤���$who�ˤ��������ܤδ��Ԥ����Ρ�@e_stats�Τɤ줫�ˤǤ��뤫������å�
sub expect_job_stat {
    my ($who, $self, $do_warn, @e_stats) = @_;
    my $stat = get_job_status($self);
    foreach my $es (@e_stats) {
        if ( $stat eq $es ) {
            return 1;
        }
    }
    if ( $do_warn ) {
        print "$who expects $self->{id} is (or @e_stats), but $stat.\n";
    }
    return 0;
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

# ���٤ƤΥ���֤ξ��֤���ϡʥǥХå��ѡ�
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
    $Running_Jobs{$req_id} = $self;
    # print STDERR "entry_running_job: $jobname($req_id), #=" . (keys %Running_Jobs) . "\n";
}
sub delete_running_job {
    my ($self) = @_;
#    my $req_id = $self->{request_id};
    my $req_id = $self->{env}->{host} . $self->{request_id};
    if ($req_id) {
        delete ($Running_Jobs{$req_id});
    }
}

sub entry_signaled_job {
    my ($self) = @_;
    $Signaled_Jobs{$self->{id}} = 1;
    print "$self->{id} is signaled to be deleted.\n";
}
sub signal_all_jobs {
    $All_Jobs_Signaled = 1;
    print "All jobs are signaled to be deleted.\n";
}
sub delete_signaled_job {
    my ($self) = @_;
    if ( exists $Signaled_Jobs{$self->{id}} ) {
        delete $Signaled_Jobs{$self->{id}};
    }
}
sub is_signaled_job {
    return ($All_Jobs_Signaled || $Signaled_Jobs{$_[0]});
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
        # %Running_Jobs �Τ�����qstat��ɽ������ʤ��ä�����֤�%unchecked�˻Ĥ�
        {
            %unchecked = %Running_Jobs;
        }
        print "check_and_write_aborted:\n";
        # foreach my $j ( keys %Running_Jobs ) { print " " . $Running_Jobs{$j} . "($j)"; }
        my @ids = qstat();
        foreach (@ids) {
            my $job = $unchecked{$_};
            delete ($unchecked{$_});
            # If the job exists but is signaled, qdel it.
            if ($job && is_signaled_job($job)) {
                delete_signaled_job($job);
                qdel ($job);
            }
        }
    }
    # %unchecked�˻ĤäƤ��른��֤�"aborted"�ˤ��롥
    foreach my $req_id ( keys %unchecked ) {
        if ( exists $Running_Jobs{$req_id} ) {
            my $aborted_job = $Running_Jobs{$req_id};
            print STDERR "aborted: $req_id: " . $aborted_job->{id} . "\n";
            set_job_aborted ($aborted_job);
        }
    }
}

# ���Ū�¹�ʸ������Ͽ����Ƥ�������
# our %periodicfuns;
# sub invoke_periodic {
#     $periodic_thread = Coro::async_pool {
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
    $abort_check_thread = Coro::async_pool {
        while (1) {
            Coro::AnyEvent::sleep $abort_check_interval;
            check_and_write_aborted();

            # print_all_job_status();
            ## inv_watch/* ��open��handle_inventory�Ⱦ��ͤ��ƥ��顼�ˤʤ�Τ�
            ## �Ȥꤢ���������ȥ�����
            # &check_and_alert_elapsed();
        }
    };
    # print "invoke_abort_check done.\n";
}

1;
