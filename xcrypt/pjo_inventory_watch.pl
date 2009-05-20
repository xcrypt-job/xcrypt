#!/usr/bin/perl
$|=1; # 出力をバッファリングしない
use strict;
use warnings;
use File::stat;
use File::Basename;
use File::Spec;
use Time::localtime;
use Getopt::Long;
use Carp;
#-----------------------------------------------------------------
#■ 変数定義
my $inventory_dir = undef;
my $inventory_tmp_dir = undef;
my $option_i = undef;
my $option_e = undef;
my $option_o = undef;
my $option_t = undef;
my $option_c = undef;
my $option_s = undef;
my $time_out = undef;
my @stdout_data = ();
my @pjo_save_data = ();
my @inventory_files_date = ();
#-----------------------------------------------------------------
#■ コマンドライン引数チェック
sub check_cmdline {
    # 引数取得
    if (@ARGV < 1 || $ARGV[0] =~ m/^\-/) {
        print STDERR "pjo_inventory_watch Inventory-Path option error\n";
        exit 99;
    }
    $inventory_dir = shift @ARGV;
    GetOptions ('i:s' => \$option_i, 'e:s' => \$option_e, 'o:s' => \$option_o, 't:s' => \$option_t, 'c' => \$option_c , 's' => \$option_s);
    # インベントリディレクトリ
    if (!-d $inventory_dir) {
        print STDERR "Inventory-Path option error\n";
        exit 99;
    } elsif (!-w $inventory_dir) {
        print STDERR "Inventory-Path is not write authority\n";
        exit 99;
    } elsif (!-r $inventory_dir) {
        print STDERR "Inventory-Path is not read authority\n";
        exit 99;
    }
    # 出力レベル
    if (! defined($option_i)) {
        $option_i = 'summary';
    } elsif ($option_i ne 'summary' and $option_i ne 'all') {
        print STDERR "output-level option error\n";
        exit 99;
    }
    # 監視対象
    if (! defined($option_e)) {
        $option_e = 'end';
    } elsif ($option_e ne 'end' and $option_e ne 'all') {
        print STDERR"monitor-object option error\n";
        exit 99;
    }
    # 保存ファイル名
    if (defined($option_o)) {
        my $stdout_file = File::Spec->catfile(dirname($0), "$option_o");
        if (! open (STDOUT_FILE, ">$stdout_file")) {
            print STDERR "output-filename option error\n";
            exit 99;
        }
    }
    close(STDOUT_FILE);
    # タイムアウト
    if (defined($option_t)) {
        if ($option_t =~ /[^0-9]/) {
            $option_t = '';
        }
        if ($option_t eq '' or
            $option_t < 0 or
            $option_t > 86400) {
            print STDERR "time-out option error\n";
            exit 99;
        } else {
            $time_out = $option_t;
        }
    } else {
        # configファイルよりabortcheckintervalを取得
        my $abortcheckinterval = undef;
        my $config_dir = "/etc/opt/FJSVplang/pjo";
        my $config_file = File::Spec->catfile($config_dir, "pjo.conf");
        if (! open (CONFIG_FILE, "$config_file")) {
            print STDERR "$config_dir: cannot open file. (file: $config_file)\n";
            exit 99;
        }
        while (<CONFIG_FILE>){
            next if (/^#/) ;
            if(/--abortcheckinterval\s*(\d+)/){
                $abortcheckinterval = $1;
            }
        }
        close(CONFIG_FILE);
        # abortcheckintervalが指定されていない
        if(! defined( $abortcheckinterval ) ) {
            print STDERR "$config_dir: abortcheckinterval:abortcheckinterval option is not set.\n";
            exit 99;
        }
        $option_t = '';
        $time_out = $abortcheckinterval;
    }
    # その他
    if (@ARGV > 0) {
        print STDERR "unnecessary option error";
        exit 99;
    }
}
#-----------------------------------------------------------------
#■ テンポラリディレクトリチェック
sub check_inventorytmp_dir {
    $inventory_tmp_dir = "$inventory_dir/\.tmp";
    if ( -d $inventory_tmp_dir) {
        if (! -w $inventory_tmp_dir) {
            print STDERR "$inventory_tmp_dir is not write authority\n";
            exit 99;
        } elsif (! -r $inventory_tmp_dir) {
            print STDERR "$inventory_tmp_dir is not read authority\n";
            exit 99;
        }
    }
}
#-----------------------------------------------------------------
#■ インベントリ監視ツール２重起動チェック
sub check_multiplex_submit {
    my $pjo_watch_lock = File::Spec->catfile( $inventory_tmp_dir, "\.pjo_watch_lock" );
    if ( -e $pjo_watch_lock) {
        # プロセスＩＤ取得
        if (! open (PJO_WATCH_LOCK, "$pjo_watch_lock")) {
            print STDERR "$inventory_tmp_dir: cannot open file. (file: $pjo_watch_lock)\n";
            exit 99;
        }
        my $check_lock_id = <PJO_WATCH_LOCK> ;
        chomp $check_lock_id;
        # プロセス存在チェック
        unless (kill(0, $check_lock_id) == 0){
            # 存在する
            print STDERR "multiplex submit error\n";
            exit 99;
        }
        close(PJO_WATCH_LOCK);
    }
    # ロックファイル出力
    if (! open (PJO_WATCH_LOCK, ">$pjo_watch_lock")) {
        print STDERR "$inventory_tmp_dir: cannot open file. (file: $pjo_watch_lock)\n";
        exit 99;
    }
    print PJO_WATCH_LOCK "$$\n";
    close(PJO_WATCH_LOCK);
}
#-----------------------------------------------------------------
#■ Pjo_Save_Dataファイル情報取得
sub get_pjo_save_data {
    @pjo_save_data = ();
    if (! defined( $option_c)) {
        my $pjo_save_data_file = File::Spec->catfile( $inventory_tmp_dir, "\.pjo_save_data" );
        if ( -e $pjo_save_data_file) {
            if (! -w $pjo_save_data_file) {
                print STDERR "$inventory_tmp_dir/.pjo_save_data is not write authority\n";
                exit 99;
            } elsif (! -r $pjo_save_data_file) {
                print STDERR "$inventory_tmp_dir/.pjo_save_data is not read authority\n";
                exit 99;
            } elsif (! open (SAVE_DATA_FILE, "$pjo_save_data_file")) {
                print STDERR "$inventory_tmp_dir: cannot open file. (file: $pjo_save_data_file)\n";
                exit 99;
            }
            while (<SAVE_DATA_FILE>){
                chomp;
                push(@pjo_save_data, $_);
            }
            close (SAVE_DATA_FILE);
        }
    }
}
#-----------------------------------------------------------------
#■ インベントリファイル更新日時取得
sub get_inventory_files_date {
    my @inventory_files_date = ();
    foreach my $inventory_file (@_) {
        if ($inventory_file =~ /\.END/){ next };                 #################### 新しいInventoryでは無いかも ####################
        if ($inventory_file =~ /\.all/){ next };                 #################### 新しいInventoryでは無いかも ####################
        my $inventory_file_date = ctime(stat($inventory_file)->mtime);
        push(@inventory_files_date , "$inventory_file, $inventory_file_date");
    }
    return @inventory_files_date
}
#-----------------------------------------------------------------
#■ インベントリファイルstatusチェック
sub get_inventory_files_status {
    my $check_status = '';
    my $check_status_kbn = undef;
    my $check_return = 0;
    foreach my $inventory_file (@_) {
        if ($inventory_file =~ /\.END/){ next };                 #################### 新しいInventoryでは無いかも ####################
        if ($inventory_file =~ /\.all/){ next };                 #################### 新しいInventoryでは無いかも ####################
        my $inventory_file_name = File::Spec->catfile( "$inventory_file" );
        if (! open (CHECK_FILE, "$inventory_file_name")) {
            print STDERR "$inventory_dir: cannot open file. (file: $inventory_file_name)\n";
            exit 99;
        }
        while (<CHECK_FILE>){
            if (/^status\:\s*([a-z]*)/) {
                $check_status = $1
            }
        }
        close (CHECK_FILE);
        if ($check_status ne 'done' and $check_status ne 'abort' and $check_status ne 'undo' and $check_status ne '') {
            $check_return = 1;
        } elsif (! defined( $check_status_kbn)) {
            if ($check_status eq 'done' or $check_status eq 'abort') {
                $check_status_kbn = 1;
            } else {
                $check_status_kbn = 2;
            }
        } elsif ($check_status_kbn == 1 and ($check_status eq 'undo' or $check_status eq '')) {
            $check_return = 1;
        } elsif ($check_status_kbn == 2 and $check_status ne 'undo' and $check_status ne '') {
            $check_return = 1;
        }
    }
    return $check_return;
}
#-----------------------------------------------------------------
#■ Inventoryファイル更新日時一覧取得
sub get_inventory_files_data {
    # ファイル一覧取得
    my @inventory_files = glob "$inventory_dir/*";
    @inventory_files = grep{ -f $_ } @inventory_files;
    # インベントリファイル更新日時取得
    @inventory_files_date = &get_inventory_files_date(@inventory_files);
    # インベントリファイルstatusチェック
    return &get_inventory_files_status(@inventory_files);
}
#-----------------------------------------------------------------
#■ 状態変化チェック
sub check_diff {
    my $check_diff = 0;
    # diff比較
    my @check_files = ();
    my %diffs = ();
    $diffs{$_} .= 1 for @pjo_save_data;
    $diffs{$_} .= 2 for @inventory_files_date;
    for (sort keys %diffs) {
        if ($diffs{$_} !~ /1/) {
            my @check_file = split(/,/, $_);
            push(@check_files , $check_file[0]);
        }
    }
    # 監視対象チェック、情報取得
    # my @stdout_data = ();
    foreach my $check_file (@check_files) {
        my @check_data = ();
        my $check_status = '';
        my $check_spec = '';
        my $check_file_name = File::Spec->catfile( "$check_file" );
        if (! open (CEHCK_FILE, "$check_file_name")) {
            print STDERR "$inventory_dir: cannot open file. (file: $check_file_name)\n";
            exit 99;
        }
        while (<CEHCK_FILE>){
            if (/^spec\:\s*(.+)/){
                $check_spec = $_;
            } elsif (/^status\:\s*([a-z]*)/){
                $check_status = $1;
                @check_data = ();
            } elsif (/^date\_.*\:\s*(.+)/){
                push(@check_data , $_);
            } elsif (/^time\_.*\:\s*(.+)/){
                push(@check_data , $_);
            }
            if ($check_status eq 'start' and $option_i eq 'all') {
                if (/^hostname\:\s*(.+)/){
                    push(@check_data , $_);
                }
            } elsif ($check_status eq 'submit' and $option_i eq 'all') {
                if (/^command\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^workdir\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^submitdir\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^scriptfile\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^master\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^qsubdir\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^masteraddr\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^DEPEND\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^DependFilesEnd\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^DependFilesEnd\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^DependFile\-.+\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^job\_script\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^job\_script\_body\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^envfile\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^dojob\_pid\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^localID\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^paramvar\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^whenline\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^timestamp\_for\_cookie\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^cookie\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^attribute\_.+\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^batchtype\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^batchtype\_path\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^JobID\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^qsub\_command\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^stdout\_file\:\s*(.+)/){
                    push(@check_data , $_);
                } elsif (/^stderr\_file\:\s*(.+)/){
                    push(@check_data , $_);
                }
            }
        }
        close (CEHCK_FILE);
        # 情報蓄積
        if ($check_status eq 'done' or
            $check_status eq 'abort' or
            $option_e eq 'all') {
            push(@stdout_data , $check_spec);
            push(@stdout_data , "status: $check_status\n");
            foreach my $check_data (@check_data) {
                push(@stdout_data , $check_data);
            }
            $check_diff = 1;
        }
    }

    return $check_diff;
}
#-----------------------------------------------------------------
#■ 出力対象情報出力
sub put_outdata {
    if (defined($option_o)) {
        my $stdout_file = File::Spec->catfile(dirname($0), "$option_o");
        if (! open (STDOUT_FILE, ">$stdout_file")) {
            print STDERR "$0: cannot open file. (file: $stdout_file)\n";
            exit 99;
        }
        foreach my $stdout_data (@stdout_data) {
            print STDOUT_FILE $stdout_data;
        }
        close (STDOUT_FILE);
    } else {
        foreach my $stdout_data (@stdout_data) {
            print $stdout_data;
        }
    }

    return 0;
}
#-----------------------------------------------------------------
#■ Pjo_Save_Dataファイル出力
sub Put_pjo_save_data {
    my $pjo_save_data_file = File::Spec->catfile($inventory_tmp_dir, "\.pjo_save_data");
    if (! open (SAVE_DATA_FILE, ">$pjo_save_data_file")) {
        print STDERR "$inventory_tmp_dir: cannot open file. (file: $pjo_save_data_file)\n";
        exit 99;
    }
    foreach my $inventory_files_date (@inventory_files_date) {
        print SAVE_DATA_FILE "$inventory_files_date\n";
    }
    close(SAVE_DATA_FILE);
}
#-----------------------------------------------------------------
#■ ＭＡＩＮ
# コマンドライン引数チェック
&check_cmdline();
# テンポラリディレクトリチェック
&check_inventorytmp_dir();
# インベントリ監視ツール２重起動チェック
&check_multiplex_submit();
# Pjo_Save_Dataファイル情報取得
&get_pjo_save_data();
# Inventoryファイル更新日時一覧取得
my $check_status = &get_inventory_files_data();
if (defined($option_c)) {
    @pjo_save_data = @inventory_files_date;
}
# inventory_watch_path
my $check_diff_fkg = &check_diff();
if ($time_out > 0 and $check_diff_fkg == 0) {
    # 基準時間を取得
    my $start_time = time;
    my $sleep_time = 10;
    my $max_time = $time_out;
    # タイマー監視
    eval {
        local $SIG{ALRM} = sub {die "timeout"};
        local $SIG{TERM}  = sub {die "signal"};
        alarm $time_out;
        while ($check_diff_fkg == 0) {
            # sleep待ち
            if ($sleep_time > $max_time) {$sleep_time = $max_time};
            sleep $sleep_time;
            $max_time = $max_time - $sleep_time;
            # Inventoryファイル更新日時一覧取得
            $check_status = &get_inventory_files_data();
            # 状態変化チェック、出力対象情報出力
            $check_diff_fkg = &check_diff();

            # 出力対象情報出力
            if ($check_diff_fkg == 1) {
                &put_outdata();
                # シグナル終了対応
                if (defined($option_s)) {
                    @pjo_save_data = @inventory_files_date;
                    &Put_pjo_save_data;
                    $check_diff_fkg = 0;
                }
            }
        }
        alarm 0;
    };
    alarm 0;
}
# Pjo_Save_Dataファイル出力
if ($check_diff_fkg == 1) {
    &Put_pjo_save_data;
}
# ロックファイル削除
my $pjo_watch_lock = File::Spec->catfile( $inventory_tmp_dir, "\.pjo_watch_lock" );
unlink $pjo_watch_lock;
#-----------------------------------------------------------------
if($@) {
    if($@ =~ /timeout/) {
        if ($check_status == 1) {
            exit 16;
        } else {
            exit 1;
        }
    } elsif ($@ =~ /signal/) {
        exit 0;
    } else {
        exit 99;
    }
}
exit 0;
