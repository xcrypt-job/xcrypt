# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use base qw(Exporter);
our @EXPORT = qw(any_to_string_nl any_to_string_spc
inventory_write_cmdline inventory_write
set_job_request_id
);

use strict;
use threads ();
use threads::shared;
use Cwd;
use File::Basename;
use File::Spec;
use IO::Socket;
use Coro;
use Coro::Socket;
#use Coro::Signal;
#use Coro::AnyEvent;
#use AnyEvent::Socket;
use Time::HiRes;
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use Net::OpenSSH;

use common;
use xcropt;
use jsconfig;
# use Thread::Semaphore;

my $rsh_command = $xcropt::options{rsh};
##################################################

### Inventory
my $inventory_host = $xcropt::options{localhost};
my $inventory_port = $xcropt::options{port}; # インベントリ通知待ち受けポート．0ならNFS経由
my $inventory_path = $xcropt::options{inventory_path};

my $write_command = undef;
my $Inventory_Write_Cmd = 'inventory_write.pl';

# for inventory_write_file
my $REQFILE = File::Spec->catfile($inventory_path, 'inventory_req');
my $ACKFILE = File::Spec->catfile($inventory_path, 'inventory_ack');
my $REQ_TMPFILE = $REQFILE . '.tmp';
my $ACK_TMPFILE = $ACKFILE . '.tmp';  # not required?
my $LOCKDIR = File::Spec->catfile($inventory_path, 'inventory_lock');
# ジョブオブジェクトのメンバに rhost が書かれるようになったので
# jobsched.pm 読み込み時にリモートのファイルの削除を行えばよいというわ
# けでなくなったので，ローカルのファイルのみを削除している．
unlink $REQFILE, $ACK_TMPFILE, $REQ_TMPFILE, $ACKFILE;
rmdir $LOCKDIR;

# 外部からの状態変更通知を待ち受け，処理するスレッド
our $watch_thread = undef; # used in bin/xcrypt

our %host_env = ();

# ジョブ名→ジョブのrequest_id
my %job_request_id : shared;
# ジョブ名→ジョブの状態
my %job_status : shared;
my $job_status_signal = new Coro::Signal;
# ジョブ名→最後のジョブ変化時刻
my %job_last_update : shared;
# ジョブの状態→ランレベル
my %status_level = ("initialized"=>0, "prepared"=>1, "submitted"=>2, "queued"=>3,
                    "running"=>4, "done"=>5, "finished"=>6, "aborted"=>7);
# "running"状態のジョブが登録されているハッシュ (key,value)=(req_id,jobname)
my %running_jobs : shared = ();
# テスト実装
our %initialized_nosync_jobs = ();
# 定期的実行文字列が登録されている配列
our %periodicfuns : shared = ();
# delete依頼を受けたジョブが登録されているハッシュ (key,value)=(jobname,signal_val)
my %signaled_jobs : shared = ();
my $all_jobs_signaled : shared = undef;

# 外部からの状態変更通知を待ち受け，処理するスレッド
our $watch_thread=undef;    # accessed from bin/xcrypt
# ジョブがabortedになってないかチェックするスレッド
our $abort_check_thread=undef;    # accessed from bin/xcrypt
my $abort_check_interval = $xcropt::options{abort_check_interval};
# ユーザ定義のタイム割り込み関数を実行するスレッド
our $periodic_thread=undef; # accessed from bin/xcrypt

# 出力をバッファリングしない（STDOUT & STDERR）
$|=1;
select(STDERR); $|=1; select(STDOUT);

##################################################
# qdelコマンドを実行して指定されたjobnameのジョブを殺す
# リモート実行未対応
sub qdel {
    my ($self) = @_;
    my $jobname = $self->{id};
    # qdelコマンドをconfigから獲得
    my $qdel_command = $jsconfig::jobsched_config{$ENV{XCRJOBSCHED}}{qdel_command};
    unless ( defined $qdel_command ) {
        die "qdel_command is not defined in $ENV{XCRJOBSCHED}.pm";
    }
    # jobname -> request id
    my $req_id = get_job_request_id ($jobname);
    if ($req_id) {
        # execute qdel
        my $command_string = any_to_string_spc ("$qdel_command ", $req_id);
        if (common::cmd_executable ($command_string, $self)) {
            print "Deleting $jobname (request ID: $req_id)\n";
            common::exec_async ($command_string);
        } else {
            warn "$command_string not executable.";
        }
    }
}

# qstatコマンドを実行して表示されたrequest IDの列を返す
sub qstat {
    my @ids;
#    my $qstat_command = $jsconfig::jobsched_config{$xcropt::options{scheduler}}{qstat_command};
    foreach (keys %host_env) {
	my $qstat_command = $jsconfig::jobsched_config{$host_env{$_}->{scheduler}}{qstat_command};
	unless ( defined $qstat_command ) {
	    die "qstat_command is not defined in $host_env{$_}->{schedulers}.pm";
	}
	my $qstat_extractor = $jsconfig::jobsched_config{$host_env{$_}->{scheduler}}{extract_req_ids_from_qstat_output};
	unless ( defined $qstat_extractor ) {
	    die "extract_req_ids_from_qstat_output is not defined in $host_env{$_}->{schedulers}.pm";
	} elsif ( ref ($qstat_extractor) ne 'CODE' ) {
	    die "Error in $host_env{$_}->{scheduler}.pm: extract_req_ids_from_qstat_output must be a function.";
	}
	my $command_string = any_to_string_spc ($qstat_command);
	unless (common::cmd_executable ($command_string, $_)) {
	    warn "$command_string not executable";
	    return ();
	}

	# foreach my $j ( keys %running_jobs ) { print " " . $running_jobs{$j} . "($j)"; }
	my @qstat_out = &xcr_qx($command_string, 'jobsched');
	my @tmp_ids = &$qstat_extractor(@qstat_out);
	push(@ids, @tmp_ids);
    }
    return @ids;
}

##############################
# Set the status of job $jobname to $stat by executing an external process.
sub inventory_write {
    my ($jobname, $stat, $self) = @_;
    my $host = $self->{rhost};
    my $wd = $self->{wd};
    my $cmdline = inventory_write_cmdline($jobname, $stat, $host, $wd);
    unless (exists($host_env{$host}->{invwatch})) {
	&xcr_mkdir($xcropt::options{inventory_path}, 'jobsched', $host, $wd);
	$host_env{$host}->{invwatch} = 1;
    }
    if ( $xcropt::options{verbose} >= 2 ) { print "$cmdline\n"; }
    &xcr_system("$cmdline", '.', $self); # &xcr_system("$cmdline", $jobname, $host, $wd);

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
    my ($jobname, $stat, $host, $wd) = @_;
    status_name_to_level ($stat); # Valid status name?

    if ($host) {
        my $prefix;
	if (exists($host_env{$host}->{xcrypt})) {
	    $prefix = $host_env{$host}->{xcrypt};
	} else {
	    my @ret = &xcr_qx('echo $XCRYPT');
	    $prefix = @ret[0];
	    &entry_host_and_xcrypt($host, $prefix);
	}
	chomp($prefix);
	if ($prefix eq '') {
	    die "Set the environment variable \$XCRYPT at $host\n";
	}
	$write_command=File::Spec->catfile($prefix, 'bin', $Inventory_Write_Cmd);
    } else {
	unless (defined $ENV{XCRYPT}) {
	    die "Set the environment varialble \$XCRYPT\n";
	}
	$write_command=File::Spec->catfile($ENV{XCRYPT}, 'bin', $Inventory_Write_Cmd);
    }

    if ( $inventory_port > 0 ) {
        return "$write_command $jobname $stat sock $inventory_host $inventory_port";
    } else {
	if ($host) {
	    my $dir = File::Spec->catfile($wd, $LOCKDIR);
	    my $req = File::Spec->catfile($wd, $REQFILE);
	    my $ack = File::Spec->catfile($wd, $ACKFILE);
	    return "$write_command $jobname $stat file $dir $req $ack";
	} else {
	    my $dir = File::Spec->catfile(Cwd::getcwd(), $LOCKDIR);
	    my $req = File::Spec->catfile(Cwd::getcwd(), $REQFILE);
	    my $ack = File::Spec->catfile(Cwd::getcwd(), $ACKFILE);
	    return "$write_command $jobname $stat file $dir $req $ack";
	}
    }
}

##############################
# watchの出力一行を処理
# set_job_statusを行ったら1，そうでなければ0，エラーなら-1を返す
my $last_jobname=undef; # 今処理中のジョブの名前（＝最後に見た"spec: <name>"）
                        # handle_inventoryとinvoke_watch_by_socketから参照
sub handle_inventory {
    my ($line) = @_;
    my $ret = 0;
    if ($line =~ /^spec\:\s*(.+)/) {            # ジョブ名
        $last_jobname = $1;
    # ・以下はNFS通信版の話
    # inventory_watch は同じ更新情報を何度も出力するので，
    # 最後の更新より古い情報は無視する．
    # 同じ時刻の更新の場合→「意図する順序」の更新なら受け入れる (ref. set_job_*)
    } elsif ($line =~ /^time_initialized\:\s*([0-9]*)/) {   # ジョブ実行予定
        set_job_initialized ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_prepared\:\s*([0-9]*)/) {   # ジョブ投入直前
        set_job_prepared ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_submitted\:\s*([0-9]*)/) {   # ジョブ投入直前
        set_job_submitted ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_queued\:\s*([0-9]*)/) {   # qsub成功
        set_job_queued ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_running\:\s*([0-9]*)/) {   # プログラム開始
        # まだqueuedになっていなければ書き込まず，0を返すことで再連絡を促す
        # ここでwaitしないのはデッドロック防止のため
        if ( get_job_status ($last_jobname) eq "queued" ) {
            set_job_running ($last_jobname, $1);
            $ret = 1;
        } else {
            $ret = -1;
        }
    } elsif ($line =~ /^time_done\:\s*([0-9]*)/) {   # プログラムの終了（正常） 
        set_job_done ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_finished\:\s*([0-9]*)/) {   # ジョブスレッドの終了 
        set_job_finished ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^time_aborted\:\s*([0-9]*)/) {   # プログラムの終了（正常以外）
        set_job_aborted ($last_jobname, $1);
        $ret = 1;
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # 終了以外のジョブ状態変化
        # とりあえず何もなし
    } elsif ($line =~ /^date\_.*\:\s*(.+)/){    # ジョブ状態変化の時刻
        # とりあえず何もなし
    } elsif ($line =~/^time\_.*\:\s*(.+)/){     # ジョブ状態変化の時刻
        # とりあえず何もなし
    } elsif ($line =~/^:del\s+(\S+)/) {         # ジョブ削除依頼
        entry_signaled_job ($1);
        $ret = 0;
    } elsif ($line =~/^:delall/) {              # 全ジョブ削除依頼
        signal_all_jobs ();
        $ret = 0;
    } else {
        warn "unexpected inventory: \"$line\"\n";
        $ret = -1;
    }
    return $ret;
}

# ジョブの状態変化を監視するスレッドを起動
sub invoke_watch {
    # インベントリファイルの置き場所ディレクトリを作成
    unless (-d "$inventory_path") {
	mkdir $inventory_path, 0755;
    }
    # 起動
    if ( $inventory_port > 0 ) {   # TCP/IP通信で通知を受ける
        invoke_watch_by_socket ();
    } else {                       # NFS経由で通知を受ける
        invoke_watch_by_file ();
    }
}

# 外部プログラムwatchを起動し，その標準出力を監視するスレッドを起動
my $slp = 1;
sub invoke_watch_by_file {
    # 監視スレッドの処理
#    $watch_thread = threads->new( sub {
#        my $interval = 0.1;
        my $interval = 0.5;
#        while (1) {
	    # Can't call Coro::AnyEvent::sleep from a thread of the Thread module.(
	    # common::wait_file ($REQFILE, $interval);
	    my $flag;
	    my $host;
	    my $wd;
	    my $count = 0;
# Coro版監視スレッドがあればジョブオブジェクトを使って監視をするので以下のような監視はしない
=comment
	    until ($flag) {
		my @tmp = %hosts_wds;
		Time::HiRes::sleep ($interval);
		$host = $tmp[$count];
		$wd = $tmp[$count+1];
		$flag = &xcr_exist('-f', $REQFILE, $host, $wd);
		if ($count + 2 < $#tmp) {
		    $count = $count + 2;
		} else {
		    $count = 0;
		}
	    }
=cut

	    my $CLIENT_IN;
	    &xcr_get($REQFILE, $host, $wd);
	    open($CLIENT_IN, '<', $REQFILE) || next;
            my $inv_text = '';
            my $handle_inventory_ret = 0;
            # クライアントからのメッセージは
            # (0行以上のメッセージ行)+(":end"で始まる行)
            while (<$CLIENT_IN>) {
                if ( $_ =~ /^:/ ) {
                    if ( $_ =~ /^:end/ ) {
                        # print STDERR "received :end\n";
                        last;
                    }
                } else {
                    # ':' で始まる行を除いてinventory_fileに保存する
                    $inv_text .= $_;
                }
                # 一度エラーがでたら以降のhandle_inventoryはとばす
                if ( $handle_inventory_ret >= 0 ) {
                    $handle_inventory_ret = handle_inventory ($_, 1);
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
                # エラーがなければinventoryファイルにログを書き込んで:ackを返す
                my $inv_save = File::Spec->catfile($inventory_path,
						   $last_jobname);
                open(my $SAVE, '>>', "$inv_save") or die "Failed to write inventory_file $inv_save\n";
                print $SAVE $inv_text;
                close($SAVE);
                print $CLIENT_OUT ":ack\n";
		close($CLIENT_OUT);
		&xcr_put($ACK_TMPFILE, $host, $wd);
		&xcr_rename($ACK_TMPFILE, $ACKFILE, 'jobsched', $host, $wd);
            } else {
                # エラーがあれば:failedを返す（inventory fileには書き込まない）
                print $CLIENT_OUT ":failed\n";
		close($CLIENT_OUT);
		&xcr_put($ACK_TMPFILE, $host, $wd);
		&xcr_rename($ACK_TMPFILE, $ACKFILE, 'jobsched', $host, $wd);
            }
	    unlink($REQFILE);
#        }
        # close (INVWATCH_LOG);
#				  });
#    $watch_thread->detach();
}

my %sftp_opts = (
                copy_attrs => 1,     # -pと同じ。オリジナルの情報を保持
                recursive => 1,       # -rと同じ。再帰的にコピー
                bwlimit => 40000,  # -lと同じ。転送量のリミットをKbit単位で指定
                glob => 1,               # ファイル名に「*」を使えるようにする。
                quiet => 1,              # 進捗を表示する
    );

# TCP/IP通信によりジョブ状態の変更通知等の外部からの通信を受け付けるスレッドを起動

sub invoke_watch_by_socket {
my $listen_socket = Coro::Socket->new( LocalAddr => 'localhost',
				       LocalPort => 9999,
				       Listen => 10,
				       Proto => 'tcp',
				       ReuseAddr => 1 );
=comment
    my $listen_socket = IO::Socket::INET->new (LocalAddr => $inventory_host,
                                               LocalPort => $inventory_port,
                                               Listen => 10,
                                               Proto => 'tcp',
                                               ReuseAddr => 1);
=cut
    unless ($listen_socket) {
        die "Can't bind : $@\n";
    }
#    $watch_thread = threads->new (sub {
        my $socket;
#        while (1) {
            # print "Waiting for connection.\n";
            $socket = $listen_socket->accept;
print "foo\n";
            # print "Connection accepted.\n";
            unless ($socket) {next;}
            $socket->autoflush();
            my $inv_text = '';
            my $handle_inventory_ret = 0;
            # クライアントからのメッセージは
            # (0行以上のメッセージ行)+(":end"で始まる行)
            while (<$socket>) {
                if ( $_ =~ /^:/ ) {
                    if ( $_ =~ /^:end/ ) {
                        # print STDERR "received :end\n";
                        last;
                    }
                } else {
                    # ':' で始まる行を除いてinventory_fileに保存する
                    $inv_text .= $_;
                }
                # 一度エラーがでたら以降のhandle_inventoryはとばす
                if ( $handle_inventory_ret >= 0 ) {
                    $handle_inventory_ret = handle_inventory ($_, 1);
                }
            }
            if ($handle_inventory_ret >= 0) {
                # エラーがなければinventoryファイルにログを書き込んで:ackを返す
                my $inv_save = File::Spec->catfile($inventory_path, $last_jobname);
                open ( SAVE, ">> $inv_save") or die "Can't open $inv_save\n";
                print SAVE $inv_text;
                close (SAVE);
                $socket->print (":ack\n");
                # print STDERR "sent :ack\n";
            } else {
                # エラーがあれば:failedを返す（inventory fileには書き込まない）
                $socket->print (":failed\n");
                # print STDERR "sent :failed\n";
            }
            $socket->close();
#        }
#    });
#    $watch_thread->detach();
}

# $jobnameに対応するインベントリファイルを読み込んで反映
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
# ジョブ名→request_id
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
# ジョブ状態名→状態レベル数
sub status_name_to_level {
    my ($name) = @_;
    if ( exists ($status_level{$name}) ) {
        return $status_level{$name};
    } else {
        die "status_name_to_runlevel: unexpected status name \"$name\"\n";
    }
}

# ジョブ名→状態
sub get_job_status {
    my ($jobname) = @_;
    if ( exists ($job_status{$jobname}) ) {
        return $job_status{$jobname};
    } else {
        return "initialized";
    }
}
# ジョブ名→最後の状態変化時刻
sub get_job_last_update {
    my ($jobname) = @_;
    if ( exists ($job_last_update{$jobname}) ) {
        return $job_last_update{$jobname};
    } else {
        return -1;
    }
}

# ジョブの状態を変更
sub set_job_status {
    my ($jobname, $stat, $tim) = @_;
    status_name_to_level ($stat); # 有効な名前かチェック
    print "$jobname <= $stat\n";
    {
        $job_status{$jobname} = $stat;
        $job_last_update{$jobname} = $tim;
        $job_status_signal->broadcast();
    }
    # 実行中ジョブ一覧に登録／削除
    if ( $stat eq "queued" || $stat eq "running" ) {
        entry_running_job ($jobname);
    } else {
        delete_running_job ($jobname);
    }
}
sub set_job_initialized  {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "initialized", "initialized", "submitted", "queued", "running", "aborted") ) {
        set_job_status ($jobname, "initialized", $tim);
    }
}
sub set_job_prepared  {
    my ($jobname, $tim) = @_;
    if (do_set_p ($jobname, $tim, "prepared", "initialized") ) {
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
    # finished→done はリトライのときに有り得る
    if (do_set_p ($jobname, $tim, "done", "running", "finished" ) ) {
        set_job_status ($jobname, "done", $tim);
        # リトライのときに実行されると，downされてないセマフォをupしてしまう
# after 処理をメインスレッド以外ですることになり limit.pm が復活したので
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
    if (do_set_p ($jobname, $tim, "aborted", "initialized", "prepared", "submitted", "queued", "running" )
        && $curstat ne "done" && $curstat ne "finished" ) {
        set_job_status ($jobname, "aborted", $tim);
    }
}
# 更新時刻情報や状態遷移の順序をもとにsetを実行してよいかを判定
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
# $jobnameの状態が，$whoによる状態遷移の期待するもの（@e_statsのどれか）であるかをチェック
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

# ジョブ"$jobname"の状態が$stat以上になるまで待つ
sub wait_job_status {
    my ($jobname, $stat) = @_;
    my $stat_lv = status_name_to_level ($stat);
    my $slp=0.1; my $slp_max=2;
    # print "$jobname: wait for the status changed to $stat($stat_lv)\n";
    until ( &status_name_to_level (&get_job_status ($jobname))
            >= $stat_lv) {
print &status_name_to_level (&get_job_status ($jobname));
        Coro::AnyEvent::sleep $slp;
        $slp *= 2;
        $slp = $slp>$slp_max ? $slp_max : $slp;
        ## Does not work because inventory_watch thread is a Perl thread
        # $job_status_signal->wait;
    }
    # print "$jobname: exit wait_job_status\n";
}
sub wait_job_initialized    { wait_job_status ($_[0], "initialized"); }
sub wait_job_prepared  { wait_job_status ($_[0], "prepared"); }
sub wait_job_submitted { wait_job_status ($_[0], "submitted"); }
sub wait_job_queued    { wait_job_status ($_[0], "queued"); }
sub wait_job_running   { wait_job_status ($_[0], "running"); }
sub wait_job_done      { wait_job_status ($_[0], "done"); }
sub wait_job_finished  { wait_job_status ($_[0], "finished"); }
sub wait_job_aborted   { wait_job_status ($_[0], "aborted"); }

# すべてのジョブの状態を出力（デバッグ用）
sub print_all_job_status {
    foreach my $jn (keys %job_status) {
        print "$jn:" . get_job_status ($jn) . " ";
    }
    print "\n";
}

##################################################
# "running"なジョブ一覧の更新
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

# running_jobsのジョブがabortedになってないかチェック
# 状態が "queued" または "running"にもかかわらず，qstatで当該ジョブが出力されないものを
# abortedとみなし，ジョブ状態ハッシュを更新する．
# また，signaledなジョブがqstatに現れたらqdelする
### Note:
# ジョブ終了後（done書き込みはスクリプト内なので終わっているはず．
# ただし，NFSのコンシステンシ戦略によっては危ないかも）
# inventory_watchからdone書き込みの通知がXcryptに届くまでの間に
# abort_checkが入ると，abortedを書き込んでしまう．
# → TCP/IP版はジョブ状態変更通知後，ackを待つようにしたので上記は起こらないはず．
# → NFS版もそうすべき
sub check_and_write_aborted {
    my %unchecked;
    {
        # %running_jobs のうち，qstatで表示されなかったジョブが%uncheckedに残る
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
            # ここでsignaledのチェックもする．
            if ($jobname && is_signaled_job($jobname)) {
                delete_signaled_job($jobname);
                qdel ($jobname);
            }
        }
    }
    # %uncheckedに残っているジョブを"aborted"にする．
    foreach my $req_id ( keys %unchecked ) {
        if ( exists $running_jobs{$req_id} ) {
            print STDERR "aborted: $req_id: " . $unchecked{$req_id} . "\n";
#            inventory_write ($unchecked{$req_id}, "aborted");
            inventory_write ($unchecked{$req_id}, "aborted", $initialized_nosync_jobs{$unchecked{$req_id}}->{rhost}, $initialized_nosync_jobs{$unchecked{$req_id}}->{rwd});
        }
    }
}

# sub invoke_periodic {
#     $periodic_thread = Coro::async_pool {
#        while (1) {
# # ユーザ定義の定期的実行文字列
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
            ## inv_watch/* のopenがhandle_inventoryと衝突してエラーになるので
            ## とりあえずコメントアウト
            # &builtin::check_and_alert_elapsed();
        }
    };
    # print "invoke_abort_check done.\n";
}

1;
