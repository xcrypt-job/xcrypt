# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use strict;
use threads;
use threads::shared;
use Cwd;
use File::Basename;
use File::Spec;
use IO::Socket;
# use Thread::Semaphore;

##################################################

my $current_directory=Cwd::getcwd();

### qsub, qdel qstat
# my $qsub_command="../kahanka/qsub";
# my $qdel_command="../kahanka/qdel";
# my $qstat_command="../kahanka/qstat";
my $qsub_command="qsub";
my $qdel_command="qdel";
my $qstat_command="qstat";

### Inventory
my $inventory_host = qx/hostname/;
chomp $inventory_host;
my $inventory_port = 9999;           # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ(unstable!)
my $inventory_path=File::Spec->catfile($current_directory, 'inv_watch');
my $inventory_save_path=$inventory_path;

my $write_command = undef;
if ($inventory_port > 0) {
    $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'inventory_write_sock.pl');
} else {
    $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'pjo_inventory_write.pl');
}
# pjo_inventory_watch.pl �Ͻ��Ϥ�Хåե���󥰤��ʤ����� ($|=1)
# �ˤ��Ƥ������ȡ�fujitsu���ꥸ�ʥ�Ϥ����ʤäƤʤ���
my $watch_command=File::Spec->catfile($ENV{'XCRYPT'}, 'pjo_inventory_watch.pl');
my $watch_opt="-i summary -e all -t 86400 -s"; # -s: signal end mode
our $watch_thread=undef;

# �����̾������֤�request_id
my %job_request_id : shared;
# �����̾������֤ξ���
my %job_status : shared;
# �����̾���Ǹ�Υ�����Ѳ�����
my %job_last_update : shared;
# ����֤ξ��֢�����٥�
my %status_level = ("active"=>0, "submit"=>1, "qsub"=>2, "start"=>3, "done"=>4, "abort"=>5);
# "start"���֤Υ���֤���Ͽ����Ƥ���ϥå��� (key,value)=(req_id,jobname)
my %running_jobs : shared;
our $abort_check_thread=undef;

our $sge : shared = 0;

# ���Ϥ�Хåե���󥰤��ʤ���STDOUT & STDERR��
$|=1;
select(STDERR); $|=1; select(STDOUT);

##################################################
# ����֥�����ץȤ���������ɬ�פ�write��Ԥä��塤���������
# ����֥������塼���NQS�Ǥ��뤫SGE�Ǥ��뤫�ˤˤ�ä��Ǥ���Τ��㤦
sub qsub {
    my $self = shift;

=comment
    my ($job_name, # �����̾
        $command,  # �¹Ԥ��륳�ޥ�ɤ�ʸ����
        $dirname,      # �¹ԥե������֤���ʥ�����ץȼ¹Ծ�꤫������Хѥ���
        $scriptfile, # ������ץȥե�����̾
        # �ʲ��ΰ�����optional
	$queue,
        $option,
        $stdofile, $stdefile, # ɸ�ࡿ���顼�������qsub�Υ��ץ�����
        # �ʲ���NQS�Υ��ץ����
        $proc, $cpu, $memory, $verbose, $verbose_node,
        ) = @_;
=cut

    my $job_name = $self->{id};
    my $dir = $self->{id};

    ## <-- Create job script file <--
    my $scriptfile;
    if ($sge) {
	$scriptfile = File::Spec->catfile($dir, 'sge.sh');
    } else {
	$scriptfile = File::Spec->catfile($dir, 'nqs.sh');
    }
    open (SCRIPT, ">$scriptfile");
    print SCRIPT "#!/bin/sh\n";
    # NQS �� SGE �⡤���ץ������δĶ��ѿ���Ÿ�����ʤ��Τ���ա�
    if ($sge) {
	print SCRIPT "#\$ -S /bin/sh\n";
    }
    my $queue = $self->{queue};
    if ($sge) {

    } else {
	print SCRIPT "# @\$-q $queue\n";
    }
    my $option = $self->{option};
    print SCRIPT "$option\n";

    my $stdofile;
    if ($self->{stdofile}) {
	$stdofile = File::Spec->catfile($dir, $self->{stdofile});
    } else {
	$stdofile = File::Spec->catfile($dir, 'stdout');
    }
    if ( -e $stdofile) { unlink $stdofile; }
    if ($sge) {
	print SCRIPT "#\$ -o $ENV{'PWD'}/$stdofile\n";
    } else {
	print SCRIPT "# @\$-o $ENV{'PWD'}/$stdofile\n";
    }

    my $stdefile;
    if ($self->{stdefile}) {
	$stdefile = File::Spec->catfile($dir, $self->{stdefile});
    } else {
	$stdefile = File::Spec->catfile($dir, 'stderr');
    }
    if ( -e $stdefile) { unlink $stdefile; }
    if ($sge) {
	print SCRIPT "#\$ -e $ENV{'PWD'}/$stdefile\n";
    } else {
	print SCRIPT "# @\$-e $ENV{'PWD'}/$stdefile\n";
    }

    my $proc = $self->{proc};
    unless ($proc eq '') {
	if ($sge) {

	} else {
	    print SCRIPT "# @\$-lP $proc\n";
	}
    }
    my $cpu = $self->{cpu};
    unless ($cpu eq '') {
	if ($sge) {

	} else {
	    print SCRIPT "# @\$-lp $cpu\n";
	}
    }
    my $memory = $self->{memory};
    unless ($memory eq '') {
	if ($sge) {

	} else {
	    print SCRIPT "# @\$-lm $memory\n";
	}
    }
    my $verbose = $self->{verbose};
    unless ($verbose eq '') {
	if ($sge) {

	} else {
	    print SCRIPT "# @\$-oi\n";
	}
    }
    my $verbose_node = $self->{verbose_node};
    unless ($verbose_node eq '') {
	if ($sge) {

	} else {
	    print SCRIPT "# @\$-OI\n";
	}
    }
#    print SCRIPT "PATH=$ENV{'PATH'}\n";
#    print SCRIPT "set -x\n";
    print SCRIPT inventory_write_cmdline($job_name, "start") . " || exit 1\n";
    print SCRIPT "cd $ENV{'PWD'}/$dir\n";
#    print SCRIPT "cd \$QSUB_WORKDIR/$dir\n";

#    print SCRIPT "$command\n";
    my @args = ();
    for ( my $i = 0; $i <= $user::max; $i++ ) { push(@args, $self->{"arg$i"}); }
    my $cmd = $self->{exe} . ' ' . join(' ', @args);
    print SCRIPT "$cmd\n";
    # ���ｪλ�Ǥʤ���� "abort" ��񤭹���٤�
    print SCRIPT inventory_write_cmdline($job_name, "done") . " || exit 1\n";
    close (SCRIPT);
    ## --> Create job script file -->
    
    inventory_write ($job_name, "submit");
    my $existence = qx/which $qsub_command \> \/dev\/null; echo \$\?/;
    if ($existence == 0) {
	my $qsub_output = qx/$qsub_command $scriptfile/;
	my $req_id = extract_req_id_from_qsub_output ($qsub_output);
	my $idfile = File::Spec->catfile($dir, 'request_id');
	open (REQUESTID, ">> $idfile");
	print REQUESTID $req_id;
	close (REQUESTID);
        set_job_request_id ($self->{id}, $req_id);
        inventory_write ($job_name, "qsub");
	return $req_id;
    } else { die "qsub not found\n"; }
}

sub extract_req_id_from_qsub_output {
    my ($line) = @_;
    my $req_id;
    if ($sge) {
        if ( $line =~ /^\s*Your\s+job\s+([0-9]+)/ ) {
            $req_id = $1;
        } else {
            die "Can't extract request_id: $line";
        }
    } else {
        if ( $line =~ /([0-9]*)\.nqs/ ) {
            $req_id = $1 . '.nqs';
        } else {
            die "Can't extract request_id: $line";
        }
    }
    return $req_id;
}

##############################
# �����ץ����inventory_write��ư����
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

# �����ץ����watch��ư��������ɸ����Ϥ�ƻ뤹�륹��åɤ�ư
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
                handle_inventory ($_, 0);
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

# TCP/IP�̿��ˤ�ꥸ��־��֤��ѹ����Τ�����դ��륹��åɤ�ư
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
            my ($cl_port, $cl_iaddr) = unpack_sockaddr_in ($paddr);
            my $cl_hostname = gethostbyaddr ($cl_iaddr, AF_INET);
            my $cl_ip = inet_ntoa ($cl_iaddr);
            select(CLIENT); $|=1; select(STDOUT);
            while (<CLIENT>) {
                if ( $_ =~ /^:end/ ) { last; }
                handle_inventory ($_, 1);
            }
            # print STDERR "received :end\n";
            print CLIENT ":ack\n";
            # print STDERR "sent :ack\n";
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
            handle_inventory ($_, 0);
        }
        close (IN);
    }
}

# watch�ν��ϰ�Ԥ����
my $last_jobname=undef; # ��������Υ���֤�̾���ʡ�Ǹ�˸���"spec: <name>"��
sub handle_inventory {
    my ($line, $write_p) = @_;
    if ($line =~ /^spec\:\s*(.+)/) {            # �����̾
        $last_jobname = $1;
#     } elsif ($line =~ /^status\:\s*active/) {   # ����ּ¹�ͽ��
#         set_job_active ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*submit/) {   # ���������ľ��
#         set_job_submit ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
# #     } elsif ($line =~ /^status\:\s*qsub/) {     # qsub����
# #         set_job_qsub ($last_jobname);   # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*start/) {    # �ץ���೫��
#         set_job_start ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*done/) {     # �ץ����ν�λ�������
#         set_job_done ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
#     } elsif ($line =~ /^status\:\s*abort/) {    # ����֤ν�λ������ʳ���
#         set_job_abort ($last_jobname); # ����־��֥ϥå���򹹿��ʡ����Ρ�
    ## �������ѹ��� "time_submit: <��������>"  �ιԤ򸫤�褦�ˤ���
    ## inventory_watch ��Ʊ������������٤���Ϥ���Τǡ�
    ## �Ǹ�ι������Ť������̵�뤹��
    ## Ʊ������ι����ξ�碪�ְտޤ������פι����ʤ��������� (ref. set_job_*)
    } elsif ($line =~ /^time_active\:\s*([0-9]*)/) {   # ����ּ¹�ͽ��
        set_job_active ($last_jobname, $1);
    } elsif ($line =~ /^time_submit\:\s*([0-9]*)/) {   # ���������ľ��
        set_job_submit ($last_jobname, $1);
    } elsif ($line =~ /^time_qsub\:\s*([0-9]*)/) {   # qsub����
        set_job_qsub ($last_jobname, $1);
    } elsif ($line =~ /^time_start\:\s*([0-9]*)/) {   # �ץ���೫��
        set_job_start ($last_jobname, $1);
    } elsif ($line =~ /^time_done\:\s*([0-9]*)/) {   # �ץ����ν�λ������� 
        set_job_done ($last_jobname, $1);
    } elsif ($line =~ /^time_abort\:\s*([0-9]*)/) {   # �ץ����ν�λ������ʳ���
        set_job_abort ($last_jobname, $1);
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # ��λ�ʳ��Υ���־����Ѳ�
        # �Ȥꤢ��������ʤ�
    } elsif (/^date\_.*\:\s*(.+)/){             # ����־����Ѳ��λ���
        # �Ȥꤢ��������ʤ�
    } elsif (/^time\_.*\:\s*(.+)/){             # ����־����Ѳ��λ���
        # �Ȥꤢ��������ʤ�
    } else {
        warn "unexpected inventory output: \"$line\"\n";
    }
    # TCP/IP�̿��⡼�ɤξ�硤inventory��ե��������¸
    if ( $write_p ) {
        my $inv_save = File::Spec->catfile($inventory_path, $last_jobname);
        open ( SAVE, ">> $inv_save")
            or die "Can't open $inv_save\n";
        print SAVE $line;
        close (SAVE);
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
    if ( $stat eq "qsub" || $stat eq "start" ) {
        entry_running_job ($jobname);
    } else {
        delete_running_job ($jobname);
    }
}
sub set_job_active  {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "active", "done", "abort") ) {
        set_job_status ($jobname, "active", $tim);
    }
}
sub set_job_submit {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "submit", "active", "done", "abort") ) {
        set_job_status ($jobname, "submit", $tim);
    }
}
sub set_job_qsub {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "qsub", "submit" ) ) {
        set_job_status ($_[0], "qsub", $tim);
    }
}
sub set_job_start  {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "start", "qsub" ) ) {
        set_job_status ($jobname, "start", $tim);
    }
}
sub set_job_done   {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "done", "start" ) ) {
        set_job_status ($jobname, "done", $tim);
    }
}
sub set_job_abort  {
    my ($jobname, $tim) = @_;
    if ( do_set_p ($jobname, $tim, "abort", "submit", "qsub", "start" )
         && get_job_status ($jobname) ne "done" ) {
        set_job_status ($jobname, "abort", $tim);
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
sub wait_job_active { wait_job_status ($_[0], "active"); }
sub wait_job_submit { wait_job_status ($_[0], "submit"); }
# sub wait_job_qsub   { wait_job_status ($_[0], "qsub"); }
sub wait_job_start  { wait_job_status ($_[0], "start"); }
sub wait_job_done   { wait_job_status ($_[0], "done"); }
sub wait_job_abort  { wait_job_status ($_[0], "abort"); }

# ���٤ƤΥ���֤ξ��֤���ϡʥǥХå��ѡ�
sub print_all_job_status {
    foreach my $jn (keys %job_status) {
        print "$jn:" . get_job_status ($jn) . " ";
    }
    print "\n";
}

##################################################
# "start"�ʥ���ְ����ι���
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

# running_jobs�Υ���֤�abort�ˤʤäƤʤ��������å�
# ���֤�"start"�ˤ⤫����餺��qstat����������֤����Ϥ���ʤ���Τ�
# abort�Ȥߤʤ���
# abort�Ȼפ����Τ�inventory_write("abort")����
### Note:
# ����ֽ�λ���done�񤭹��ߤϥ�����ץ���ʤΤǽ���äƤ���Ϥ���
# ��������NFS�Υ��󥷥��ƥ���ά�ˤ�äƤϴ�ʤ������
# inventory_watch����done�񤭹��ߤ����Τ�Xcrypt���Ϥ��ޤǤδ֤�
# abort_check������ȡ�abort��񤭹���Ǥ��ޤ���
# ���������񤭹��ߤ�done��abort�ν�Ǥ��ꡤset_job_status�⤽�ν�
# �ʤΤǤ����餯����ʤ���
# done�ʥ���֤ξ��֤�abort���ѹ��Ǥ��ʤ��褦�ˤ��٤���
# ���Ȥꤢ�����������Ƥ����ref. set_job_abort��
sub check_and_write_abort {
    my %unchecked;
    {
        lock (%running_jobs);
        print "check_and_write_abort:\n";
        # foreach my $j ( keys %running_jobs ) { print " " . $running_jobs{$j} . "($j)"; }
        # print "\n";
        %unchecked = %running_jobs;
        open (QSTATOUT, "$qstat_command |");
        while (<QSTATOUT>) {
            chomp;
            my $req_id = extract_req_id_from_qstat_line ($_);
            if ($req_id) {
                # print STDERR "$req_id: " . $unchecked{$req_id} . "\n";
                delete ($unchecked{$req_id});
            }
        }
        close (QSTATOUT);
    }
    # "abort"�򥤥�٥�ȥ�ե�����˽񤭹���
    foreach my $req_id ( keys %unchecked ){
        print STDERR "abort: $req_id: " . $unchecked{$req_id} . "\n";
        inventory_write ($unchecked{$req_id}, "abort");
    }
}
sub extract_req_id_from_qstat_line {
    my ($line) = @_;
    ## depend on outputs of NQS's qstat
    ## SGE�Ǥ�ư���褦�ˤ����Ĥ��
    # print STDERR $_ . "\n";
    if ($sge) {
        # print "--- $_\n";
        if ($line =~ /^\s*([0-9]+)/) {
            return $1;
        } else {
            return 0;
        }
    } else {
        # print "=== $_\n";
        if ( $line =~ /([0-9]+)\.nqs/ ) {
            return $1;
        } else {
            return 0;
        }
    }
}

sub invoke_abort_check {
    $abort_check_thread = threads->new( sub {
        while (1) {
            sleep 19;
            check_and_write_abort();
            # print_all_job_status();
        }
    });
}

# ����åɵ�ư���ɤ߹�������ǵ�ư��������������
#invoke_watch ();
#invoke_abort_check ();
## ����åɽ�λ�Ԥ����ǥХå���jobsched.pmñ�μ¹ԡ���
# $watch_thread->join();

1;


## ������watch�����Ȥ����ĳ�
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
