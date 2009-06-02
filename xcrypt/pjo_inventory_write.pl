#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;

#------------< 変数の定義 >------------#
my $inventory_dir = undef;
my $inventory_lock_dir = ".lock";
my $inventory_name = undef;
my $inventory_file = undef;
my $inventory_status = undef;
my @inventory_write_datas = ();
my $time_out = 10;                                                   # timeout秒
#------------------------------------------------------------------------------#
#   ＜＜ check_cmdline(コマンドライン引数チェック)の定義 ＞＞                  #
#------------------------------------------------------------------------------#
sub check_cmdline {
        ############################################
        # $ARGV[0] = Inventoryファイル名(フルパス) #
        # $ARGV[1] = status                        #
        # $ARGV[2] = 追加情報                      #
        ############################################
        #----引数取得----#
    if ($#ARGV < 1) {
                # 必須引数なし
        print STDERR "pjo_inventory_write option error\n";
        exit 99;
    }
    $inventory_file = shift @ARGV;
    $inventory_dir = dirname($inventory_file);
    $inventory_name = basename($inventory_file);
    $inventory_status = $ARGV[0];
    while ($#ARGV > 0) {
        unless ($ARGV[1] eq '') {
            push(@inventory_write_datas , $ARGV[1]);
        }
        shift @ARGV;
    }
        #----取得した引数をチェック----#
        # Inventoryファイル名
    if (-e $inventory_file) {
        if (! -w $inventory_file) {
            print STDERR "$inventory_file is not write authority\n";
            exit 99;
        } elsif (! -r $inventory_file) {
            print STDERR "$inventory_file is not read authority\n";
            exit 99;
        }
    }
        # status
    if ($inventory_status eq '') {
        print STDERR "status option error\n";
        exit 99;
    }
        # 追加情報
    foreach my $inventory_write_data(@inventory_write_datas) {
        if ( $inventory_write_data !~ m/^.+\:\s+/) {
            print STDERR "Additional Information does not match a pattern \($inventory_write_data\)\n";
            exit 99;
        }
    }
}
#------------------------------------------------------------------------------#
#   ＜＜ Put_inventory_update(Inventoryファイル出力)の定義 ＞＞                #
#------------------------------------------------------------------------------#
sub Put_inventory_update {
    if ($inventory_status ne 'qsub' and 'abort') {
                # ロックファイル存在確認(削除されるまで待つ)
        if (-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
            my $check_lock_fkg = 0;
                        # タイマー監視
            eval {
                local $SIG{ALRM} = sub {die "timeout"};
                alarm $time_out;
                while ($check_lock_fkg == 0) {
                                        # sleep待ち
                    sleep 1;
                                        # ロックファイル存在確認
                    if (!-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
                        $check_lock_fkg = 1;
                    }
                }
                alarm 0;
            };
            alarm 0;
            if($@) {
                if($@ =~ /timeout/) {
                    print STDERR "${inventory_dir}/${inventory_lock_dir}/${inventory_name} cannot open timeout\n";
                    exit 99;
                }
            }
        }
    }
        
        # InventoryファイルOPEN
    if (! open (INVENTORY_FILE, "+>>$inventory_file")) {
        print STDERR "$inventory_file cannot open file\n";
        exit 99;
    }
        # Inventoryファイルの排他ロック
    flock(INVENTORY_FILE, 2);
        
        # 基本情報の出力
    if ($inventory_status ne 'qsub') {
                # statusの出力
        print INVENTORY_FILE "status: $inventory_status\n";
                # 年月日時分秒を取得
        my $time_now = time();
        my @times = localtime($time_now);
        my ($year, $mon, $mday, $hour, $min, $sec, $wday) = ($times[5] + 1900, $times[4] + 1, $times[3], $times[2], $times[1], $times[0], $times[6]);
        my $timestring = sprintf("%04d%02d%02d_%02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
                # 年月日時分秒の出力
        print INVENTORY_FILE "date_${inventory_status}: $timestring\n";
        print INVENTORY_FILE "time_${inventory_status}: $time_now\n";
    }
        # 追加情報の出力
    foreach my $inventory_write_data(@inventory_write_datas) {
        print INVENTORY_FILE $inventory_write_data."\n";
                #print "inventory_write_data = $inventory_write_data\n";
    }
        # ロックファイル作成
    if ($inventory_status eq 'submit') {
        if (!-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
            if (! open (INVENTORY_FILE_LOCK, ">${inventory_dir}/${inventory_lock_dir}/${inventory_name}")) {
                print STDERR "${inventory_dir}/${inventory_lock_dir}/${inventory_name} cannot make file\n";
                exit 99;
            }
            close(INVENTORY_FILE_LOCK);
        }
    }
        # ロックファイル削除
    if ($inventory_status eq 'qsub' or 'abort') {
        if (-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
            unlink "${inventory_dir}/${inventory_lock_dir}/${inventory_name}";
        }
    }
        # InventoryファイルCLOSE
    close(INVENTORY_FILE);
}
#------------------------------------------------------------------------------#
#   ＜＜ メイン処理の定義 ＞＞                                                 #
#------------------------------------------------------------------------------#
# コマンドライン引数チェック
&check_cmdline();
# Inventoryファイル出力
&Put_inventory_update();
exit 0;
