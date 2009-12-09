# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use strict;
use threads;
use threads::shared;
use Cwd;
use File::Basename;
use File::Spec;
use IO::Socket;
use common;
use xcropt;
use jsconfig;
# use Thread::Semaphore;

##################################################

my $current_directory=Cwd::getcwd();
my $jobsched = $ENV{'XCRJOBSCHED'};

### Inventory
my $inventory_host = qx/hostname/;
chomp $inventory_host;
my $inventory_port = $xcropt::options{port};           # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ(unstable!)
# print "inventory_port: $inventory_port\n"
my $inventory_path=File::Spec->catfile($current_directory, 'inv_watch');
my $reqids_file=File::Spec->catfile($inventory_path, '.request_ids');

my $write_command = undef;
if ($inventory_port > 0) {
    $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'bin', 'inventory_write_sock.pl');
} else {
    $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'bin', 'pjo_inventory_write.pl');
}

# pjo_inventory_watch.pl �Ͻ��Ϥ�Хåե���󥰤��ʤ����� ($|=1)
# �ˤ��Ƥ������ȡ�fujitsu���ꥸ�ʥ�Ϥ����ʤäƤʤ���
my $watch_command=File::Spec->catfile($ENV{'XCRYPT'}, 'bin', 'pjo_inventory_watch.pl');
my $watch_opt="-i summary -e all -t 86400 -s"; # -s: signal end mode
our $watch_thread=undef; # used in bin/xcrypt

# �����̾������֤�request_id
my %job_request_id : shared;
# �����̾������֤ξ���
our %job_status : shared;
# �����̾���Ǹ�Υ�����Ѳ�����
my %job_last_update : shared;
# ����֤ξ��֢�����٥�
my %status_level = ("active"=>0, "prepared"=>1, "submitted"=>2, "queued"=>3,
                    "running"=>4, "done"=>5, "finished"=>6, "aborted"=>7);
# "running"���֤Υ���֤���Ͽ����Ƥ���ϥå��� (key,value)=(req_id,jobname)
my %running_jobs : shared = ();
# ���Ū�¹�ʸ������Ͽ����Ƥ�������
our @periodicfuns : shared = ();
# delete��������������֤���Ͽ����Ƥ���ϥå��� (key,value)=(jobname,signal_val)
my %signaled_jobs : shared = ();
my $all_jobs_signaled : shared = undef;

our $periodic_check_thread=undef; # used in bin/xcrypt
my $abort_check_interval = $xcropt::options{abort_check_interval};


# ���Ϥ�Хåե���󥰤��ʤ���STDOUT & STDERR��
$|=1;
select(STDERR); $|=1; select(STDOUT);

##################################################
sub any_to_string {
    my ($arraysep, $x, @args) = @_;
    my $r = ref ($x);
    if ( $r eq '' ) {             # $x is a scalar
        return $x . join(' ', @args);
    } elsif ( $r eq 'ARRAY' ) {   # $arraysep works only here
        return join ($arraysep, @$x) . $arraysep . join($arraysep, @args);
    } elsif ( $r eq 'CODE' ) {
        return &$x(@args);
    } elsif ( $r eq 'SCALAR' ) {  # $x is *a reference to* a scalar
        return $$x . join(' ', @args);
    } else {
        die "any_to_string: Unexpected reference $r";
    }
}
sub any_to_string_nl  { any_to_string ("\n", @_); }
sub any_to_string_spc { any_to_string (" ", @_); }

##################################################
# ����֥�����ץȤ���������ɬ�פ�write��Ԥä��塤���������
# ����֥������塼��ˤ�ä��Ǥ���Τ��㤦
sub qsub {
    my $self = shift;

    my $job_name = $self->{id};
    my $dir = $self->{id};

    ### <-- Create job script file <--
    ## Preamble
    my $scriptfile = File::Spec->catfile($dir, $jobsched . '.sh');
    open (SCRIPT, ">$scriptfile");
    print SCRIPT "#!/bin/sh\n";
    # NQS �� SGE �⡤���ץ������δĶ��ѿ���Ÿ�����ʤ��Τ����ա�
    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_preamble} ) {
        foreach (@{$jsconfig::jobsched_config{$jobsched}{jobscript_preamble}}) {
            print SCRIPT $_ . "\n";
        }
    }

    ## Options
    # queue
    my $queue = $self->{queue};
    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_queue} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_queue}, $queue) . "\n";
    }
    # stderr & stdout
    my $stdofile;
    $stdofile = File::Spec->catfile($dir, $self->{stdofile} ? $self->{stdofile} : 'stdout');
    if ( -e $stdofile) { unlink $stdofile; }
    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_stdout} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_stdout}, $ENV{'PWD'}.'/'.$stdofile) . "\n";
    }
    my $stdefile;
    $stdefile = File::Spec->catfile($dir, $self->{stdefile} ? $self->{stdefile} : 'stderr');
    if ( -e $stdefile) { unlink $stdefile; }
    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_stderr} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_stderr}, $ENV{'PWD'}.'/'.$stdefile) . "\n";
    }
    # computing resources
    my $proc = $self->{proc};
    if ( $proc ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_proc} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_proc}, $proc) . "\n";
    }
    my $cpu = $self->{cpu};
    if ( $cpu ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_cpu} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_cpu}, $cpu) . "\n";
    }
    my $memory = $self->{memory};
    if ( $memory ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_memory} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_memory}, $memory) . "\n";
    }
    # verbosity
    my $verbose = $self->{verbose};
    if ( $verbose ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_verbose} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_verbose}) . "\n";
    }
    my $verbose_node = $self->{verbose_node};
    if ( $verbose_node ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_verbose_node} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_verbose_node}) . "\n";
    }
    # other options
    my $option = $self->{option};
    print SCRIPT "$option\n";

    ## Commands
    # print SCRIPT "PATH=$ENV{'PATH'}\n";
    # print SCRIPT "set -x\n";
    # Move to the job directory
    my $wkdir_str = defined ($jsconfig::jobsched_config{$jobsched}{jobscript_workdir})
        ? any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_workdir})
        : $ENV{'PWD'};
    print SCRIPT "cd " . File::Spec->catfile ($wkdir_str, $dir) . "\n";

    # Set job's status "running"
    print SCRIPT inventory_write_cmdline($job_name, "running") . " || exit 1\n";

    # Execute a program
    my @args = ();
    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) { push(@args, $self->{"arg$i"}); }
    my $cmd = $self->{exe} . ' ' . join(' ', @args);
    print SCRIPT "$cmd\n";
    # ���ｪλ�Ǥʤ���� "aborted" ��񤭹���٤���

    # Set job's status "done"
    print SCRIPT inventory_write_cmdline($job_name, "done") . " || exit 1\n";
    close (SCRIPT);
    ### --> Create job script file -->

    ### <-- Create qsub options <--
    my $qsub_options = '';
    # stderr & stdout
    if ( defined $jsconfig::jobsched_config{$jobsched}{qsub_stdout_option} ) {
        $qsub_options .= " ". any_to_string_spc ($jsconfig::jobsched_config{$jobsched}{qsub_stdout_option}, $stdofile);
    }
    if ( defined $jsconfig::jobsched_config{$jobsched}{qsub_stderr_option} ) {
        $qsub_options .= " ". any_to_string_spc ($jsconfig::jobsched_config{$jobsched}{qsub_stderr_option}, $stdefile);
    }
    ### --> Create qsub options -->

    # Set job's status "submitted"
    inventory_write ($job_name, "submitted");

    my $qsub_command = $jsconfig::jobsched_config{$jobsched}{qsub_command};
    unless ( defined $qsub_command ) {
        die "qsub_command is not defined in $jobsched.pm";
    }
    if (common::cmd_executable ($qsub_command)) {
        # ������qsub���ޥ�ɼ¹�
        # print STDERR "$qsub_command $qsub_options $scriptfile\n";
        my @qsub_output = qx/$qsub_command $qsub_options $scriptfile/;
        my $req_id;
        # Get request ID from qsub's output
        if ( defined ($jsconfig::jobsched_config{$jobsched}{extract_req_id_from_qsub_output}) ) {
            unless ( ref $jsconfig::jobsched_config{$jobsched}{extract_req_id_from_qsub_output} eq 'CODE' ) {
                die "Error in $jobsched.pm: extract_req_id_from_qsub_output must be a function";
            }
            $req_id = &{$jsconfig::jobsched_config{$jobsched}{extract_req_id_from_qsub_output}} (@qsub_output);
        } else { # default extractor
            $req_id = ($qsub_output[0] =~ /([0-9]+)/) ? $1 : -1;
        }
        if ( $req_id < 0 ) { die "Can't extract request ID from qsub output." }
        # Remember request ID
        my $idfile = File::Spec->catfile($dir, 'request_id');
        open (REQUESTID, ">> $idfile");
        print REQUESTID $req_id;
        close (REQUESTID);
        open (REQUESTIDS, ">> $reqids_file");
        print REQUESTIDS $req_id . ' ' . $dir . ' ';
        close (REQUESTIDS);
        set_job_request_id ($self->{id}, $req_id);
        # Set job's status "queued"
        inventory_write ($job_name, "queued");
        return $req_id;
    } else {
        die "$qsub_command is not executable";
    }
}

# qdel���ޥ�ɤ�¹Ԥ��ƻ��ꤵ�줿jobname�Υ���֤򻦤�
sub qdel {
    my ($jobname) = @_;
    # qdel���ޥ�ɤ�config�������
    my $qdel_command = $jsconfig::jobsched_config{$ENV{'XCRJOBSCHED'}}{qdel_command};
    unless ( defined $qdel_command ) {
        die "qdel_command is not defined in $ENV{'XCRJOBSCHED'}.pm";
    }
    # jobname -> request id
    my $req_id = get_job_request_id ($jobname);
    if ($req_id) {
        # execute qdel
        my $command_string = any_to_string_spc ("$qdel_command ", $req_id);
        if (common::cmd_executable ($command_string)) {
            print "Deleting $jobname (request ID: $req_id)\n";
            exec ($command_string);
        } else {
            warn "$command_string not executable.";
        }
    }
}

# qstat���ޥ�ɤ�¹Ԥ���ɽ�����줿request ID������֤�
sub qstat {
    my $qstat_command = $jsconfig::jobsched_config{$jobsched}{qstat_command};
    unless ( defined $qstat_command ) {
        die "qstat_command is not defined in $jobsched.pm";
    }
    my $qstat_extractor = $jsconfig::jobsched_config{$jobsched}{extract_req_ids_from_qstat_output};
    unless ( defined $qstat_extractor ) {
        die "extract_req_ids_from_qstat_output is not defined in $jobsched.pm";
    } elsif ( ref ($qstat_extractor) ne 'CODE' ) {
        die "Error in $jobsched.pm: extract_req_ids_from_qstat_output must be a function.";
    }
    my $command_string = any_to_string_spc ($qstat_command);
    unless (common::cmd_executable ($command_string)) {
        warn "$command_string not executable";
        return ();
    }
    # foreach my $j ( keys %running_jobs ) { print " " . $running_jobs{$j} . "($j)"; }
    my @qstat_out = qx/$command_string/;
    my @ids = &$qstat_extractor(@qstat_out);
    return @ids;
}

##############################
# �����ץ������inventory_write��ư����
# ����٥�ȥ�ե������$jobname�ξ��֤�$stat���Ѳ��������Ȥ�񤭹���
sub inventory_write {
    my ($jobname, $stat) = @_;
    system (inventory_write_cmdline($jobname,$stat));
}
sub inventory_write_cmdline {
    my ($jobname, $stat) = @_;
    status_name_to_level ($stat); # ͭ����̾���������å�
    if ( $inventory_port > 0 ) {
        return "$write_command $inventory_host $inventory_port $jobname $stat";
    } else { 
        my $file = File::Spec->catfile($inventory_path, $jobname);
        my $jobspec = "\"spec: $jobname\"";
        return "$write_command $file \"$stat\" $jobspec";
    }
}

##############################
# watch�ν��ϰ�Ԥ����
# set_job_status��Ԥä���1�������Ǥʤ����0�����顼�ʤ�-1���֤�
my $last_jobname=undef; # ��������Υ���֤�̾���ʡ�Ǹ�˸���"spec: <name>"��
                        # handle_inventory��invoke_watch_by_socket���黲��
sub handle_inventory {
    my ($line) = @_;
    my $ret = 0;
    if ($line =~ /^spec\:\s*(.+)/) {            # �����̾
        $last_jobname = $1;
    # ���ʲ���NFS�̿��Ǥ���
    # inventory_watch ��Ʊ������������٤���Ϥ���Τǡ�
    # �Ǹ�ι������Ť������̵�뤹�롥
    # Ʊ������ι����ξ�碪�ְտޤ������פι����ʤ��������� (ref. set_job_*)
    } elsif ($line =~ /^time_active\:\s*([0-9]*)/) {   # ����ּ¹�ͽ��
        set_job_active ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_prepared\:\s*([0-9]*)/) {   # ���������ľ��
        set_job_prepared ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_submitted\:\s*([0-9]*)/) {   # ���������ľ��
        set_job_submitted ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_queued\:\s*([0-9]*)/) {   # qsub����
        set_job_queued ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_running\:\s*([0-9]*)/) {   # �ץ�����೫��
        # �ޤ�queued�ˤʤäƤ��ʤ���н񤭹��ޤ���0���֤����ȤǺ�Ϣ����¥��
        # ������wait���ʤ��Τϥǥåɥ��å��ɻߤΤ���
        if ( get_job_status ($last_jobname) eq "queued" ) {
            set_job_running ($last_jobname, $1);
            $ret = 1;
        } else {
            $ret = -1;
        }
    } elsif ($line =~ /^time_done\:\s*([0-9]*)/) {   # �ץ������ν�λ������� 
        set_job_done ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_finished\:\s*([0-9]*)/) {   # ����֥���åɤν�λ 
        set_job_finished ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_aborted\:\s*([0-9]*)/) {   # �ץ������ν�λ������ʳ���
        set_job_aborted ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # ��λ�ʳ��Υ���־����Ѳ�
        # �Ȥꤢ��������ʤ�
    } elsif ($line =~ /^date\_.*\:\s*(.+)/){    # ����־����Ѳ��λ���
        # �Ȥꤢ��������ʤ�
    } elsif ($line =~/^time\_.*\:\s*(.+)/){     # ����־����Ѳ��λ���
        # �Ȥꤢ��������ʤ�
    } elsif ($line =~/^:del\s+(\S+)/) {         # ����ֺ������
        entry_signaled_job ($1);
        $ret = 0;
    } elsif ($line =~/^:delall/) {              # ������ֺ������
        signal_all_jobs ();
        $ret = 0;
    } else {
        warn "unexpected inventory: \"$line\"\n";
        $ret = -1;
    }
    return $ret;
}

# ����֤ξ����Ѳ���ƻ뤹�륹��åɤ�ư
sub invoke_watch {
    # ����٥�ȥ�ե�������֤����ǥ��쥯�ȥ�����
    if ( !(-d $inventory_path) ) {
        mkdir $inventory_path or
        die "Can't make $inventory_path: $!.\n";
    }
    foreach (".tmp", ".lock") {
        my $newdir = File::Spec->catfile($inventory_path, $_);
        if ( !(-d $newdir) ) {
            mkdir $newdir or
                die "Can't make $newdir: $!.\n";
        }
    }
    # ��ư
    if ( $inventory_port > 0 ) {   # TCP/IP�̿������Τ������
        invoke_watch_by_socket ();
    } else {                       # NFS��ͳ�����Τ������
        invoke_watch_by_file ();
    }
}

# �����ץ������watch��ư��������ɸ����Ϥ�ƻ뤹�륹��åɤ�ư
sub invoke_watch_by_file {
    # inventory_watch�����ƻ�������Ǥ������Ȥ����Τ��뤿������֤���ե�����
    my $invwatch_ok_file = "$inventory_path/.tmp/.pjo_invwatch_ok";
    # ��ư���ˤ⤷����оä��Ƥ���
    if ( -f $invwatch_ok_file ) { unlink $invwatch_ok_file; }
    # �ʲ����ƻ륹��åɤν���
    $watch_thread =  threads->new( sub {
        # open (INVWATCH_LOG, ">", "$inventory_path/log");
        open (INVWATCH, "$watch_command $inventory_path $watch_opt |")
            or die "Failed to execute inventory_watch.";
        while (1) {
            while (<INVWATCH>){
                # print INVWATCH_LOG "$_";
                handle_inventory ($_);
            }
            close (INVWATCH);
            # print "watch finished.\n";
            open (INVWATCH, "$watch_command $inventory_path $watch_opt -c |");
        }
        # close (INVWATCH_LOG);
    });
    # inventory_watch�ν������Ǥ���ޤ��Ԥ�
    until ( -f $invwatch_ok_file ) { sleep 1; }
}

# TCP/IP�̿��ˤ�ꥸ��־��֤��ѹ��������γ���������̿�������դ��륹��åɤ�ư
sub invoke_watch_by_socket {
    $watch_thread = threads-> new ( sub {
        socket (CLIENT_WAITING, PF_INET, SOCK_STREAM, 0)
            or die "Can't make socket. $!";
        setsockopt (CLIENT_WAITING, SOL_SOCKET, SO_REUSEADDR, 1)
            or die "setsockopt failed. $!";
        bind (CLIENT_WAITING, pack_sockaddr_in ($inventory_port, inet_aton($inventory_host)))
            or die "Can't bind socket. $!";
        listen (CLIENT_WAITING, SOMAXCONN)
            or die "listen: $!";
        while (1) {
            my $paddr = accept (CLIENT, CLIENT_WAITING);
            unless ($paddr) {next;}
            my ($cl_port, $cl_iaddr) = unpack_sockaddr_in ($paddr);
            my $cl_hostname = gethostbyaddr ($cl_iaddr, AF_INET);
            my $cl_ip = inet_ntoa ($cl_iaddr);
            my $inv_text = '';
            my $handle_inventory_ret = 0;
            select(CLIENT); $|=1; select(STDOUT);
            # ���饤����Ȥ���Υ�å�������
            # (0�԰ʾ�Υ�å�������)+(":end"�ǻϤޤ��)
            while (<CLIENT>) {
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
                    $handle_inventory_ret = handle_inventory ($_, 1);
                }
            }
            if ($handle_inventory_ret >= 0) {
                # ���顼���ʤ����inventory�ե�����˥�����񤭹����:ack���֤�
                my $inv_save = File::Spec->catfile($inventory_path, $last_jobname);
                open ( SAVE, ">> $inv_save") or die "Can't open $inv_save\n";
                print SAVE $inv_text;
                close (SAVE);
                print CLIENT ":ack\n";
                # print STDERR "sent :ack\n";
            } else {
                # ���顼�������:failed���֤���inventory file�ˤϽ񤭹��ޤʤ���
                print CLIENT ":failed\n";
                # print STDERR "sent :failed\n";
            }
            close (CLIENT);
        }
    });
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
# �����̾��request_id
sub get_job_request_id {
    my ($jobname) = @_;
    if ( exists ($job_request_id{$jobname}) ) {
        return $job_request_id{$jobname};
    } else {
        return 0;
    }
}
sub set_job_request_id {
    my ($jobname, $req_id) = @_;
    unless ( $req_id =~ /[0-9]+/ ) {
        die "Unexpected request_id of $jobname: $req_id";
    }
    print "$jobname id <= $req_id\n";
    lock (%job_request_id);
    $job_request_id{$jobname} = $req_id;
}

##############################
# ����־���̾�����֥�٥��
sub status_name_to_level {
    my ($name) = @_;
    if ( exists ($status_level{$name}) ) {
        return $status_level{$name};
    } else {
        die "status_name_to_runlevel: unexpected status name \"$name\"\n";
    }
}

# �����̾������
sub get_job_status {
    my ($jobname) = @_;
    if ( exists ($job_status{$jobname}) ) {
        return $job_status{$jobname};
    } else {
        return "active";
    }
}
# �����̾���Ǹ�ξ����Ѳ�����
sub get_job_last_update {
    my ($jobname) = @_;
    if ( exists ($job_last_update{$jobname}) ) {
        return $job_last_update{$jobname};
    } else {
        return -1;
    }
}

# ����֤ξ��֤��ѹ�
sub set_job_status {
    my ($jobname, $stat, $tim) = @_;
    status_name_to_level ($stat); # ͭ����̾���������å�
    print "$jobname <= $stat\n";
    {
        lock (%job_status);
        $job_status{$jobname} = $stat;
        $job_last_update{$jobname} = $tim;
        cond_broadcast (%job_status);
    }
    # �¹��楸��ְ�������Ͽ�����
    if ( $stat eq "queued" || $stat eq "running" ) {
        entry_running_job ($jobname);
    } else {
        delete_running_job ($jobname);
    }
}
sub set_job_active  {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "active", "active", "submitted", "queued", "running", "aborted") ) {
        set_job_status ($jobname, "active", $tim);
    }
}
sub set_job_prepared  {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "prepared", "active") ) {
        set_job_status ($jobname, "prepared", $tim);
    }
}
sub set_job_submitted {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "submitted", "prepared") ) {
        set_job_status ($jobname, "submitted", $tim);
    }
}
sub set_job_queued {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "queued", "submitted" ) ) {
        set_job_status ($jobname, "queued", $tim);
    }
}
sub set_job_running  {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "running", "queued" ) ) {
        set_job_status ($jobname, "running", $tim);
    }
}
sub set_job_done   {
    my ($jobname, $tim) = @_;
    # finished��done �ϥ�ȥ饤�ΤȤ���ͭ������
    if (do_set_p ($jobname, $tim, "done", "running", "finished" ) ) {
        set_job_status ($jobname, "done", $tim);
        # ��ȥ饤�ΤȤ��˼¹Ԥ����ȡ�down����Ƥʤ����ޥե���up���Ƥ��ޤ�
# after ������ᥤ�󥹥�åɰʳ��Ǥ��뤳�Ȥˤʤ� limit.pm �����褷���Τ�
#        if (defined $user::smph) {
#            $user::smph->up;
#        }
    }
}
sub set_job_finished   {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "finished", "done" ) ) {
        set_job_status ($jobname, "finished", $tim);
    }
}
sub set_job_aborted  {
    my ($jobname, $tim) = @_;
    my $curstat = get_job_status ($jobname);
    if (do_set_p ($jobname, $tim, "aborted", "active", "prepared", "submitted", "queued", "running" )
        && $curstat ne "done" && $curstat ne "finished" ) {
        set_job_status ($jobname, "aborted", $tim);
    }
}
# ������������������ܤν�����Ȥ�set��¹Ԥ��Ƥ褤����Ƚ��
sub do_set_p {
  my ($jobname, $tim, $stat, @e_stats) = @_;
  my $who = "set_job_$stat";
  my $last_update = get_job_last_update ($jobname);
  # print "$jobname: cur=$tim, last=$last_update\n";
  if ( $tim > $last_update ) {
      expect_job_stat ($who, $jobname, 1, @e_stats);
      return 1;
  } elsif ( $tim == $last_update ) {
      if ( $stat eq get_job_status($jobname) ) {
          return 0;
      } else {
          return expect_job_stat ($who, $jobname, 0, @e_stats);
      }
  } else {
      return 0;
  }
}
# $jobname�ξ��֤���$who�ˤ��������ܤδ��Ԥ����Ρ�@e_stats�Τɤ줫�ˤǤ��뤫������å�
sub expect_job_stat {
    my ($who, $jobname, $do_warn, @e_stats) = @_;
    my $stat = get_job_status($jobname);
    foreach my $es (@e_stats) {
        if ( $stat eq $es ) {
            return 1;
        }
    }
    if ( $do_warn ) {
        print "$who expects $jobname is (or @e_stats), but $stat.\n";
    }
    return 0;
}

# �����"$jobname"�ξ��֤�$stat�ʾ�ˤʤ�ޤ��Ԥ�
sub wait_job_status {
    my ($jobname, $stat) = @_;
    my $stat_lv = status_name_to_level ($stat);
    # print "$jobname: wait for the status changed to $stat($stat_lv)\n";
    lock (%job_status);
    until ( &status_name_to_level (&get_job_status ($jobname))
            >= $stat_lv) {
        cond_wait (%job_status);
    }
    # print "$jobname: exit wait_job_status\n";
}
sub wait_job_active    { wait_job_status ($_[0], "active"); }
sub wait_job_prepared  { wait_job_status ($_[0], "prepared"); }
sub wait_job_submitted { wait_job_status ($_[0], "submitted"); }
sub wait_job_queued    { wait_job_status ($_[0], "queued"); }
sub wait_job_running   { wait_job_status ($_[0], "running"); }
sub wait_job_done      { wait_job_status ($_[0], "done"); }
sub wait_job_finished  { wait_job_status ($_[0], "finished"); }
sub wait_job_aborted   { wait_job_status ($_[0], "aborted"); }

# ���٤ƤΥ���֤ξ��֤���ϡʥǥХå��ѡ�
sub print_all_job_status {
    foreach my $jn (keys %job_status) {
        print "$jn:" . get_job_status ($jn) . " ";
    }
    print "\n";
}

##################################################
# "running"�ʥ���ְ����ι���
sub entry_running_job {
    my ($jobname) = @_;
    my $req_id = get_job_request_id ($jobname);
    lock (%running_jobs);
    $running_jobs{$req_id} = $jobname;
    # print STDERR "entry_running_job: $jobname($req_id), #=" . (keys %running_jobs) . "\n";
}
sub delete_running_job {
    my ($jobname) = @_;
    my $req_id = get_job_request_id ($jobname);
    if ($req_id) {
        lock (%running_jobs);
        delete ($running_jobs{$req_id});
    }
}

sub entry_signaled_job {
    my ($jobname) = @_;
    lock (%signaled_jobs);
    $signaled_jobs{$jobname} = 1;
    print "$jobname is signaled to be deleted.\n";
}
sub signal_all_jobs {
    lock ($all_jobs_signaled);
    $all_jobs_signaled = 1;
    print "All jobs are signaled to be deleted.\n";
}
sub delete_signaled_job {
    my ($jobname) = @_;
    lock (%signaled_jobs);
    if ( exists $signaled_jobs{$jobname} ) {
        delete $signaled_jobs{$jobname};
    }
}
sub is_signaled_job {
    lock (%signaled_jobs);
    return ($all_jobs_signaled || $signaled_jobs{$_[0]});
}

# running_jobs�Υ���֤�aborted�ˤʤäƤʤ��������å�
# ���֤� "queued" �ޤ��� "running"�ˤ⤫����餺��qstat����������֤����Ϥ���ʤ���Τ�
# aborted�Ȥߤʤ�������־��֥ϥå���򹹿����롥
# �ޤ���signaled�ʥ���֤�qstat�˸��줿��qdel����
### Note:
# ����ֽ�λ���done�񤭹��ߤϥ�����ץ���ʤΤǽ���äƤ���Ϥ���
# ��������NFS�Υ��󥷥��ƥ���ά�ˤ�äƤϴ��ʤ������
# inventory_watch����done�񤭹��ߤ����Τ�Xcrypt���Ϥ��ޤǤδ֤�
# abort_check������ȡ�aborted��񤭹���Ǥ��ޤ���
# �� TCP/IP�Ǥϥ���־����ѹ����θ塤ack���ԤĤ褦�ˤ����ΤǾ嵭�ϵ�����ʤ��Ϥ���
# �� NFS�Ǥ⤽�����٤�
sub check_and_write_aborted {
    my %unchecked;
    {
        # %running_jobs �Τ�����qstat��ɽ������ʤ��ä�����֤�%unchecked�˻Ĥ�
        {
            lock (%running_jobs);
            %unchecked = %running_jobs;
        }
        print "check_and_write_aborted:\n";
        # foreach my $j ( keys %running_jobs ) { print " " . $running_jobs{$j} . "($j)"; }
        my @ids = qstat();
        foreach (@ids) {
            my $jobname = $unchecked{$_};
            delete ($unchecked{$_});
            # ������signaled�Υ����å��⤹�롥
            if ($jobname && is_signaled_job($jobname)) {
                delete_signaled_job($jobname);
                qdel ($jobname);
            }
        }
    }
    # %unchecked�˻ĤäƤ��른��֤�"aborted"�ˤ��롥
    foreach my $req_id ( keys %unchecked ) {
        if ( exists $running_jobs{$req_id} ) {
            print STDERR "aborted: $req_id: " . $unchecked{$req_id} . "\n";
            inventory_write ($unchecked{$req_id}, "aborted");
        }
    }
}

sub getjobids {
    open( JOBIDS, "< $_[0]" );
    my %reqid_jobids = split(' ', <JOBIDS>);
    my %count;
    my @vals = values(%reqid_jobids);
    @vals = grep(!$count{$_}++, @vals);
    my @jobids = sort @vals;
    close( JOBIDS );
    return @jobids;
}

sub invoke_periodic_check {
    $periodic_check_thread = threads->new( sub {
        while (1) {
            sleep $abort_check_interval;
            check_and_write_aborted();

            # print_all_job_status();
            ## inv_watch/* ��open��handle_inventory�Ⱦ��ͤ��ƥ��顼�ˤʤ�Τ�
            ## �Ȥꤢ���������ȥ�����
	    # &builtin::check_and_alert_elapsed();

# �桼����������Ū�¹�ʸ����
	    foreach my $i (@periodicfuns) {
		eval "$i";
	    }
        }
    });
}

## ������watch�������Ȥ����ĳ�
#         my %timestamps = {};
#         my @updates = ();
#         foreach (glob "$inventory_path/*") {
#             my $bname = fileparse($_);
#             my @filestat = stat $_;
#             my $tstamp = @filestat[9];
#             if ( !exists ($timestamps{$bname})
#                  || $timestamps{$bname} < $tstamp )
#             {
#                 push (@updates, $bname);
#                 $timestamps{$bname} = $tstamp;
#             }
#         }

1;