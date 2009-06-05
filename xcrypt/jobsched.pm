# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use threads;
use threads::shared;
use Cwd;
use File::Basename;
use File::Spec;
use threads::shared;
# use Thread::Semaphore;

##################################################

# my $qsub_command="../kahanka/qsub";
# my $qdel_command="../kahanka/qdel";
# my $qstat_command="../kahanka/qstat";
my $qsub_command="qsub";
my $qdel_command="qdel";
my $qstat_command="qstat";

my $current_directory=Cwd::getcwd();

my $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'pjo_inventory_write.pl');
# my $write_opt="";

# pjo_watch.pl は出力をバッファリングしない設定 ($|=1)
# にしておくこと（fujitsuオリジナルはそうなってない）
#
my $watch_command="pjo_inventory_watch.pl";
my $watch_opt="-i summary -e end -t 86400 -s"; # -s
my $watch_path=File::Spec->catfile($current_directory, 'inv_watch');
#my $watch_thread=undef;
our $watch_thread=undef;

# ジョブ名→ジョブの状態
my %job_status : shared;

##################################################
# ジョブスクリプトを生成し，必要なwriteを行った後，ジョブ投入
sub qsub {
    my ($job_name, # ジョブ名
        $command,  # 実行するコマンドの文字列
        $dirname,      # 実行ファイル置き場（スクリプト実行場所からの相対パス）
        $scriptfile, # スクリプトファイル名
        # 以下の引数はoptional
	$queue,
        $option,
        $stdofile, $stdefile, # 標準／エラー出力先（qsubのオプション）
        # 以下，NQSのオプション
        $proc, $cpu, $memory, $verbose, $verbose_node,
        ) = @_;
    my $file = File::Spec->catfile($watch_path, $dirname);
    my $jobspec = "\"spec: $job_name\"";
    open (SCRIPT, ">$scriptfile");
    print SCRIPT "#!/bin/sh\n";
    # NQS も SGE も，オプション中の環境変数を展開しないので注意！
    print SCRIPT "#\$ -S /bin/sh\n";
    if ($queue) {
	print SCRIPT "# @\$-q $queue\n";
    }
    print SCRIPT "$option\n";
    if ($stdofile) {
	print SCRIPT "#\$ -o $ENV{'PWD'}/$stdofile\n";
	print SCRIPT "# @\$-o $ENV{'PWD'}/$stdofile\n";
    }
    if ($stdefile) {
	print SCRIPT "#\$ -e $ENV{'PWD'}/$stdefile\n";
	print SCRIPT "# @\$-e $ENV{'PWD'}/$stdefile\n";
    }
    if ($proc) {
	print SCRIPT "# @\$-lP $proc\n";
    }
    if ($cpu) {
	print SCRIPT "# @\$-lp $cpu\n";
    }
    if ($memory) {
	print SCRIPT "# @\$-lm $memory\n";
    }
    if ($verbose) {
	print SCRIPT "# @\$-oi\n";
    }
    if ($verbose_node) {
	print SCRIPT "# @\$-OI\n";
    }

#    print SCRIPT "PATH=$ENV{'PATH'}\n";
#    print SCRIPT "set -x\n";
    print SCRIPT "$write_command $file \"start\" $jobspec\n";
    print SCRIPT "cd $ENV{'PWD'}/$dirname\n";
#    print SCRIPT "cd \$QSUB_WORKDIR/$dirname\n";
    print SCRIPT "$command\n";
    # 正常終了でなければ "abort" を書き込むべき
    print SCRIPT "$write_command $file \"done\" $jobspec\n";
    close (SCRIPT);
    system ("$write_command $file \"submit\" $jobspec");
    my $id = qx/$qsub_command $scriptfile/;
    my $idfile = File::Spec->catfile($dirname, 'request_id');
    open (REQUESTID, ">> $idfile");
    print REQUESTID $id;
    close (REQUESTID);
}

##############################
# 外部プログラムwatchを起動し，その標準出力を監視するスレッドを起動
sub invoke_watch {
    # インベントリファイルの置き場所ディレクトリを作成
    if ( !(-d $watch_path) ) {
        mkdir $watch_path or
        die "Can't make $watch_path: $!.\n";
    }
    foreach (".tmp", ".lock") {
        if ( !(-d "$watch_path/$_") ) {
            mkdir "$watch_path/$_" or
                die "Can't make $watch_path/$_: $!.\n";
        }
    }
    # 以下，監視スレッドの処理
    $watch_thread =  threads->new( sub {
        open (INVWATCH, "$watch_command $watch_path $watch_opt |");
        while (1) {
            while (<INVWATCH>){
                handle_inventory ($_);
            }
            close (INVWATCH);
            print "watch finished.\n";
            open (INVWATCH, "$watch_command $watch_path $watch_opt -c |");
        }
    });
}

# watchの出力一行を処理
my $last_jobname=undef; # 今処理中のジョブの名前（＝最後に見た"spec: <name>"）
sub handle_inventory {
    my ($line) = @_;
    if ($line =~ /^spec\:\s*(.+)/) {            # ジョブ名
        $last_jobname = $1;
    } elsif ($line =~ /^status\:\s*done/) {     # ジョブの終了（正常）
        set_job_done ($last_jobname); # ジョブ状態ハッシュを更新（＆通知）
    } elsif ($line =~ /^status\:\s*abort/) {    # ジョブの終了（正常以外）
        set_job_abort ($last_jobname); # ジョブ状態ハッシュを更新（＆通知）
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # 終了以外のジョブ状態変化
        # とりあえず何もなし
    } elsif (/^date\_.*\:\s*(.+)/){             # ジョブ状態変化の時刻
        # とりあえず何もなし
    } elsif (/^time\_.*\:\s*(.+)/){             # ジョブ状態変化の時刻
        # とりあえず何もなし
    } else {
        warn "unexpected inventory output: \"$line\"\n";
    }
}

##############################
# ジョブの状態を変更
sub set_job_done {
    my ($jobname) = @_;
    lock (%job_status);
    $job_status{$jobname} = "done";
    cond_broadcast (%job_status);
}
sub set_job_abort {
    my ($jobname) = @_;
    lock (%job_status);
    $job_status{$jobname} = "abort";
    cond_broadcast (%job_status);
}
## 呼び出すタイミング（そもそも必要か）がわからない
# sub set_job_submit  { ... }
# sub set_job_running { ... }

# ジョブ"$jobname"の状態がdoneになるまで待つ
sub wait_job_done {
    my ($jobname) = @_;
    lock (%job_status);
#    while ($job_status{$jobname} != "done") {
    until ($job_status{$jobname} eq 'done') {
        cond_wait (%job_status);
    }
}

# スレッド起動（読み込むだけで起動，は正しい？）
invoke_watch ();
## スレッド終了待ち：デバッグ（jobsched.pm単体実行）用
# $watch_thread->join();

1;


## 自前でwatchをやろうとした残骸
#         my %timestamps = {};
#         my @updates = ();
#         foreach (glob "$watch_path/*") {
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
