############################################
# ＜＜出力データ抽出＞＞                   #
# Copyright FUJITSU LIMITED 2009           #
# Ver=0.1 2009/08/07                       #
############################################
package Data_Extraction;
use Exporter;
@ISA    = (Exporter);
@EXPORT = qw(EF);
use strict;
use File::Basename;
use Cwd;

#-------------------------------------------------------------------------------------------------#
#   ＜＜ EF(抽出対象ファイル定義コマンド)の定義 ＞＞                                              #
#-------------------------------------------------------------------------------------------------#
sub EF{
    ############################################
    # $obj = 入力(リスト名 or ファイル名)      #
    ############################################
    my $in_kbn          = undef;
    my $in_name         = undef;
    my $in_name_check   = shift;
    my @out_data        = ();
    my $extraction_cnt  = 0;
    
    # 入力(リスト名 or ファイル名)
    if ($in_name_check !~ /file:/) {
        # リスト指定
        $in_kbn = '';
        $in_name = '${main::'.$in_name_check.'};';
        if (! eval($in_name)) {
            # 変数無し
            print STDERR "Input variable($in_name_check) not found\n";
            exit 99;
        }
    } else {
        # ファイル指定
        $in_kbn = 'file';
        $in_name = substr $in_name_check, 5;
        if (!-e "$in_name") {
            # 入力ファイル無し
            print STDERR "Input file($in_name_check) not found\n";
            exit 99;
        } elsif (!-r "$in_name") {
            # 入力ファイルに読込み権限無し
            print STDERR "Input file($in_name_check) is not read authority\n";
            exit 99;
        }
    }
    # オブジェクト定義
    my $Job = {"in_kbn"          =>$in_kbn,                 # 入力区分（ファイルor変数）
               "in_name"         =>$in_name,                # 入力データ（ファイル名or変数名）
               "out_data"        =>\@out_data,              # 出力データ（配列）
               "extraction_cnt"  =>$extraction_cnt};        # 抽出回数
    bless $Job;
    return $Job;
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ ED(抽出実行コマンド)の定義 ＞＞                                                          #
#-------------------------------------------------------------------------------------------------#
sub ED{
    ###############################################################################################
    # $_[0]  = オブジェクト                                                                       #
    # $_[1～]= 抽出データ指示                                                                     #
    ###############################################################################################
    # 抽出データ指示                                                                              #
    #   行抽出                                                                                    #
    #     行番号指定  ：[!]L/行番号[/[範囲][/列抽出]]                                             #
    #     正規表現指定：[!]LR/抽出条件[/範囲][/列抽出]]                                           #
    #     ※条件以外の抽出は、先頭に"!"を付与                                                     #
    #   列抽出                                                                                    #
    #     列番号指定  ：[!]C/列番号[/範囲]                                                        #
    #     正規表現指定：[!]CR/抽出条件[/範囲]                                                     #
    #     ※条件以外の抽出は、先頭に"!"を付与                                                     #
    #   ユーザー抽出  ：［"[ALL/]パッケージ名::サブルーチン名"[, "ユーザー抽出条件", ･･･ ]］      #
    ###############################################################################################
    my $obj     = shift;
    my @in_data = ();
    
    ##############
    # 抽出前処理 #
    ##############
    # 抽出条件チェック
    my @extraction_cond_data     = &extraction_cond(@_);
    my @extraction_cond          = @{$extraction_cond_data[0]};
    my @extraction_cond_user     = @{$extraction_cond_data[1]};
    my @extraction_cond_user_all = @{$extraction_cond_data[2]};
    # 抽出対象データ取得、ファイルOPEN
    if ($obj->{extraction_cnt} == 0) {
        # 初回
        if ($obj->{in_kbn} eq '') {
            # リスト指定
            my $in_name_check  = (eval($obj->{in_name}));
            @in_data = split /[\n]/, "$in_name_check";
        } else {
            # ファイル指定
            if (!open (EXTRACTION_FILE, "< $obj->{in_name}")) {
                # 入力ファイルOPENエラー
                print STDERR "Input File($obj->{in_name}) cannot Open File\n";
                exit 99;
            }
            flock(EXTRACTION_FILE, 1);
        }
    } else {
        # ２回目以降
        $obj->{in_kbn} = '';
        @in_data = @{$obj->{out_data}};
    }
    # 入力データ有無チェック
    if ($obj->{in_kbn} eq '') {
        if ($#in_data < 0) {
            print STDERR "There are not the input data\n";
            exit 99;
        }
        unshift @in_data, '';
    }
    @{$obj->{out_data}} = ();
    
    ####################
    # 抽出条件設定処理 #
    ####################
    # 列番号抽出条件設定
    my @extraction_cond_c = &set_extraction_cond_c(99999, grep{${$_}[0] =~ 'C'}@extraction_cond);
    # 正規表現抽出抽出条件設定
    my @extraction_cond_lr = grep{${$_}[0] eq 'LR'}@extraction_cond;
    
    ############
    # 抽出処理 #
    ############
    my $line_now        = 0;
    my $line_last       = 0;
    my %line_pos        = (); $line_pos{1} = 0;
    my %extraction_data = ();
    my %user_return     = ();
    
    # 列抽出、正規表現抽出判定（行番号指定に変換）
    if ($obj->{in_kbn} eq '') {
        # リスト情報抽出
        for ($line_now=1; $line_now <= $#in_data and ($#extraction_cond_c >= 0 or $#extraction_cond_lr >= 0 or $#extraction_cond_user >= 0); $line_now++) {
            # 列番号による行抽出
            if ($#extraction_cond_c >= 0) {
                $extraction_data{$line_now} = &get_extraction_cond_c($in_data[$line_now], @extraction_cond_c);
            }
            # 正規表現による行抽出判定（行番号指定に変換）
            if ($#extraction_cond_lr >= 0) {
                push(@extraction_cond, (&get_extraction_cond_lr($in_data[$line_now], $line_now, @extraction_cond_lr)));
                &get_extraction_cond_lr2($in_data[$line_now], $line_now, @extraction_cond);
            }
            # ユーザーによる行抽出（ユーザー独自処理）
            if ($#extraction_cond_user >= 0) {
                my $user_return = &get_extraction_cond_user($in_data[$line_now], $line_now, @extraction_cond_user);
                if ($user_return =~ /^ARRAY\(.*\)/) {
                    $extraction_data{$line_now} = $user_return;
                }
            }
        }
        $line_last = $#in_data;
    } else {
        # ファイル情報抽出
        while (my $line_data = <EXTRACTION_FILE>){
            $line_now = $.;
            chop $line_data;
            $line_pos{$line_now + 1} = tell EXTRACTION_FILE;
            # 列番号による行抽出
            if ($#extraction_cond_c >= 0) {
                $extraction_data{$line_now} = &get_extraction_cond_c($line_data, @extraction_cond_c);
            }
            # 正規表現による行抽出判定（行番号指定に変換）
            if ($#extraction_cond_lr >= 0) {
                push(@extraction_cond, (&get_extraction_cond_lr($line_data, $line_now, @extraction_cond_lr)));
                &get_extraction_cond_lr2($line_data, $line_now, @extraction_cond);
            }
            # ユーザーによる行抽出（ユーザー独自処理）
            if ($#extraction_cond_user >= 0) {
                my $user_return = &get_extraction_cond_user($line_data, $line_now, @extraction_cond_user);
                if ($user_return =~ /^ARRAY\(.*\)/) {
                    $extraction_data{$line_now} = $user_return;
                }
            }
        }
        $line_last = $line_now;
    }
    # 終了位置が検出できなかった正規表現抽出（終了レコードを最終行に変換）
    &get_extraction_cond_lr3($line_last, @extraction_cond);
    # 行番号抽出条件設定（抽出範囲を実値＆肯定条件に変更）
    my @extraction_cond_l = &set_extraction_cond_l($line_last, @extraction_cond);
    
    # 行抽出（行番号指定＋正規表現指定(行番号変換後)）
    if ($#extraction_cond_l >= 0) {
        my $index_s = 0;
        my $index_e = 0;
        foreach my $extraction_line(@extraction_cond_l) {
            if ($index_e < ${$extraction_line}[3]) {
                if ($index_s < ${$extraction_line}[2]) {
                    $index_s = ${$extraction_line}[2];
                } else {
                    $index_s = $index_e + 1;
                }
                $index_e = ${$extraction_line}[3];
                for (my $index2=$index_s ; $index2 <= ${$extraction_line}[3]; $index2++) {
                    my $line_data = undef;
                    if ($obj->{in_kbn} eq '') {
                        $line_data = $in_data[$index2];
                    } else {
                        seek EXTRACTION_FILE, ($line_pos{$index2}), 0 or "$!($obj->{in_name})";
                        $line_data = <EXTRACTION_FILE>;
                        chop $line_data;
                    }
                    $extraction_data{$index2} = &get_extraction_cond_lc($line_data, [@extraction_cond_c], [(grep{${$_}[2] <= $index2 and ${$_}[3] >= $index2}@extraction_cond_l)], $extraction_data{$index2});
                }
            }
        }
    }
    # 全域に対する自由形式抽出（ユーザー独自処理）
    if ($#extraction_cond_user_all >= 0) {
        my %user_return_all = ();
        if ($obj->{in_kbn} eq '') {
            %user_return_all = &get_extraction_cond_user_all($obj->{in_kbn}, [@extraction_cond_user_all], $obj->{in_name}, @in_data);
        } else {
            %user_return_all = &get_extraction_cond_user_all($obj->{in_kbn}, [@extraction_cond_user_all], $obj->{in_name}, %line_pos);
        }
        foreach my $user_return_all_key(keys %user_return_all) {
            my $user_return = &get_extraction_cond_user2([$extraction_data{$user_return_all_key}], [$user_return_all{$user_return_all_key}]);
            $extraction_data{$user_return_all_key} = [$user_return];
        }
    }
    @in_data  = ();
    %line_pos = ();
    
    # 出力データ生成
    push(@{$obj->{out_data}}, &put_extraction_data(%extraction_data));
    %extraction_data = ();
    
    ##############
    # 抽出後処理 #
    ##############
    # ファイルCLOSE
    if ($obj->{in_kbn} eq 'file') {
        close(EXTRACTION_FILE);
    }
    # 抽出回数のカウウトUP
    $obj->{extraction_cnt}++;
    # 出力データを返却
    return @{$obj->{out_data}};
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ extraction_cond(抽出条件チェックコマンド)の定義 ＞＞                                     #
#-------------------------------------------------------------------------------------------------#
sub extraction_cond{
    ############################################
    # @_     = 抽出条件                        #
    ############################################
    my @out_cond          = ();
    my @out_cond_user     = ();
    my @out_cond_user_all = ();
    
    foreach (@_) {
        if (/^\!{0,1}[CLcl][Rr]*\//) {
            # 定型抽出
            my @in_cond = split /[\/]/, $_;
            my @in_kbn  = ();
            # 行or列
            if ((substr $in_cond[0], 0, 1) ne '!') {
                $in_kbn[0] = '';
                $in_kbn[1] = uc(substr $in_cond[0], 0);
            } else {
                $in_kbn[0] = substr $in_cond[0], 0, 1;
                $in_kbn[1] = uc(substr $in_cond[0], 1);
            }
            &extraction_cond_check($in_kbn[0], $in_kbn[1], $in_cond[1], $in_cond[2]);
            # 行内の列
            if ($in_cond[3] =~ /^\!{0,1}[Cc][Rr]*$/) {
                if ((substr $in_cond[3], 0, 1) ne '!') {
                    $in_kbn[2] = '';
                    $in_kbn[3] = uc(substr $in_cond[3], 0);
                } else {
                    $in_kbn[2] = substr $in_cond[3], 0, 1;
                    $in_kbn[3] = uc(substr $in_cond[3], 1);
                }
                &extraction_cond_check($in_kbn[2], $in_kbn[3], $in_cond[4], $in_cond[5]);
                push(@out_cond, ["$in_kbn[1]", "$in_kbn[0]", "$in_cond[1]", "$in_cond[2]", "$in_kbn[3]", "$in_kbn[2]", "$in_cond[4]", "$in_cond[5]"]);
            } elsif ($in_cond[3] eq "") {
                if ($in_kbn[1] ne "CR") {
                    push(@out_cond, ["$in_kbn[1]", "$in_kbn[0]", "$in_cond[1]", "$in_cond[2]", "", "", "", ""]);
                } else {
                    push(@out_cond, ["L", "", "1", "E", "$in_kbn[1]", "$in_kbn[0]", "$in_cond[1]", "$in_cond[2]"]);
                }
            } else {
                print STDERR "Extraction Division is an Error \($_\)\n";
                exit 99;
            }
        } elsif ($_ =~ /^ARRAY\(.*\)/) {
            # ユーザー抽出
            my $check_data = ${$_}[0];
            if ($check_data !~ /^ALL\/(.+)/) {
                push(@out_cond_user, [@{$_}]);
            } else {
                ${$_}[0] = $1;
                push(@out_cond_user_all, [@{$_}]);
            }
        } else {
            # 抽出区分誤り
            print STDERR "Extraction Division is an Error \($_\)\n";
            exit 99;
        }
    }
    return ([@out_cond],[@out_cond_user],[@out_cond_user_all]);
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ extraction_cond_check(定型抽出条件の記述チェックコマンド)の定義 ＞＞                     #
#-------------------------------------------------------------------------------------------------#
sub extraction_cond_check{
    ############################################
    # $_[0]  = 肯定否定区分                    #
    # $_[1]  = 抽出区分                        #
    # $_[2]  = 起点                            #
    # $_[3]  = 範囲                            #
    ############################################
    if ($_[0] ne '' and $_[0] ne '!') {
        print STDERR "Affirmation Negation Division is an Error \($_[0]\)\n";
        exit 99;
    }
    if ($_[1] eq 'L' and $_[2] ne 'E' and $_[2] ne 'e' and ($_[2] !~ /^\d+$/ or $_[2] == 0)) {
        print STDERR "Starting Point Number is an Error \($_[2]\)\n";
        exit 99;
    }
    if ($_[1] eq 'C' and ($_[2] !~ /^\d+$/ or $_[2] == 0)) {
        print STDERR "Starting Point Number is an Error \($_[2]\)\n";
        exit 99;
    }
    if ($_[1] eq 'LR' or $_[1] eq 'CR') {
        if ($_[2] eq '') {
            print STDERR "Regular Expression Character string is not Found\n";
            exit 99;
        }
        if ($_[1] eq 'LR' and (($_[3] =~ /^\+\d+/ and ($_[3] !~ /^\+\d+$/ or $_[3] == 0)) or ($_[3] =~ /^-\d+$/ and $_[3] == 0))) {
            print STDERR "1End Range Number is an Error \($_[3]\)\n";
            exit 99;
        }
        if ($_[1] eq 'CR' and $_[3] =~ /^\+\d+/ and ($_[3] !~ /^\+\d+$/ or $_[3] == 0)) {
            print STDERR "2End Range Number is an Error \($_[3]\)\n";
            exit 99;
        }
    }
    if ($_[1] eq 'L') {
        if ($_[3] eq '' or ($_[3] =~ /^\d+$/ and $_[3] > 0) or ($_[3] =~ /^[\+-]\d+$/ and $_[3] != 0) or $_[3] eq 'E' or $_[3] eq 'e') {
        } else {
           print STDERR "End Range Number is an Error \($_[3]\)\n";
           exit 99;
        }
    }
    if ($_[1] eq 'C') {
        if ($_[3] eq '' or ($_[3] =~ /^\d+$/ and $_[3] > 0 and $_[3] <= 99999) or ($_[3] =~ /^[\+-]\d+$/ and $_[3] != 0) or $_[3] eq 'E' or $_[3] eq 'e') {
        } else {
            print STDERR "End Range Number is an Error \($_[3]\)\n";
            exit 99;
        }
    }
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ set_extraction_cond_c(列番号指定による列抽出条件設定コマンド)の定義 ＞＞                 #
#-------------------------------------------------------------------------------------------------#
sub set_extraction_cond_c{
    ##############################################
    # $_[0]    = 列数                            #
    # @_       = 抽出条件(列)                    #
    ##############################################
    my $col_max  = shift;
    my @out_data = ();
    
    foreach (@_) {
        my $col_start = undef;
        my $col_end   = undef;
        my $add_index = undef;
        if (${$_}[0] eq 'C') {
            $add_index = 0;
        } else {
            $add_index = 4;
        }
        if (${$_}[3 + $add_index] eq 'E' or ${$_}[3 + $add_index] eq 'e') {
            ${$_}[3 + $add_index] = $col_max;
        }
        if (${$_}[3 + $add_index] ne '') {
            my $extraction_range_kbn = substr ${$_}[3 + $add_index], 0, 1;
            if ($extraction_range_kbn eq '-') {
                $col_start = ${$_}[2 + $add_index] + ${$_}[3 + $add_index];
                if ($col_start < 1) {
                    $col_start = 1;
                }
                $col_end   = ${$_}[2 + $add_index];
            } elsif ($extraction_range_kbn eq '+') {
                $col_start = ${$_}[2 + $add_index];
                $col_end   = ${$_}[2 + $add_index] + ${$_}[3 + $add_index];
            } elsif (${$_}[2 + $add_index] > ${$_}[3 + $add_index]) {
                $col_start = ${$_}[3 + $add_index];
                $col_end   = ${$_}[2 + $add_index];
            } else {
                $col_start = ${$_}[2 + $add_index];
                $col_end   = ${$_}[3 + $add_index];
            }
        } else {
            $col_start = ${$_}[2 + $add_index];
            $col_end   = ${$_}[2 + $add_index];
        }
        if (${$_}[1 + $add_index] eq '') {
            # 範囲内を抽出
            for (my $index2=$col_start; $index2 <= $col_end and $index2 <= $col_max; $index2++) {
                $out_data[$index2] = '1';
            }
        } else {
            # 範囲外を抽出
            for (my $index2=1; $index2 <= $col_max; $index2++) {
                if ($col_start > $index2 or $col_end < $index2) {
                    $out_data[$index2] = '1';
                }
            }
        }
    }
    return @out_data;
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ set_extraction_cond_l(行番号指定による行抽出条件設定コマンド)の定義 ＞＞                 #
#-------------------------------------------------------------------------------------------------#
sub set_extraction_cond_l{
    ##############################################
    # $_[0]    = 抽出対象データ数                #
    # @_       = 抽出条件(行(行番号指定))        #
    ##############################################
    my $last_line = shift;
    my @out_data  = ();
    
    foreach (grep{${$_}[0] eq 'L'}@_) {
        my $start_line = undef;
        my $end_line   = undef;
        if (${$_}[2] eq 'E' or ${$_}[2] eq 'e') {
             ${$_}[2] = $last_line;
        }
        if (${$_}[3] eq 'E' or ${$_}[3] eq 'e') {
            ${$_}[3] = $last_line;
        }
        if (${$_}[3] =~ /^\d+$/) {
            if (${$_}[2] > ${$_}[3]) {
                $start_line = ${$_}[3];
                $end_line   = ${$_}[2];
            } else {
                $start_line = ${$_}[2];
                $end_line   = ${$_}[3];
            }
        } elsif (${$_}[3] eq '') {
            $start_line = ${$_}[2];
            $end_line   = ${$_}[2];
        } elsif (${$_}[3] =~ /^-\d+$/) {
            $start_line = ${$_}[2] + ${$_}[3];
            if ($start_line < 1) {
                $start_line = 1;
            }
            $end_line   = ${$_}[2];
        } elsif (${$_}[3] =~ /^\+\d+$/) {
            $start_line = ${$_}[2];
            $end_line   = ${$_}[2] + ${$_}[3];
        } else {
            $start_line = ${$_}[2];
            $end_line   = ${$_}[3];
        }
        if ($end_line > $last_line) {
            $end_line = $last_line;
        }
        if (${$_}[1] eq '') {
            # 範囲内を抽出
            push(@out_data, ["${$_}[0]", "", "$start_line", "$end_line", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
        } else {
            # 範囲外を抽出
            if ($start_line > 1) {
                push(@out_data, ["${$_}[0]", "", "1", ($start_line - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
            }
            if ($end_line < $last_line) {
                push(@out_data, ["${$_}[0]", "", ($end_line + 1), "$last_line", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
            }
        }
    }
    return (sort {${$a}[2] <=> ${$b}[2]} @out_data);
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_c(列番号指定による列抽出コマンド)の定義 ＞＞                         #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_c{
    ##############################################
    # $_[0]    = 行データ                        #
    # @_       = 抽出条件(列(列番号指定))        #
    ##############################################
    my $line_data    = shift;
    my @column_datas = split /\s+\,*\s*|\,+\s*/, $line_data; unshift @column_datas, '';
    my $out_data     = undef;
    
    for (my $index1=1 ; $index1 <= $#column_datas; $index1++) {
        if ($_[$index1] eq '1') {
            $out_data .= " ".$column_datas[$index1];
        }
    }
    if ($out_data =~ /^\s(.*)/) {
        $out_data = $1;
    }
    return $out_data;
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_lr(正規表現指定による行抽出の起点行検出コマンド)の定義 ＞＞          #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_lr{
    ############################################
    # $_[0]  = 行データ                        #
    # $_[1]  = 行番号                          #
    # @_     = 抽出条件(行(正規表現指定))      #
    ############################################
    my $line_data = shift;
    my $line_no   = shift;
    my @add_cond  = ();
    
    foreach (grep{${$_}[0] eq 'LR' and $line_data =~ /${$_}[2]/}@_) {
        if (${$_}[3] =~ /^[\+-]\d+$/ or ${$_}[3] eq '') {
            push(@add_cond, ['L', "${$_}[1]", "$line_no", "${$_}[3]", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
        } else {
            push(@add_cond, ['r', "${$_}[1]", "$line_no", "${$_}[3]", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
        }
    }
    return @add_cond;
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_lr2(正規表現指定による行抽出の終了行検出コマンド)の定義 ＞＞         #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_lr2{
    ##############################################
    # $_[0]   = 行データ                         #
    # $_[1]   = 行番号                           #
    # @_      = 抽出条件(行(正規表現指定の範囲)) #
    ##############################################
    my $line_data = shift;
    my $line_no   = shift;
    
    foreach (grep{${$_}[0] eq 'r' and $line_data =~ /${$_}[3]/}@_) {
        ${$_}[0] = 'L';
        ${$_}[3] = $line_no;
    }
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_lr3(正規表現指定による行抽出の終了行強制設定コマンド)の定義 ＞＞     #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_lr3{
    ##############################################
    # $_[0]   = 行番号                           #
    # @_      = 抽出条件(行(正規表現指定の範囲)) #
    ##############################################
    my $line_last = shift;
    
    foreach (grep{${$_}[0] eq 'r' }@_) {
        ${$_}[0] = 'L';
        ${$_}[3] = $line_last;
    }
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_lc(行内抽出対象データの抽出コマンド)の定義 ＞＞                      #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_lc{
    ##############################################
    # $_[0]   = 行データ                         #
    # @{$_[1]}= 抽出条件(列(正規表現指定))       #
    # @{$_[2]}= 抽出条件(処理行)                 #
    # $_[3]   = 抽出結果(処理行)                 #
    ##############################################
    my $line_data  = $_[0];
    my @line_datas = split /\s+\,*\s*|\,+\s*/, $line_data; unshift @line_datas, '';
    my @cond_c     = @{$_[1]};
    my @cond_line  = grep{${$_}[4] eq ''}@{$_[2]};
    
    if ($_[3] =~ /^ARRAY\(.*\)/ and ${$_[3]}[0] !~ /^ARRAY\(.*\)/) {
        # ユーザー抽出（行抽出）
        return ${$_[3]}[0];
    } elsif ($#cond_line >= 0) {
        # 定型抽出（行抽出）
        if ($_[3] =~ /^ARRAY\(.*\)/) {
            # ユーザー抽出（列抽出）
            for (my $index1=0; $index1 <= $#{${$_[3]}[0]}; $index1++) {
                if (${${$_[3]}[0]}[$index1] ne '') {
                    if ($#line_datas > $index1) {
                        if (${${$_[3]}[0]}[$index1] ne $line_datas[$index1 + 1]) {
                            my $check_data_front = undef;
                            for (my $index2=1; $index2 <= $index1; $index2++) {
                                $check_data_front .= '.*(\s+\,*\s*|\,+\s*)';
                            }
                            $check_data_front .= '.*';
                            $line_data =~ s/^(${check_data_front})$line_datas[$index1 + 1]/$1${${$_[3]}[0]}[$index1]/;
                        }
                    } else {
                        $line_data .= " ".${${$_[3]}[0]}[$index1];
                    }
                }
            }
        }
        return $line_data;
    } else {
        # 定型抽出（列番号による列抽出）
        my @cond_lc = &set_extraction_cond_c($#line_datas, grep{${$_}[4] eq 'C'}@{$_[2]});
        # 定型抽出（正規表現による列抽出）
        foreach (grep{${$_}[4] eq 'CR'}@{$_[2]}) {
            my $check_key1 = '';
            ${$_}[6] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
            ${$_}[6] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
            ${$_}[6] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
            ${$_}[6] =~  s/^(\[.*),(.*\]\*)/$1$2/;
            if (${$_}[6] !~ /^\^|^\\s|^\\,|^,|^\[.*\\s|^\[.*\\,|^\[.*,/) {
                $check_key1 .= '[^\s\,]*';
            }
            $check_key1 .= ${$_}[6];
            if (${$_}[6] !~ /\$$|\\s\*$|\\s\+$|\\s$|,\*$|,\+$|,$|\[.*\\s.*\]\*$|\[.*\\s.*\]\+$|\[.*,.*\]\*$|\[.*,.*\]\+$/) {
                $check_key1 .= '[^\s\,]*';
            }
            my $check_key2 = '';
          ##if (${$_}[7] ne '' and ${$_}[7] !~ /^[\+-]\d+$/) {
            if (${$_}[7] ne '' and ${$_}[7] !~ /^\+\d+$/) {
                ${$_}[7] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
                ${$_}[7] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
                ${$_}[7] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
                ${$_}[7] =~  s/^(\[.*),(.*\]\*)/$1$2/;
                if (${$_}[7] !~ /^\^|^\\s|^\\,|^,|^\[.*\\s|^\[.*\\,|^\[.*,/) {
                    $check_key2 .= '[^\s\,]*';
                }
                $check_key2 .= ${$_}[7];
                if (${$_}[7] !~ /\$$|\\s\*$|\\s\+$|\\s$|,\*$|,\+$|,$|\[.*\\s.*\]\*$|\[.*\\s.*\]\+$|\[.*,.*\]\*$|\[.*,.*\]\+$/) {
                    $check_key2 .= '[^\s\,]*';
                }
            }
            my @cond_c_new = ();
            my $start_index = 0;
            my $end_index = 0;
            while ($line_data =~ /($check_key1)(.*)/) {
                my $next_data = $2;
                my @split_out1 = split /($check_key1)/, $line_data, 3;
                my $split_out1_add = 0;
                if ($split_out1[0] =~ /^\s+\,*\s*$|^\,+\s*$/) {
                } else {
                    if ($split_out1[0] =~ /^\s+\,*\s*|^\,+\s*/ and $split_out1[0] =~ /\s+\,*\s*$|\,+\s*$/) {
                        $split_out1_add--;
                    }
                }
                $start_index = $start_index + (split /\s+\,*\s*|\,+\s*/, $split_out1[0]) + $split_out1_add + 1;
                my $end_index2 = $start_index + (split /\s+\,*\s*|\,+\s*/, $split_out1[1]) - 1;
                if (${$_}[7] =~ /^\+(\d+)$/) {
                    $end_index = $start_index + (split /\s+\,*\s*|\,+\s*/, $split_out1[1]) - 1 + ${$_}[7];
              ##} elsif (${$_}[7] =~ /^-(\d+)$/) {
              ##    $end_index = $start_index;
              ##    $start_index = $end_index2 + (split /\s+\,*\s*|\,+\s*/, $split_out1[1]) - 1 + ${$_}[7];
              ##    if ($start_index < 1) {
              ##        $start_index = 1;
              ##    }
                } elsif (${$_}[7] ne '') {
                    if ($next_data =~ /($check_key2)(.*)/) {
                        my $back_data = $2;
                        my @split_out2 = split /($check_key2)/, $next_data, 3;
                        $end_index = $#line_datas - (split /\s+\,*\s*|\,+\s*/, $back_data) + 1;
                    } else {
                        $end_index = $#line_datas;
                    }
                } else {
                    $end_index = $start_index + (split /\s+\,*\s*|\,+\s*/, $split_out1[1]) - 1;
                }
                for (my $index3=$start_index; $index3 <= $end_index; $index3++) {
                    $cond_c_new[$index3] = '1';
                }
                $start_index = $end_index2;
                $line_data = $next_data;
            }
            for (my $index2=1; $index2 <= $#line_datas; $index2++) {
                if ((${$_}[5] eq '' and $cond_c_new[$index2] eq '1') or (${$_}[5] ne '' and $cond_c_new[$index2] eq '')) {
                    $cond_lc[$index2] = '1';
                }
            }
        }
        my @mid_data = ();
        for (my $index1=1; $index1 <= $#line_datas; $index1++) {
            if ($cond_c[$index1] eq '1' or $cond_lc[$index1] eq '1') {
                $mid_data[$index1] = $line_datas[$index1];
            }
        }
        # ユーザー抽出（列抽出）
        if ($_[3] =~ /^ARRAY\(.*\)/) {
            for (my $index1=0; $index1 <= $#{${$_[3]}[0]}; $index1++) {
                if (${${$_[3]}[0]}[$index1] ne '') {
                    $mid_data[$index1 + 1] = ${${$_[3]}[0]}[$index1];
                }
            }
        }
        # 返却値設定
        my $out_data = undef;
        for (my $index1=1; $index1 <= $#mid_data; $index1++) {
            if ($mid_data[$index1] ne '') {
                $out_data .= " ".$mid_data[$index1];
            }
        }
        if ($out_data =~ /^\s(.*)/) {
            $out_data = $1;
        }
        return $out_data;
    }
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_user(ユーザー抽出コマンド)の定義 ＞＞                                #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_user{
    ##############################################
    # $_[0]   = 行データ                         #
    # $_[1]   = 行番号                           #
    # @_      = 抽出条件(ユーザー(行単位処理))   #
    ##############################################
    my $line_data = shift;
    my $line_no   = shift;
    my $out_data  = undef;
    
    foreach (@_) {
        # ユーザーサブルーチン呼出し
        my $user_sub = '&'.${$_}[0].'(';
        $user_sub .= "'$line_data',\"$line_no\"";
        for (my $index1=1 ; $index1 <= $#{$_}; $index1++) {
            $user_sub .= ', "'.${$_}[$index1].'"';
        }
        $user_sub .= ');';
        my $user_sub_return = eval($user_sub);
        $out_data = &get_extraction_cond_user2([$out_data], [$user_sub_return]);
    }
    if ($out_data ne '') {
        return [$out_data];
    } else {
        return;
    }
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_user2(ユーザー抽出コマンド)の定義 ＞＞                               #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_user2{
    ##############################################
    # $_[0]   = 抽出条件（行単位処理）           #
    # $_[1]   = 抽出結果（ユーザー(全域処理)）   #
    ##############################################
    my $out_data        = ${$_[0]}[0];
    my $user_sub_return = ${$_[1]}[0];
    
    if ($out_data eq '' or ($user_sub_return ne '' and $user_sub_return !~ /^ARRAY\(.*\)/)) {
        # ユーザーによる行抽出
        $out_data = $user_sub_return;
    } elsif ($out_data =~ /^ARRAY\(.*\)/) {
        # ユーザーによる列抽出
        for (my $index2=1 ; $index2 <= $#{$user_sub_return}; $index2++) {
            if (${$user_sub_return}[$index2] ne '') {
                ${$out_data}[$index2] = ${$user_sub_return}[$index2];
            }
        }
    } else {
        # ユーザーによる列抽出＋定型行抽出
        for (my $index2=0; $index2 <= $#{$user_sub_return}; $index2++) {
            if (${$user_sub_return}[$index2] ne '' and ${$user_sub_return}[$index2] ne ${$out_data}[$index2]) {
                my $out_data_front = undef;
                for (my $index3=1; $index3 <= $index2; $index3++) {
                    $out_data_front .= '.*(\s+\,*\s*|\,+\s*)';
                }
                $out_data_front .= '.*';
                $out_data =~ s/^(${out_data_front})${$out_data}[$index2]/$1${$user_sub_return}[$index2]/;
            }
        }
    }
    return $out_data;
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ get_extraction_cond_user_all(ユーザー抽出(ALL)コマンド)の定義 ＞＞                       #
#-------------------------------------------------------------------------------------------------#
sub get_extraction_cond_user_all{
    #####################################################
    # $_[0]   = 処理区分                                #
    # @{$_[1]}= 抽出条件（ユーザー(ALL)）               #
    # ファイル入力時                                    #
    #   $_[2]   = ファイル名                            #
    #   %_      = 入力データレコード位置                #
    # リスト入力時                                      #
    #   @_      = 入力データ                            #
    #####################################################
    my $in_kbn     = shift;
    my @cond_users = @{$_[0]}; shift;
    my $in_name    = shift;
    my %out_data   = ();
    
    foreach my $cond_user(@cond_users) {
        # ユーザーサブルーチン呼出し
        my $user_sub = '&'.${$cond_user}[0].'(';
        $user_sub .= "'$in_kbn'";
        if ($in_kbn eq '') {
            $user_sub .= ",".'[@_]';
        } else {
            $user_sub .= ",'$in_name',".'[@_]';
        }
        for (my $index1=1 ; $index1 <= $#{$cond_user}; $index1++) {
            $user_sub .= ', "'.${$cond_user}[$index1].'"';
        }
        $user_sub .= ');';
        my %user_sub_return = eval($user_sub);
        foreach my $user_sub_return_key(keys %user_sub_return) {
            $out_data{$user_sub_return_key} = &get_extraction_cond_user2([$out_data{$user_sub_return_key}], [$user_sub_return{$user_sub_return_key}]);
        }
    }
    return %out_data;
}
#-------------------------------------------------------------------------------------------------#
#   ＜＜ put_extraction_data(出力データ生成コマンド)の定義 ＞＞                                   #
#-------------------------------------------------------------------------------------------------#
sub put_extraction_data{
    ##############################################
    # @_      = 抽出結果                         #
    ##############################################
    my %in_data      = @_;
    my @out_data     = ();
    my @in_data_keys = sort{ $a <=> $b }(keys %in_data);
    
    foreach (@in_data_keys) {
        if ($in_data{$_} =~ /^ARRAY\(.*\)/) {
            if (${$in_data{$_}}[0] !~ /^ARRAY\(.*\)/) {
                push(@out_data, ${$in_data{$_}}[0]);
            } else {
                my $col_datas = undef;
                foreach my $col_data(@{${$in_data{$_}}[0]}) {
                    if ($col_data ne '') {
                        $col_datas .= " ".$col_data;
                    }
                }
                if ($col_datas =~ /^\s(.*)/) {
                    $col_datas = $1;
                }
                push(@out_data, $col_datas);
            }
        } elsif ($in_data{$_} ne '') {
            push(@out_data, $in_data{$_});
        }
    }
    return @out_data;
}
1;
