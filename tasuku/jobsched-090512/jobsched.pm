# Job scheduler I/F  (written by Tasuku HIRAISHI)
package jobsched;

use threads;
use threads::shared;
use Cwd;
use File::Basename;
use Thread::Semaphore;

##################################################

# my $qsub_command="../kahanka/qsub";
# my $qdel_command="../kahanka/qdel";
# my $qstat_command="../kahanka/qstat";
my $qsub_command="qsub";
my $qdel_command="qdel";
my $qstat_command="qstat";

my $current_directory=Cwd::getcwd();

my $inventory_write_command="perl pjo_inventory_write.pl";
# my $inventory_write_opt="";

# pjo_inventory_watch.pl は出力をバッファリングしない設定 ($|=1) 
# にしておくこと（fujitsuオリジナルはそうなってない）
my $inventory_watch_command="perl pjo_inventory_watch.pl";
my $inventory_watch_opt="-i summary -e end -t 86400 -s"; # -s
my $inventory_watch_path="$current_directory/inv_watch";
my $inventory_watch_thread=undef;

# ジョブ名→条件変数（セマフォ）
my %jobthread_conds={};

##################################################
# ジョブスクリプトを生成し，必要なinventory_writreを行った後，ジョブ投入
sub qsub {
    my ($job_name, # ジョブ名
        $command,  # 実行するコマンドの文字列
        $dir,      # 実行ファイル置き場（スクリプト実行場所からの相対パス）
        $scriptfile, # スクリプトファイル名
        # 以下の引数はoptional
        $stderr_file, $stdout_file, # 標準／エラー出力の出力先（qsubのオプション）
        # 以下，NQSのオプション
        $verbose, $verbose_node, $queue, $process, $cpu, $memory
        ) = @_;
    my $inventory_file = $dir/$job_name;
    my $jobspec = "\"spec: $job_name\"";
    open (SCRIPT, ">$scriptfile");
    if ($verbose == "") { print SCRIPT "# @\$-oi\n"; }
    if ($verbose_node)  { print SCRIPT "# @\$-OI\n"; }
    if ($queue)         { print SCRIPT "# @\$-q $queue\n"; }
    if ($process)       { print SCRIPT "# @\$-lP $process\n"; }
    if ($cpu)           { print SCRIPT "# @\$-lp $cpu\n"; }
    if ($memory)        { print SCRIPT "# @\$-lm $memory\n"; }
    print SCRIPT "cd \$QSUB_WORKDIR \n";
    print SCRIPT "$inventory_write_command $inventory_file \"start\" $jobspec\n";
    print SCRIPT "cd \$QSUB_WORKDIR/$dir \n";
    print SCRIPT "$command\n";
    print SCRIPT "cd \$QSUB_WORKDIR \n";
    # 正常終了でなければ "abort" を書き込むべき
    print SCRIPT "$inventory_write_command $inventory_file \"done\" $jobspec\n";
    close (SCRIPT);
    my $stderr_option = ($stderr_file = "")?"":"-e $stderr_file";
    my $stdout_option = ($stdout_file = "")?"":"-o $stdout_file";
    system ("$inventory_write_command $inventory_file \"submit\" $jobspec");
    system ("$qsub_command $stderr_option $stdout_option $scriptfile");
}

##############################
# 外部プログラムinventory_watchを起動し，その標準出力を監視するスレッドを起動
sub invoke_inventory_watch {
    # インベントリファイルの置き場所ディレクトリを作成
    if ( !(-d $inventory_watch_path) ) {
        mkdir $inventory_watch_path or
        die "Can't make $inventory_watch_path: $!.\n";
    }
    foreach (".tmp", ".lock") {
        if ( !(-d "$inventory_watch_path/$_") ) {
            mkdir "$inventory_watch_path/$_" or
                die "Can't make $inventory_watch_path/$_: $!.\n";
        }
    }
    # 以下，監視スレッドの処理
    $inventory_watch_thread =  threads->new( sub {
        open (INVWATCH, "$inventory_watch_command $inventory_watch_path $inventory_watch_opt |");
        while (1) {
            while (<INVWATCH>){
                handle_inventory ($_);
            }
            close (INVWATCH);
            print "inventory_watch finished.\n";
            open (INVWATCH, "$inventory_watch_command $inventory_watch_path $inventory_watch_opt -c |");
        }
    });
}

# inventory_watchの出力一行を処理
my $last_jobname=undef; # 今処理中のジョブの名前（＝最後に見た"spec: <name>"）
sub handle_inventory {
    my ($line) = @_;
    if ($line =~ /^spec\:\s*(.+)/) {            # ジョブ名
        $last_jobname = $1;
    } elsif ($line =~ /^status\:\s*done/) {     # ジョブの終了（正常）
        jobthread_signal ($last_jobname); # ジョブ終了を待っているスレッドを起こす
    } elsif ($line =~ /^status\:\s*abort/) {    # ジョブの終了（正常以外）
        jobthread_signal ($last_jobname); # ジョブ終了を待っているスレッドを起こす
    } elsif ($line =~ /^status\:\s*([a-z]*)/) { # 終了以外のジョブ状態変化
        # とりあえず何もなし
    } elsif (/^date\_.*\:\s*(.+)/){             # ジョブ状態変化の時刻
        # とりあえず何もなし
    } else {
        warn "unexpected inventory output: \"$line\"\n";
    }
}

##############################
# 誰かが jobthread_signal($jobname) で起こしてくれるまで寝る
sub jobthread_condwait {
    my ($jobname) = @_;
    if (!exists ($jobthread_conds{$jobname})) {
        $jobthread_conds{$jobname} = Thread::Semaphore->new(0);
    }
    $jobthread_conds{$jobname}->down;
}

# jobthread_condwait($jobname) で寝ているスレッドを起こす
sub jobthread_signal {
    my ($jobname) = @_;
    if (!exists ($jobthread_conds{$jobname})) {
        # 正常実行でも，タイミングによって!existsなことがあるかも
        # （busy waitで待てばよい？）
        print STDERR "Conditional variable for $jobname thread does not exists.\n";
        exit 255;
    }
    $jobthread_conds{$jobname}->up;
}

# スレッド起動（読み込むだけで起動，は正しい？）
invoke_inventory_watch ();
## スレッド終了待ち：デバッグ（jobsched.pm単体実行）用
# $inventory_watch_thread->join();

1;


## 自前でinventory_watchをやろうとした残骸
#         my %timestamps = {};
#         my @updates = ();
#         foreach (glob "$inventory_watch_path/*") {
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
