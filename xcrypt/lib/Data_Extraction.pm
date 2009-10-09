package Data_Extraction;
use Exporter;
@ISA    = (Exporter);
@EXPORT = qw(EF);
use strict;
use threads;
use threads::shared;
#use warnings;
use File::Basename;
use Cwd;

my @pipe_data1    : shared;
my @pipe_data2    : shared;
my @pipe_data3    : shared;
my @pipe_data4    : shared;
my @pipe_data5    : shared;
my @pipe_data6    : shared;
my @pipe_data7    : shared;
my @pipe_data8    : shared;
my @pipe_data9    : shared;
my @pipe_data10   : shared;
my $pipe_buf_plus = 100;     # 各抽出をつなぐ最大pipeバッファ数
                             # ユーザseekバッファ数が指定されている場合、実際の最大pipeバッファ数は（ユーザseekバッファ数＋pipeバッファ数）

###################################################################################################
#   ＜＜ 抽出対象ファイル定義 ＞＞                                                                #
###################################################################################################
sub EF {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 入力データ情報                                                          #
    #                 ・変数指定    ）変数名                                                  #
    #                 ・ファイル指定）file:ファイル名                                         #
    #         $_[1] = ユーザseekバッファ数                                                    #
    # 処理 ： 入力データチェック、オブジェクト定義（抽出対象ファイル定義）                    #
    # 返却 ： オブジェクト                                                                    #
    #-----------------------------------------------------------------------------------------#
    my $cond_index    = 0;
    my @cond_data     = ();
    my @cond_buf      = ();
    my @cond_buf_max  = ();
    my @seek_buf      = ();
    my $seek_buf_max  = 0;
    my $seek_kbn      = '';
    my $seek_index    = 0;
    my @seek_num      = ();
    my $get_kbn       = '';
    my $get_index     = 0;
    my @get_num       = ();
    my $input         = '';
    my @mid           = ();
    my $output        = '';
    my $output_kbn    = '';
    my $output_index  = 0;
    @pipe_data1       = ();
    @pipe_data2       = ();
    @pipe_data3       = ();
    @pipe_data4       = ();
    @pipe_data5       = ();
    @pipe_data6       = ();
    @pipe_data7       = ();
    @pipe_data8       = ();
    @pipe_data9       = ();
    @pipe_data10      = ();
    
    # 入力データチェック
    my @in_data = &check_in_data($_[0]);
    # ユーザseekバッファ数チェック
    $seek_buf_max = &check_seek_max($_[1]);
    
    # オブジェクト定義
    my $Job = {
             # 入力情報
               "in_kbn"        =>$in_data[0],                 # 入力区分（ファイルor変数）
               "in_name"       =>$in_data[1],                 # 入力データ名（ファイル名or変数名）
             # 抽出条件
               "cond_index"    =>$cond_index,                 # 抽出条件index
               "cond_data"     =>\@cond_data,                 # 抽出条件
             # バッファ
               "cond_buf"      =>\@cond_buf,                  # 抽出バッファ
               "cond_buf_max"  =>\@cond_buf_max,              # 抽出バッファ数
               "seek_buf"      =>\@seek_buf,                  # seekバッファ
               "seek_buf_max"  =>$seek_buf_max,               # seekバッファ数
               "seek_kbn"      =>$seek_kbn,                   # seek区分（seek/cond/input/org）
               "seek_index"    =>$seek_index,                 # seekバッファindex（バッファの配列index）
               "seek_num"      =>\@seek_num,                  # seek行情報（オリジナル行番号、バイト位置、入力行番号）
               "get_kbn"       =>$get_kbn,                    # get区分（seek/cond/input/org）
               "get_index"     =>$get_index,                  # getバッファindex（バッファの配列index）
               "get_num"       =>\@get_num,                   # get行情報（オリジナル行番号、バイト位置、入力行番号）
             # pipe情報
               "input"         =>$input,                      # 入力データ（先行ED抽出結果）
               "output"        =>$output,                     # 出力データ（抽出結果）
             # 出力情報
               "mid"           =>\@mid,                       # ユーザ抽出データ（先読み部分）
               "output_kbn"    =>$output_kbn,                 # 出力区分
               "output_index"  =>$output_index};              # 出力データindex
    bless $Job;
    return $Job;
}
###################################################################################################
#   ＜＜ 入力データチェック ＞＞                                                                  #
###################################################################################################
sub check_in_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 入力データ情報                                                          #
    # 処理 ： 変数指定    ）変数存在チェック、データ存在チェック                              #
    #         ファイル指定）ファイル存在チェック、読込み権限チェック、データ存在チェック      #
    # 返却 ： 入力区分、入力データ名                                                          #
    #-----------------------------------------------------------------------------------------#
    my @in_data = ();
    
    if ($_[0] !~ /file:/) {
        # 変数指定
        $in_data[0] = '';
        $in_data[1] = '${main::'.$_[0].'}';
        if (! defined eval($in_data[1])) {
            # 変数なし
            print STDERR "Input variable($_[0]) not found\n";
            exit 99;
        }
        if (eval($in_data[1]) eq '') {
            # 変数に値なし
            print STDERR "There are not the input data($_[0])\n";
            exit 99;
        }
    } else {
        # ファイル指定
        $in_data[0] = 'file';
        $in_data[1] = substr $_[0], 5;
        if (!-e "$in_data[1]") {
            # ファイルなし
            print STDERR "Input file($_[0]) not found\n";
            exit 99;
        } elsif (!-r "$in_data[1]") {
            # ファイルに読込み権限なし
            print STDERR "Input file($_[0]) is not read authority\n";
            exit 99;
        }
        my @in_file_information = stat $in_data[1];
        if ($in_file_information[7] == 0) {
            # ファイルが空
            print STDERR "There are not the input data($_[0])\n";
            exit 99;
        }
    }
    return @in_data;
}
###################################################################################################
#   ＜＜ ユーザseekバッファ数チェック ＞＞                                                        #
###################################################################################################
sub check_seek_max {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = ユーザseekバッファ数                                                    #
    # 処理 ： 数値チェック                                                                    #
    # 返却 ： ユーザseekバッファ数                                                            #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] eq "") {
        return 0;
    } elsif ($_[0] =~ /^\d+$/) {
        return $_[0];
    } else {
        # ユーザseekバッファ数に誤り
        print STDERR "Greatest Seek Buffers Number is an Error($_[0])\n";
        exit 99;
    }
}
###################################################################################################
#   ＜＜ 抽出条件定義 ＞＞                                                                        #
###################################################################################################
sub ED {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = オブジェクト                                                           #
    #         $_[1～]= 抽出データ指示                                                         #
    # 処理 ： 抽出条件チェック、抽出条件設定                                                  #
    #-----------------------------------------------------------------------------------------#
    # 抽出データ指示                                                                          #
    #   行抽出                                                                                #
    #     行番号指定  ：[!]L/行番号[/[範囲][/列抽出]]                                         #
    #     正規表現指定：[!]LR/抽出条件[/範囲][/列抽出]]                                       #
    #     ※条件以外の抽出は、先頭に"!"を付与                                                 #
    #   列抽出                                                                                #
    #     列番号指定  ：[!]C/列番号[/範囲]                                                    #
    #     正規表現指定：[!]CR/抽出条件[/範囲]                                                 #
    #     ※条件以外の抽出は、先頭に"!"を付与                                                 #
    #   ユーザー抽出  ：［"パッケージ名::サブルーチン名"[, "ユーザー抽出条件", ･･･ ]］        #
    #                   ※大外の［］は、配列定義を意味する                                    #
    #-----------------------------------------------------------------------------------------#
    my $cond_buf_max = 0;
    
    # 抽出条件チェック
    my @cond_data = &check_extraction_cond(@_);
    if ($#cond_data >  9) {
        # 抽出条件が多い
        print STDERR "Extraction Conditions Exceed a Maximum Number \($cond_data[10]\)\n";
        exit 99;
    }
    foreach (grep{${$_}[0] =~ 'L' and ${$_}[3] =~ /^-\d+$/}@cond_data) {
         if ($cond_buf_max > ${$_}[3]) {
             $cond_buf_max = ${$_}[3];
         }
    }
    
    # 抽出条件設定
    push(@{$_[0]->{cond_data}}, [@cond_data]);
    push(@{$_[0]->{cond_buf_max}}, ($cond_buf_max * -1));
}
###################################################################################################
#   ＜＜ 抽出条件チェック ＞＞                                                                    #
###################################################################################################
sub check_extraction_cond {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = オブジェクト                                                           #
    #         $_[1～]= 抽出データ指示                                                         #
    # 処理 ： 抽出条件チェック、定型抽出条件の記述チェック                                    #
    #-----------------------------------------------------------------------------------------#
    my $obj         = shift;
    my @cond_data   = ();
    
    foreach (@_) {
        if (/^\!{0,1}[CLcl][Rr]*\//) {
            # 定型抽出
            my @in_cond = split /[\/]/, $_;
            my @in_kbn  = ();
            
            if ((substr $in_cond[0], 0, 1) ne '!') {
                $in_kbn[0] = '';
                $in_kbn[1] = uc(substr $in_cond[0], 0);
            } else {
                $in_kbn[0] = substr $in_cond[0], 0, 1;
                $in_kbn[1] = uc(substr $in_cond[0], 1);
            }
            &check_fixed_form_cond($obj, $in_kbn[0], $in_kbn[1], $in_cond[1], $in_cond[2], $in_cond[2]);
            if ($in_kbn[1] eq "LR" and $in_kbn[0] ne "") {
                $in_kbn[4] = "0";
            } else {
                $in_kbn[4] = "";
            }
            
            if ($in_cond[3] eq "") {
                push(@cond_data, ["$in_kbn[1]", "$in_kbn[0]", "$in_cond[1]", "$in_cond[2]", "", "", "", "", "$in_kbn[4]"]);
            } elsif ($in_cond[3] =~ /^\!{0,1}[Cc][Rr]*$/) {
                if ((substr $in_cond[3], 0, 1) ne '!') {
                    $in_kbn[2] = '';
                    $in_kbn[3] = uc(substr $in_cond[3], 0);
                } else {
                    $in_kbn[2] = substr $in_cond[3], 0, 1;
                    $in_kbn[3] = uc(substr $in_cond[3], 1);
                }
                &check_fixed_form_cond($obj, $in_kbn[2], $in_kbn[3], $in_cond[4], $in_cond[5]);
                push(@cond_data, ["$in_kbn[1]", "$in_kbn[0]", "$in_cond[1]", "$in_cond[2]", "$in_kbn[3]", "$in_kbn[2]", "$in_cond[4]", "$in_cond[5]", "$in_kbn[4]"]);
            } else {
                # 抽出区分誤り
                print STDERR "Extraction Division is an Error \($_\)\n";
                exit 99;
            }
        } elsif ($_ =~ /^ARRAY\(.*\)/) {
            my @in_cond_user = @{$_};
            # ユーザー抽出
            if ($in_cond_user[0] =~ /\:\:/) {
                push(@cond_data, ["USER", @in_cond_user]);
            } else {
                # 抽出区分誤り
                print STDERR "Extraction Division is an Error \(@{$_}\)\n";
                exit 99;
            }
        } else {
            # 抽出区分誤り
            print STDERR "Extraction Division is an Error \($_\)\n";
            exit 99;
        }
    }
    return @cond_data;
}
###################################################################################################
#   ＜＜ 定型抽出条件の記述チェック ＞＞                                                          #
###################################################################################################
sub check_fixed_form_cond {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 肯定否定区分                                                            #
    #         $_[2] = 抽出区分                                                                #
    #         $_[3] = 起点                                                                    #
    #         $_[4] = 範囲                                                                    #
    # 処理 ： 定型抽出条件の記述チェック                                                      #
    #-----------------------------------------------------------------------------------------#
    if ($_[1] ne '' and $_[1] ne '!') {
        # 肯定否定区分誤り
        print STDERR "Affirmation Negation Division is an Error \($_[1]\)\n";
        exit 99;
    }
    if (($_[2] eq 'L' or $_[2] eq 'C') and ($_[3] eq 'E' or $_[3] eq 'e')) {
        $_[3] = 'E';
    } elsif (($_[2] eq 'L' and ($_[3] !~ /^\d+$/ or $_[3] == 0)) or
             ($_[2] eq 'C' and ($_[3] !~ /^\d+$/ or $_[3] <= 0))) {
        # 起点番号誤り
        print STDERR "Starting Point Number is an Error \($_[3]\)\n";
        exit 99;
    }
    if ($_[2] =~ /R/ and $_[3] eq '') {
        # 起点正規表指定現無し
        print STDERR "Regular Expression Character string is not Found\n";
        exit 99;
    }
    if ($_[2] =~ /R/ and $_[4] =~ /^[\+-]\d+/ and ($_[4] !~ /^[\+-]\d+$/ or $_[4] == 0))  {
        # 抽出範囲誤り
        print STDERR "End Range Number is an Error \($_[4]\)\n";
        exit 99;
    }
    if ($_[2] eq 'L' or $_[2] eq 'C') {
        if ($_[4] eq '') {
        } elsif ($_[4] =~ /^\d+$/ and $_[4] > 0) {
            if ($_[3] eq 'E' or $_[3] > $_[4]) {
                my $temp_su = $_[3];
                $_[3] = $_[4];
                $_[4] = $temp_su;
            }
        } elsif ($_[4] =~ /^-\d+$/ and $_[4] != 0) {
            if ($_[3] ne 'E') {
                my $temp_su = $_[3];
                $_[3] = $_[3] + $_[4];
                $_[4] = $temp_su;
            }
        } elsif ($_[4] =~ /^\+\d+$/ and $_[4] != 0) {
            if ($_[3] ne 'E') {
                $_[4] = $_[3] + $_[4];
            }
        } elsif ($_[4] eq 'E' or $_[4] eq 'e') {
            $_[4] = 'E';
        } else {
            # 抽出範囲誤り
            print STDERR "End Range Number is an Error \($_[4]\)\n";
            exit 99;
        }
    }
}
###################################################################################################
#   ＜＜ 抽出実行 ＞＞                                                                            #
###################################################################################################
sub ER {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    # 処理 ： 行データ取得、EDコマンド抽出実行                                                #
    # 返却 ： 抽出結果                                                                        #
    #-----------------------------------------------------------------------------------------#
    my $obj      = shift;
    my @thread   = ();
    
    if ($obj->{in_kbn} eq 'file') {
        &in_file_open($obj->{in_name});
    }
    if ($#{$obj->{cond_data}} > -1) {$thread[0] = &existence_init($obj, \@pipe_data1)}
    if ($#{$obj->{cond_data}} >  0) {$thread[1] = &existence_watch($obj, 1, \@pipe_data1, \@pipe_data2)}
    if ($#{$obj->{cond_data}} >  1) {$thread[2] = &existence_watch($obj, 2, \@pipe_data2, \@pipe_data3)}
    if ($#{$obj->{cond_data}} >  2) {$thread[3] = &existence_watch($obj, 3, \@pipe_data3, \@pipe_data4)}
    if ($#{$obj->{cond_data}} >  3) {$thread[4] = &existence_watch($obj, 4, \@pipe_data4, \@pipe_data5)}
    if ($#{$obj->{cond_data}} >  4) {$thread[5] = &existence_watch($obj, 5, \@pipe_data5, \@pipe_data6)}
    if ($#{$obj->{cond_data}} >  5) {$thread[6] = &existence_watch($obj, 6, \@pipe_data6, \@pipe_data7)}
    if ($#{$obj->{cond_data}} >  6) {$thread[7] = &existence_watch($obj, 7, \@pipe_data7, \@pipe_data8)}
    if ($#{$obj->{cond_data}} >  7) {$thread[8] = &existence_watch($obj, 8, \@pipe_data8, \@pipe_data9)}
    if ($#{$obj->{cond_data}} >  8) {$thread[9] = &existence_watch($obj, 9, \@pipe_data9, \@pipe_data10)}
    
    $thread[0]->join;
    sleep(1);
    for (my $index=1; $index <= $#{$obj->{cond_data}}; $index++) {
        $thread[$index]->detach;
    }
    
    if ($obj->{in_kbn} eq 'file') {
        &in_file_close($obj->{in_name});
    }
    if ($#{$obj->{cond_data}} == 0) {return &extraction_result(@pipe_data1)}
    if ($#{$obj->{cond_data}} == 1) {return &extraction_result(@pipe_data2)}
    if ($#{$obj->{cond_data}} == 2) {return &extraction_result(@pipe_data3)}
    if ($#{$obj->{cond_data}} == 3) {return &extraction_result(@pipe_data4)}
    if ($#{$obj->{cond_data}} == 4) {return &extraction_result(@pipe_data5)}
    if ($#{$obj->{cond_data}} == 5) {return &extraction_result(@pipe_data6)}
    if ($#{$obj->{cond_data}} == 6) {return &extraction_result(@pipe_data7)}
    if ($#{$obj->{cond_data}} == 7) {return &extraction_result(@pipe_data8)}
    if ($#{$obj->{cond_data}} == 8) {return &extraction_result(@pipe_data9)}
    if ($#{$obj->{cond_data}} == 9) {return &extraction_result(@pipe_data10)}
    return ();
}
###################################################################################################
sub existence_init {
    my ($obj, $output) = @_;
    my @input    = ();
    my @line     = ();
    my $line_in  = 0;
    my @seek     = ();
    
    threads->new(sub {
        $obj->{input}      = \@input;
        $obj->{output}     = $output;
        push(@line, (&get_line_data($obj, $line_in)));
        push(@seek, 0);
        push(@seek, (tell EXTRACTION_FILE));
        while ($line[0] ne 'Data_Extraction_END') {
            $line_in++;
            push(@line, (&get_line_data($obj, $line_in)));
            push(@seek, (tell EXTRACTION_FILE));
            my @result;
            if ($obj->{in_kbn} eq '') {
                @result = &check_existence($obj, [$line_in, "", $line_in, "", $line[0]], $line[1]);
            } else {
                @result = &check_existence($obj, [$line_in, $seek[0], $line_in, "", $line[0]], $line[1]);
            }
            &put_output($obj, \@result);
            shift(@line);
            shift(@seek);
            seek EXTRACTION_FILE, ($seek[1]), 0 or "$!($obj->{in_name})";
        }
        for (my $index=$#{$obj->{cond_buf}}; $index >= 0; $index--) {
            my @result = &get_existence_data($obj);
            &put_output($obj, \@result);
        }
        push(@{$output}, 'Data_Extraction_END');
    });
}
###################################################################################################
sub existence_watch {
    my ($obj, $cond_index, $input, $output) = @_;
    my $line_in  = 0;
    
    threads->new(sub {
        $obj->{cond_index} = $cond_index;
        $obj->{input}      = $input;
        $obj->{output}     = $output;
        while (1) {
            if ($#{$input} >= 1 and ($#{$input} > $obj->{seek_buf_max} or ${$input}[$#{$input}] eq 'Data_Extraction_END')) {
                my $input_data = shift(@{$input});
                $line_in++;
                if ($input_data =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                    my @result = &check_existence($obj, ["$1", "$2", "$line_in", "$4", "$5"], "${$input}[0]");
                    &put_output($obj, \@result);
                }
            }
            if (${$input}[0] eq 'Data_Extraction_END') {
                for (my $index=$#{$obj->{cond_buf}}; $index >= 0; $index--) {
                    my @result = &get_existence_data($obj);
                    &put_output($obj, \@result);
                }
                push(@{$output}, 'Data_Extraction_END');
                last;
            }
        }
    });
}
###################################################################################################
sub put_output {
    foreach (@{$_[1]}) {
        my $sleep_cnt = 0;
        $_[0]->{output_index}++;
        while ($#{$_[0]->{input}} >= ($_[0]->{seek_buf_max} + $pipe_buf_plus)) {
            $sleep_cnt++;
            if ($sleep_cnt > 10) {
                # 抽出範囲誤り
                print STDERR "Following extraction takes time. Therefore the output to the pipe buffer is not done.\n";
                exit 99;
            }
            sleep 1;
        }
        push(@{$_[0]->{output}}, "${$_}[0],${$_}[1],$_[0]->{output_index},${$_}[3],${$_}[4]");
    }
}
###################################################################################################
sub extraction_result {
    my @return_data = ();
    
    foreach (@_) {
        if ($_ =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($4 ne 'DEL') {
                push(@return_data, $5);
            }
        }
    }
    return @return_data;
}
###################################################################################################
sub check_existence {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行データ                                                                #
    # 処理 ： 定型抽出（行・列・ブロック抽出）、ユーザー抽出（ユーザー関数呼出し）            #
    # 返却 ： 抽出結果                                                                        #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $input_data, $next_line_data) = @_;
    my ($index_org, $seek, $index_now, $out_kbn, $line_data) = @{$input_data};
    
    if ($line_data ne 'Data_Extraction_END') {
        # 削除対象チェック
        if ($out_kbn eq 'DEL' or (&check_mid_data($obj, $index_org))) {return ()}
        # 入力データをcond判定用にバッファ
        push(@{$obj->{cond_buf}}, $input_data);
        
        # 最終行指定を実行番号指定に変換
        if ($next_line_data eq 'Data_Extraction_END') {
            &get_cond_l_s($index_now, grep{${$_}[0] eq 'L' and ${$_}[2] eq 'E'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
            &get_cond_l_e($index_now, grep{${$_}[0] eq 'L' and ${$_}[3] eq 'E'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
        }
        # 正規表現指定を実行番号指定に変換
        push(@{${$obj->{cond_data}}[$obj->{cond_index}]}, &get_cond_lr_s($index_now, $line_data, grep{${$_}[0] eq 'LR'}@{${$obj->{cond_data}}[$obj->{cond_index}]}));
        &get_cond_lr_e($index_now, grep{${$_}[0] eq 'r' and $line_data =~ /${$_}[3]/}@{${$obj->{cond_data}}[$obj->{cond_index}]});
        
        # 抽出
        if ($#{$obj->{cond_buf}} > ${$obj->{cond_buf_max}}[$obj->{cond_index}]) {
            return (&get_existence_data($obj));
        } else {
            return ();
        }
    } else {
        # 抽出
        my @return_data = ();
        for (my $index=$#{$obj->{cond_buf}}; $index >= 0; $index--) {
            push(@return_data, &get_existence_data($obj));
        }
        return @return_data;
    }
}
###################################################################################################
sub get_existence_data {
    my ($obj) = @_;
    my $input_data = ${$obj->{cond_buf}}[0];
    my ($buf_org, $seek, $buf_now, $buf_kbn, $buf_data) = @{$input_data};
    
    # 削除対象チェック
    if (&check_mid_data($obj, $buf_org)) {shift(@{$obj->{cond_buf}}); return ()}
    # 入力データをseek用にバッファ
    push(@{$obj->{seek_buf}}, $input_data);
    if ($#{$obj->{seek_buf}} > $obj->{seek_buf_max}) {shift(@{$obj->{seek_buf}})}
    
    # ユーザー抽出
    if (&put_mid_data($obj, $buf_org)) {shift(@{$obj->{cond_buf}}); return ()}
    my $extraction_data = &init_extraction_data("", "$buf_data") |
                          &get_cond_user($obj, "$buf_data", grep{${$_}[0] eq 'USER'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
    if (&change_Bto2($extraction_data) == 0) {
        if ($obj->{output_kbn} ne '' and ${$obj->{output}}[$#{$obj->{output}}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($1 eq $buf_org and $4 eq "USER") {shift(@{$obj->{cond_buf}}); return ()}
            if ($1 eq $buf_org and $4 eq "DEL") {return ()}
        }
        if ($buf_kbn eq "USER") {
            $obj->{output_index}++;
            push(@{$obj->{output}}, "$buf_org,$seek,$obj->{output_index},USER,$buf_data");
            shift(@{$obj->{cond_buf}});
            return ();
        }
    }
    
    # 定型抽出
    if (&change_Bto2($extraction_data) !~ /^1/) {
        # 行抽出、ブロック抽出
        $extraction_data = $extraction_data |
                           &get_cond_lc($buf_data,
                                        grep{(${$_}[0] eq "L" and ((${$_}[1] eq "" and ${$_}[2] ne "E" and ${$_}[2] <= $buf_now and (${$_}[3] eq "E" or $buf_now <= ${$_}[3]))
                                                                or (${$_}[1] ne "" and (${$_}[2] eq "E" or $buf_now < ${$_}[2] or (${$_}[3] ne "E" and ${$_}[3] < $buf_now))))
                                          or (${$_}[0] eq "r" and ((${$_}[1] eq "" and ${$_}[2] <= $buf_now)
                                                                or (${$_}[1] ne "" and $buf_now < ${$_}[2])))
                                          or (${$_}[0] eq "LR" and ${$_}[1] ne "" and ${$_}[8] eq "1" and ${$_}[9] <= $buf_now))}@{${$obj->{cond_data}}[$obj->{cond_index}]});
    }
    # 列抽出
    if (&change_Bto2($extraction_data) !~ /^1/) {
        $extraction_data = $extraction_data | &get_cond_c($buf_data, grep{${$_}[0] eq 'C'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
        $extraction_data = $extraction_data | &get_cond_cr($buf_data, grep{${$_}[0] eq 'CR'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
    }
    
    # condバッファ制御
    shift(@{$obj->{cond_buf}});
    
    if (&change_Bto2($extraction_data) > 0) {
        my $return_data = &get_out_data("$buf_data", &change_Bto2($extraction_data));
        return [$buf_org, $seek, "", "$buf_kbn", "$return_data"];
    } else {
        return ();
    }
}
###################################################################################################
sub put_mid_data {
    my ($obj, $buf_org) = @_;
    
    my $mid_flg = 0;
    for (my $index=0 ; $index <= $#{$obj->{mid}}; $index++) {
        if (${$obj->{mid}}[$index] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($1 eq $buf_org) {
                $obj->{output_index}++;
                push(@{$obj->{output}}, "$1,$2,$obj->{output_index},USER,$5");
                $mid_flg = 1;
            }
        }
    }
    return $mid_flg;
}
###################################################################################################
sub check_mid_data {
    my ($obj, $index_org) = @_;
    
    for (my $index=0 ; $index <= $#{$obj->{mid}}; $index++) {
        if (${$obj->{mid}}[$index] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($1 eq $index_org and $4 eq 'DEL') {return 1}
        }
    }
    return 0;
}
###################################################################################################
#   ＜＜ 抽出データを取得 ＞＞                                                                    #
###################################################################################################
sub get_out_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 行データ                                                                #
    #      ： $_[1] = 抽出対象区分                                                            #
    # 処理 ： 抽出対象区分から抽出データを取得                                                #
    # 返却 ： 抽出データ                                                                      #
    #-----------------------------------------------------------------------------------------#
    if ($_[1] =~ /^1/) {
        # 行抽出
        return $_[0];
    } else {
        # 列抽出
        my @col_data = &get_col_data("", "$_[0]"); unshift @col_data, '';
        my $out_data = "";
        for (my $index=1; $index <= $#col_data; $index++) {
            if ((substr $_[1], $index, 1) eq "1") {$out_data .= "$col_data[$index] "}
        }
        chop $out_data;
        return $out_data;
    }
}
###################################################################################################
#   ＜＜ 入力ファイルＯＰＥＮ ＞＞                                                                #
###################################################################################################
sub in_file_open {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 入力ファイル名                                                          #
    # 処理 ： 入力ファイルのファイルＯＰＥＮ                                                  #
    #-----------------------------------------------------------------------------------------#
    if (! open (EXTRACTION_FILE, "< $_[0]")) {
        # 入力ファイルOPENエラー
        print STDERR "Input File($_[0]) cannot Open\n";
        exit 99;
    }
    #flock(EXTRACTION_FILE, 1);
}
###################################################################################################
#   ＜＜ 入力ファイルＣＬＯＳＥ ＞＞                                                              #
###################################################################################################
sub in_file_close {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 入力ファイル名                                                          #
    # 処理 ： 入力ファイルのファイルＣＬＯＳＥ                                                #
    #-----------------------------------------------------------------------------------------#
    if (! close (EXTRACTION_FILE)) {
        # 入力ファイルCLOSEエラー
        print STDERR "Input File($_[0]) cannot Close\n";
        exit 99;
    }
}
###################################################################################################
#   ＜＜ 処理中行番号取得 ＞＞                                                                    #
###################################################################################################
sub get_line_num {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    # 処理 ： 処理中の行番号を取得                                                            #
    #-----------------------------------------------------------------------------------------#
    return ${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2];
}
###################################################################################################
#   ＜＜ 行番号チェック ＞＞                                                                      #
###################################################################################################
sub check_line_num {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 行番号                                                                  #
    # 処理 ： 行番号の記述チェック                                                            #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] !~ /^\d+$/ or $_[0] <= 0) {
        print STDERR "Line Number Error($_[0]), \n";
        exit 99;
    }
}
###################################################################################################
#   ＜＜ データ取得区分チェック ＞＞                                                              #
###################################################################################################
sub check_data_acquisition_flag {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = データ取得区分                                                          #
    # 処理 ： データ取得区分の記述チェック                                                    #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] ne "org" and $_[0] ne "now") {
        print STDERR "Data Acquisition division Error($_[0]), \n";
        exit 99;
    }
}
###################################################################################################
#   ＜＜ 抽出データ存在チェック ＞＞                                                              #
###################################################################################################
sub check_existence_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行番号                                                                  #
    # 処理 ： オブジェクトに保存している抽出対象データに指定行が存在するかチェック            #
    #-----------------------------------------------------------------------------------------#
    foreach (@{$_[0]->{seek_buf}}) {
        if ($_[1] == ${$_}[2]) {return 1}
    }
    return 0;
}
###################################################################################################
#   ＜＜ １０進数→１６進数変換 ＞＞                                                              #
###################################################################################################
sub change_10to16{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = １０進数の文字列                                                        #
    # 処理 ： １０進数の文字列を１６進数の文字列に変換                                        #
    #-----------------------------------------------------------------------------------------#
    if (((length $_[0]) % 2) == 0) {
        return pack("H*", "$_[0]");
    } else {
        return pack("H*", "0$_[0]");
    }
}
###################################################################################################
#   ＜＜ １６進数→１０進数変換 ＞＞                                                              #
###################################################################################################
sub change_16to10{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = １６進数の文字列                                                        #
    # 処理 ： １６進数の文字列を１０進数の文字列に変換                                        #
    #-----------------------------------------------------------------------------------------#
    return unpack("H*", "$_[0]");
}
###################################################################################################
#   ＜＜ ２進数→バイナリ変換 ＞＞                                                                #
###################################################################################################
sub change_2toB{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = ２進数の文字列                                                          #
    # 処理 ： ２進数の文字列をバイナリ文字列に変換                                            #
    #-----------------------------------------------------------------------------------------#
    return pack("B*", "$_[0]");
}
###################################################################################################
#   ＜＜ バイナリ→２進数変換 ＞＞                                                                #
###################################################################################################
sub change_Bto2{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = バイナリ文字列                                                          #
    # 処理 ： バイナリ文字列を２進数の文字列に変換                                            #
    #-----------------------------------------------------------------------------------------#
    return unpack("B*", "$_[0]");
}
###################################################################################################
#   ＜＜ バッファエラー ＞＞                                                                      #
###################################################################################################
sub error_buffers {
    # バッファに該当データ無し
    print STDERR "Buffers does not have Line Number Pertinence Data(line($_[0])-\>seek($_[1]))\n";
    exit 99;
}
###################################################################################################
#   ＜＜ 抽出対象データ取得位置指定 ＞＞                                                          #
###################################################################################################
sub seek_line {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行番号                                                                  #
    # 処理 ： 行番号チェック、抽出対象データの読込む位置を指定行へ移動                        #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $number) = @_;
    &check_line_num("$number");
    if ($obj->{output_kbn} ne '') {$obj->{output_kbn} = 'seek'}
    
    if ($number <= ${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[2]) {
        for (my $index=0; $index <= $#{$obj->{seek_buf}}; $index++) {
            if ($number == ${${$obj->{seek_buf}}[$index]}[2]) {
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$index]}[1]), 0 or "$!($obj->{in_name})";
                }
                @{$obj->{seek_num}}[0..2] = (${${$obj->{seek_buf}}[$index]}[0], ${${$obj->{seek_buf}}[$index]}[1], $number);
                $obj->{seek_kbn}          = 'seek';
                $obj->{seek_index}        = $index;
                @{$obj->{get_num}}        = @{$obj->{seek_num}};
                $obj->{get_kbn}           = $obj->{seek_kbn};
                $obj->{get_index}         = $obj->{seek_index};
                return ${${$obj->{seek_buf}}[$index]}[1];
            }
        }
        &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
    } else {
        if ($obj->{cond_index} > 0) {
            for (my $index=0; $index <= $#{$obj->{cond_buf}}; $index++) {
                if (${${$obj->{cond_buf}}[$index]}[4] eq 'Data_Extraction_END') {
                    &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
                }
                if ($number == ${${$obj->{cond_buf}}[$index]}[2]) {
                    if ($obj->{in_kbn} ne '') {
                        seek EXTRACTION_FILE, (${${$obj->{cond_buf}}[$index]}[1]), 0 or "$!($obj->{in_name})";
                    }
                    @{$obj->{seek_num}}[0..2] = (${${$obj->{cond_buf}}[$index]}[0], ${${$obj->{cond_buf}}[$index]}[1], $number);
                    $obj->{seek_kbn}          = 'cond';
                    $obj->{seek_index}        = $index;
                    @{$obj->{get_num}}        = @{$obj->{seek_num}};
                    $obj->{get_kbn}           = $obj->{seek_kbn};
                    $obj->{get_index}         = $obj->{seek_index};
                    return ${${$obj->{cond_buf}}[$index]}[1];
                }
            }
            while (1) {
                my $for_max = $#{$obj->{input}} - $obj->{seek_buf_max};
                if ($obj->{seek_buf_max} > 0 and ${$obj->{input}}[$#{$obj->{input}}] eq 'Data_Extraction_END') {
                    $for_max = $#{$obj->{input}};
                }
                for (my $index=0; $index <= $for_max; $index++) {
                    if (${$obj->{input}}[$index] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                        if ($number == $3) {
                            if ($obj->{in_kbn} ne '') {
                                seek EXTRACTION_FILE, ($2), 0 or "$!($obj->{in_name})";
                            }
                            @{$obj->{seek_num}}[0..2] = ($1, $2, $number);
                            $obj->{seek_kbn}          = 'input';
                            $obj->{seek_index}        = $index;
                            @{$obj->{get_num}}        = @{$obj->{seek_num}};
                            $obj->{get_kbn}           = $obj->{seek_kbn};
                            $obj->{get_index}         = $obj->{seek_index};
                            return $2;
                        }
                    }
                    if ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus) or ${$obj->{input}}[$index] eq 'Data_Extraction_END') {
                        &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
                    }
                }
                sleep 1;
            }
        } else {
            if ($obj->{in_kbn} ne '') {
                seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1]), 0 or "$!($obj->{in_name})";
            }
            my $index = ${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[2];
            my $line = &get_line_data($obj, $index);
            while ($line ne 'Data_Extraction_END') {
                $index++;
                if ($number == $index) {
                    @{$obj->{seek_num}}[0..2] = ($index, (tell EXTRACTION_FILE), $number);
                    $obj->{seek_kbn}          = 'org';
                    $obj->{seek_index}        = 0;
                    @{$obj->{get_num}}        = @{$obj->{seek_num}};
                    $obj->{get_kbn}           = $obj->{seek_kbn};
                    $obj->{get_index}         = $obj->{seek_index};
                    return (tell EXTRACTION_FILE);
                }
                $line = &get_line_data($obj, $index);
            }
            &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
        }
    }
}
###################################################################################################
#   ＜＜ 抽出対象データ取得 ＞＞                                                                  #
###################################################################################################
sub get_line {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = データ取得区分（org：オリジナル／now：抽出結果）                        #
    # 処理 ： データ取得区分チェック、抽出対象データの取得                                    #
    # 返却 ： 抽出対象データ                                                                  #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $flg) = @_;
    my $line = "";
    &check_data_acquisition_flag("$flg");
    
    if ($flg eq "org" or $obj->{seek_kbn} eq "org") {
        # オリジナル
        @{$obj->{get_num}} = @{$obj->{seek_num}};
        if ($_[0]->{in_kbn} eq "") {
            $line = &get_line_data($obj, (${$obj->{seek_num}}[2] - 1));
        } else {
            $line = &get_line_data($obj);
        }
        $obj->{get_kbn}    = $obj->{seek_kbn};
        ${$obj->{seek_num}}[0]++;
    } else {
        # 抽出結果
        if ($obj->{seek_kbn} eq 'seek') {
            ${$obj->{seek_num}}[0] = ${${$obj->{seek_buf}}[$obj->{seek_index}]}[0];
            ${$obj->{seek_num}}[1] = ${${$obj->{seek_buf}}[$obj->{seek_index}]}[1];
            $line = ${${$obj->{seek_buf}}[$obj->{seek_index}]}[4];
        } elsif ($obj->{seek_kbn} eq 'cond') {
            ${$obj->{seek_num}}[0]  = ${${$obj->{cond_buf}}[$obj->{seek_index}]}[0];
            ${$obj->{seek_num}}[1]  = ${${$obj->{cond_buf}}[$obj->{seek_index}]}[1];
            $line = ${${$obj->{cond_buf}}[$obj->{seek_index}]}[4];
        } else {
            while (($#{$obj->{input}} - $obj->{seek_buf_max}) < $obj->{seek_index}) {
                if ($#{$obj->{input}} >= $obj->{seek_index} and ${$obj->{input}}[$#{$obj->{input}}] eq 'Data_Extraction_END') {
                    last;
                }
                if ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus)) {
                    &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],${$obj->{seek_num}}[2]);
                }
                sleep 1;
            }
            if (${$obj->{input}}[$obj->{seek_index}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                ${$obj->{seek_num}}[0] = $1;
                ${$obj->{seek_num}}[1] = $2;
                $line = $5;
            }
        }
        
        @{$obj->{get_num}} = @{$obj->{seek_num}};
        $obj->{get_kbn}    = $obj->{seek_kbn};
        $obj->{get_index}  = $obj->{seek_index};
        $obj->{seek_index}++;
        if ($obj->{seek_kbn} eq 'seek' and $#{$obj->{seek_buf}} < $obj->{seek_index}) {
            $obj->{seek_kbn}   = 'cond';
            $obj->{seek_index} = 1;
        }
        if ($obj->{seek_kbn} eq 'cond' and $#{$obj->{cond_buf}} < $obj->{seek_index}) {
            if ($obj->{cond_index} > 0) {
                $obj->{seek_kbn}   = 'input';
                $obj->{seek_index} = 0;
            } else {
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${$obj->{seek_num}}[1]), 0 or "$!($obj->{in_name})";
                }
                my $line = &get_line_data($obj, ${$obj->{seek_num}}[0]);
                $obj->{seek_kbn}   = 'org';
                $obj->{seek_index} = 0;
                ${$obj->{seek_num}}[0]++;
            }
        }
    }
    if ($obj->{seek_kbn} ne 'org') {${$obj->{seek_num}}[2]++}
    return $line;
}
###################################################################################################
sub get_line_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行カウンタ                                                              #
    #-----------------------------------------------------------------------------------------#
    my $line = '';
    
    # オリジナル
    if ($_[0]->{in_kbn} eq "") {
        # 変数指定
        my $check = '^';
        for (my $index=1; $index <= $_[1]; $index++) {
            $check .= '.*\n';
        }
        $check .= '(.*\n{0,1})';
        if ((eval($_[0]->{in_name})) =~ /$check/) {
            $line = $1;
        }
    } else {
        # ファイル指定
        $line = <EXTRACTION_FILE>;
    }
    if ($line eq '') {
        $line = 'Data_Extraction_END';
    } else {
        $_[0]->cut_last_0a($line);
    }
    ${$_[0]->{seek_num}}[2]++;
    return $line;
}
###################################################################################################
#   ＜＜ 抽出区分初期化 ＞＞                                                                      #
###################################################################################################
sub init_extraction_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行データ                                                                #
    # 処理 ： 行データを区切り文字で分割                                                      #
    # 返却 ： 配列化した行データ                                                              #
    #-----------------------------------------------------------------------------------------#
    my $extraction_data = "0" x (&get_col_data("", "$_[1]") + 1);
    return &change_2toB($extraction_data);
}
###################################################################################################
#   ＜＜ 行データ配列変換 ＞＞                                                                    #
###################################################################################################
sub get_col_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行データ                                                                #
    # 処理 ： 行データを区切り文字で分割                                                      #
    # 返却 ： 配列化した行データ                                                              #
    #-----------------------------------------------------------------------------------------#
    return (split /\s+\,*\s*|\,+\s*/, $_[1]);
}
###################################################################################################
#   ＜＜ 抽出データ追加・更新 ＞＞                                                                #
###################################################################################################
sub add_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行データ                                                                #
    # 処理 ： 行データを抽出データのカレント行（seekしている場合は、その行）に追加・更新      #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $line_data) = @_;
    
    if ($obj->{get_kbn} eq 'seek') {
        if ($obj->{get_index} == $#{$obj->{seek_buf}}) {
            $obj->{output_index}++;
            push(@{$obj->{output}}, "${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[0],${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1],$obj->{output_index},USER,$line_data");
            $obj->{output_kbn} = 'output';
        } else {
            for (my $index=0 ; $index <= $#{$obj->{output}} ; $index++) {
                if (${$obj->{output}}[($#{$obj->{output}} - $index)] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                    if ($1 eq ${$obj->{get_num}}[0]) {
                        if ($obj->{output_kbn} eq '') {
                            my @temp = @{$obj->{output}};
                            splice(@temp, ($#{$obj->{output}} - $index), 1, ("$1,$2,$3,USER,$line_data"));
                            @{$obj->{output}} = @temp;
                        } elsif ($index > 0) {
                            $obj->{output_index}++;
                            my @temp = @{$obj->{output}};
                            splice(@temp, ($#{$obj->{output}} - $index + 1), 0, ("$1,$2,$obj->{output_index},USER,$line_data"));
                            @{$obj->{output}} = @temp;
                        } else {
                            $obj->{output_index}++;
                            push(@{$obj->{output}}, "$1,$2,$obj->{output_index},USER,$line_data");
                        }
                        $obj->{output_kbn} = 'output';
                        last;
                    }
                }
            }
        }
    } elsif ($obj->{get_kbn} eq 'cond') {
        push(@{$obj->{mid}}, "${${$obj->{cond_buf}}[$obj->{get_index}]}[0],${${$obj->{cond_buf}}[$obj->{get_index}]}[1],${${$obj->{cond_buf}}[$obj->{get_index}]}[2],USER,$line_data");
    } elsif ($obj->{get_kbn} eq 'input') {
        if (${$obj->{input}}[$obj->{get_index}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            push(@{$obj->{mid}}, "$1,$2,$3,USER,$line_data");
        }
    } else {
        if ($obj->{in_kbn} eq '') {
            push(@{$obj->{mid}}, "${$obj->{get_num}}[0],,${$obj->{get_num}}[2],USER,$line_data");
        } else {
            push(@{$obj->{mid}}, "${$obj->{get_num}}[0],${$obj->{get_num}}[1],${$obj->{get_num}}[2],USER,$line_data");
        }
    }
}
###################################################################################################
#   ＜＜ 抽出データ削除 ＞＞                                                                      #
###################################################################################################
sub del_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    # 処理 ： 抽出データからカレント行（seekしている場合は、その行）を削除                    #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $line_data) = @_;
    
    if ($obj->{get_kbn} eq 'seek') {
        if ($obj->{get_index} < $#{$obj->{seek_buf}}) {
            my $del_flg = '';
            for (my $index=0 ; $index <= $#{$obj->{output}} ; $index++) {
                if (${$obj->{output}}[($#{$obj->{output}} - $index)] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                    if ($1 eq ${$obj->{get_num}}[0]) {
                        if ($4 eq '' or $index == $#{$obj->{output}}) {
                            my @temp = @{$obj->{output}};
                            splice(@temp, ($#{$obj->{output}} - $index), 1);
                            @{$obj->{output}} = @temp;
                            last;
                        } else {
                            $del_flg = '1';
                        }
                    } elsif ($del_flg = '1') {
                        my @temp = @{$obj->{output}};
                        splice(@temp, ($#{$obj->{output}} - $index + 1), 1);
                        @{$obj->{output}} = @temp;
                        last;
                    }
                }
            }
        } else {
            push(@{$obj->{output}}, "${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[0],,,DEL,");
            shift(@{$obj->{cond_buf}});
        }
        $obj->{output_kbn} = 'output';
        splice(@{$obj->{seek_buf}}, $obj->{get_index}, 1);
    } elsif ($obj->{get_kbn} eq 'cond') {
        push(@{$obj->{mid}}, "${${$obj->{cond_buf}}[$obj->{get_index}]}[0],,,DEL,");
        splice(@{$obj->{cond_buf}}, $obj->{get_index}, 1);
    } elsif ($obj->{get_kbn} eq 'input') {
        if (${$obj->{input}}[$obj->{get_index}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            push(@{$obj->{mid}}, "$1,,,DEL,");
        }
        splice(@{$obj->{input}}, $obj->{get_index}, 1);
    } else {
        push(@{$obj->{mid}}, "${$obj->{get_num}}[0],,,DEL,");
    }
}
###################################################################################################
#   ＜＜ 行末改行コード削除 ＞＞                                                                  #
###################################################################################################
sub cut_last_0a{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #         $_[1] = 行データ                                                                #
    # 処理 ： 行末の改行コードを削除                                                          #
    # 返却 ： 行データ                                                                        #
    #-----------------------------------------------------------------------------------------#
    if ((substr $_[1], -1) eq "\n") {
        chop $_[1];
    }
}
###################################################################################################
#   ＜＜ 正規表現指定による行抽出の起点行検出 ＞＞                                                #
###################################################################################################
sub get_cond_lr_s {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = 行番号                                                                 #
    #      ： $_[1]  = 行データ                                                               #
    #      ： $_[2～]= 抽出条件（正規表現による行抽出）                                       #
    # 処理 ： 範囲指定なし）行番号指定（抽出区分＝"L"）に変換                                 #
    #         範囲指定あり）起点を行番号指定（抽出区分＝"r"）に変換                           #
    # 返却 ： 起点を行番号指定に変換した抽出条件                                              #
    #-----------------------------------------------------------------------------------------#
    my $line_now  = shift;
    my $line_data = shift;
    my @add_cond  = ();
    
    # 正規表現指定を行番号指定に変換（起点行）
    foreach (@_) {
        if ($line_data =~ /${$_}[2]/) {
            if (${$_}[1] eq "") {
                if (${$_}[3] eq '') {
                    push(@add_cond, ['L', "", "$line_now", "${$_}[3]", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                } elsif (${$_}[3] =~ /^\+\d+$/ ) {
                    push(@add_cond, ['L', "", "$line_now", ($line_now + ${$_}[3]), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                } elsif (${$_}[3] =~ /^-\d+$/ ) {
                    push(@add_cond, ['L', "", ($line_now + ${$_}[3]), "$line_now", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                } else {
                    push(@add_cond, ['r', "", "$line_now", "${$_}[3]", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                }
            } else {
                if (${$_}[3] eq '') {
                    if (${$_}[8] eq "1") {
                        push(@add_cond, ['L', "", "${$_}[9]", ($line_now - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                    }
                    ${$_}[9] = ($line_now + 1);
                } elsif (${$_}[3] =~ /^\+\d+$/ ) {
                    if (${$_}[8] eq "1") {
                        push(@add_cond, ['L', "", "${$_}[9]", ($line_now - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                    }
                    ${$_}[9] = ($line_now + ${$_}[3] + 1);
                } elsif (${$_}[3] =~ /^-\d+$/ ) {
                    if (${$_}[8] eq "1") {
                        push(@add_cond, ['L', "", "${$_}[9]", ($line_now + ${$_}[3] - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                    }
                    ${$_}[9] = ($line_now + 1);
                } else {
                    if (${$_}[8] eq "1") {
                        push(@add_cond, ['L', "", "${$_}[9]", ($line_now - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                    }
                }
                ${$_}[8] = "";
            }
        } else {
            if (${$_}[8] eq "") {
                if (${$_}[3] eq '' or ${$_}[3] =~ /^[\+-]\d+$/ ) {
                    if (${$_}[9] <= $line_now) {
                        ${$_}[8] = "1";
                    }
                } else {
                    if ($line_data =~ /${$_}[3]/) {
                        ${$_}[8] = "0";
                        ${$_}[9] = ($line_now + 1);
                    }
                }
            } elsif (${$_}[8] eq "0") {
                ${$_}[8] = "1";
                ${$_}[9] = $line_now;
            }
        }
    }
    # 検出情報を返却
    return @add_cond;
}
###################################################################################################
#   ＜＜ 正規表現指定による行抽出の範囲行検出 ＞＞                                                #
###################################################################################################
sub get_cond_lr_e {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = 行番号                                                                 #
    #      ： $_[1～]= 抽出条件                                                               #
    # 処理 ： 正規表現（範囲）を行番号指定に変換                                              #
    #-----------------------------------------------------------------------------------------#
    my $line_now  = shift;
    
    # 正規表現指定を行番号指定に変換（範囲行）
    foreach (@_) {
        ${$_}[0] = 'L';
        ${$_}[3] = $line_now;
    }
}
###################################################################################################
#   ＜＜ 最終行指定による行抽出の起点行検出 ＞＞                                                  #
###################################################################################################
sub get_cond_l_s {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = 行番号                                                                 #
    #      ： $_[1～]= 抽出条件（最終行指定"E"による行抽出）                                  #
    # 処理 ： 最終行指定を行番号指定に変換                                                    #
    #-----------------------------------------------------------------------------------------#
    my $line_now  = shift;
    
    foreach (@_) {
        ${$_}[2] = $line_now;
        if (${$_}[3] eq '') {
            ${$_}[3] = $line_now;
        } elsif (${$_}[3] =~ /^\d+$/) {
            if (${$_}[2] > ${$_}[3]) {
                my $temp_su = ${$_}[2];
                ${$_}[2] = ${$_}[3];
                ${$_}[3] = $temp_su;
            }
        } elsif (${$_}[3] =~ /^-\d+$/ and ${$_}[3] != 0) {
            my $temp_su = ${$_}[2];
            ${$_}[2] = ${$_}[2] + ${$_}[3];
            ${$_}[3] = $temp_su;
        } elsif (${$_}[3] =~ /^\+\d+$/ and ${$_}[3] != 0) {
            ${$_}[3] = ${$_}[2] + ${$_}[3];
        }
    }
}
###################################################################################################
#   ＜＜ 最終行指定による行抽出の範囲行検出 ＞＞                                                  #
###################################################################################################
sub get_cond_l_e {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = 行番号                                                                 #
    #      ： $_[1～]= 抽出条件（最終行指定"E"による行抽出）                                  #
    # 処理 ： 最終行指定を行番号指定に変換                                                    #
    #-----------------------------------------------------------------------------------------#
    my $line_now  = shift;
    
    foreach (@_) {
        ${$_}[3] = $line_now;
        if (${$_}[3] =~ /^\d+$/) {
            if (${$_}[2] > ${$_}[3]) {
                my $temp_su = ${$_}[2];
                ${$_}[2] = ${$_}[3];
                ${$_}[3] = $temp_su;
            }
        } elsif (${$_}[3] =~ /^-\d+$/ and ${$_}[3] != 0) {
            my $temp_su = ${$_}[2];
            ${$_}[2] = ${$_}[2] + ${$_}[3];
            ${$_}[3] = $temp_su;
        } elsif (${$_}[3] =~ /^\+\d+$/ and ${$_}[3] != 0) {
            ${$_}[3] = ${$_}[2] + ${$_}[3];
        }
    }
}
###################################################################################################
#   ＜＜ ユーザー抽出 ＞＞                                                                        #
###################################################################################################
sub get_cond_user {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = オブジェクト                                                           #
    #      ： $_[1]  = 入力データ                                                             #
    #      ： $_[1～]= ユーザー引数                                                           #
    # 処理 ： ユーザー関数の呼出し                                                            #
    # 返却 ： ユーザー関数が返却した抽出対象区分                                              #
    #-----------------------------------------------------------------------------------------#
    my $obj             = shift;
    my $line_data       = shift;
    my $extraction_data = '';
    $obj->{output_kbn}  = '';
    
    foreach (@_) {
        # ユーザー関数の呼出し
        @{$obj->{seek_num}}[0..2] = @{${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]};
        $obj->{seek_index}        = $#{$obj->{seek_buf}};
        $obj->{seek_kbn}          = 'seek';
        @{$obj->{get_num}}        = @{$obj->{seek_num}};
        $obj->{get_kbn}           = $obj->{seek_kbn};
        $obj->{get_index}         = $obj->{seek_index};
        seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1]), 0 or "$!($obj->{in_name})";
        my $user_sub = '&'.${$_}[1].'('."\"$line_data\"";
        for (my $index1=2 ; $index1 <= $#{$_}; $index1++) {
            $user_sub .= ', "'.${$_}[$index1].'"';
        }
        $user_sub .= ');';
        $extraction_data = $extraction_data | eval($user_sub);
    }
    return &change_2toB("$extraction_data");
}
###################################################################################################
#   ＜＜ 行・ブロック抽出 ＞＞                                                                    #
###################################################################################################
sub get_cond_lc {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = 行データ                                                               #
    #      ： $_[1～]= 抽出条件（処理行の行・ブロック抽出）                                   #
    # 処理 ： 行抽出、列抽出（列番号指定による列抽出、正規表現指定による列抽出）              #
    # 返却 ： 抽出対象区分                                                                    #
    #-----------------------------------------------------------------------------------------#
    my $line_data = shift;
    
    if ((grep{${$_}[4] eq ''}@_) > 0) {
        # 行抽出
        return &change_2toB("1");
    } else {
        # 列抽出
        my $extraction_data = &get_cond_c($line_data, grep{${$_}[4] eq 'C'}@_);
        $extraction_data = $extraction_data | &get_cond_cr($line_data, grep{${$_}[4] eq 'CR'}@_);
        return $extraction_data;
    }
}
###################################################################################################
#   ＜＜ 列番号指定による列抽出 ＞＞                                                              #
###################################################################################################
sub get_cond_c {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = 行データ                                                               #
    #      ： $_[1～]= 抽出条件（列番号による列抽出）                                         #
    # 処理 ： 列番号指定による列抽出                                                          #
    # 返却 ： 抽出対象区分                                                                    #
    #-----------------------------------------------------------------------------------------#
    my $col_su          = &get_col_data("", shift);
    my $col_start       = undef;
    my $col_end         = undef;
    my $col_add         = undef;
    my $in_kbn          = undef;
    my $in_start        = undef;
    my $in_end          = undef;
    my $extraction_data = "0" x $col_su;
    
    foreach (@_) {
        # 抽出判定対象をチェック
        if (${$_}[0] eq 'C') {
            $col_add = 0;
        } else {
            $col_add = 4;
        }
        # 起点を設定
        if (${$_}[2] eq 'E' or ${$_}[2] eq 'e') {
            $col_start = $col_su;
        } else {
            $col_start = ${$_}[(2 + $col_add)];
        }
        # 範囲を算出
        if (${$_}[(3 + $col_add)] eq '') {
            # 範囲なし
            $col_end = $col_start;
        } elsif (${$_}[(3 + $col_add)] eq 'E' or ${$_}[(3 + $col_add)] eq 'e') {
            # 最終列まで
            if ($col_start <= $col_su) {
                $col_end = $col_su;
            } else {
                $col_end = $col_start;
            }
        } elsif (${$_}[(3 + $col_add)] =~ /^\-(\d+)$/) {
            # －ｎ列まで
            $col_end   = $col_start;
            $col_start = $col_start + ${$_}[(3 + $col_add)];
        } elsif (${$_}[(3 + $col_add)] =~ /^\+(\d+)$/) {
            # ＋ｎ列まで
            $col_end   = $col_start + ${$_}[(3 + $col_add)];
        } elsif (${$_}[(2 + $col_add)] <= ${$_}[(3 + $col_add)]) {
            # 後続指定列まで
            $col_end   = ${$_}[(3 + $col_add)];
        } else {
            # 先行指定列まで
            $col_end   = $col_start;
            $col_start = ${$_}[(3 + $col_add)];
        }
        if ($col_start < 0) {$col_start = 0}
        if ($col_end   < 0) {$col_end   = 0}
        # 抽出対象列を設定
        for (my $index2=1; $index2 <= $col_su; $index2++) {
            if ((${$_}[(1 + $col_add)] eq '' and $index2 >= $col_start and $index2 <= $col_end) or (${$_}[(1 + $col_add)] ne '' and ($index2 < $col_start or $index2 > $col_end))) {
                substr($extraction_data, $index2, 1) = "1";
            }
        }
    }
    return &change_2toB("$extraction_data");
}
###################################################################################################
#   ＜＜ 正規表現指定による列抽出 ＞＞                                                            #
###################################################################################################
sub get_cond_cr {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0]  = 行データ                                                               #
    #      ： $_[1～]= 抽出条件（正規表現による列抽出）                                       #
    # 処理 ： 正規表現指定による列抽出                                                        #
    # 返却 ： 抽出対象区分                                                                    #
    #-----------------------------------------------------------------------------------------#
    my $line_data       = shift;
    my $col_su          = &get_col_data("", "$line_data");
    my $col_start       = undef;
    my $col_end         = undef;
    my $col_add         = undef;
    my $in_kbn          = undef;
    my $in_start        = undef;
    my $in_end          = undef;
    my $extraction_data = "0" x $col_su;
    
    foreach (@_) {
        # 抽出判定対象をチェック
        if (${$_}[0] eq 'CR') {
            $col_add = 0;
        } else {
            $col_add = 4;
        }
        # 正規表現を補正
        my $check_key1 = '';
        ${$_}[(2 + $col_add)] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
        ${$_}[(2 + $col_add)] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
        ${$_}[(2 + $col_add)] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
        ${$_}[(2 + $col_add)] =~  s/^(\[.*),(.*\]\*)/$1$2/;
        if (${$_}[(2 + $col_add)] !~ /^\^|^\\s|^\\,|^,|^\[.*\\s|^\[.*\\,|^\[.*,/) {
            $check_key1 .= '[^\s\,]*';
        }
        $check_key1 .= ${$_}[(2 + $col_add)];
        if (${$_}[(2 + $col_add)] !~ /\$$|\\s\*$|\\s\+$|\\s$|,\*$|,\+$|,$|\[.*\\s.*\]\*$|\[.*\\s.*\]\+$|\[.*,.*\]\*$|\[.*,.*\]\+$/) {
            $check_key1 .= '[^\s\,]*';
        }
        my $check_key2 = '';
        if (${$_}[(3 + $col_add)] ne '' and ${$_}[(3 + $col_add)] !~ /^[\+-]\d+$/) {
            ${$_}[(3 + $col_add)] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
            ${$_}[(3 + $col_add)] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
            ${$_}[(3 + $col_add)] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
            ${$_}[(3 + $col_add)] =~  s/^(\[.*),(.*\]\*)/$1$2/;
            if (${$_}[(3 + $col_add)] !~ /^\^|^\\s|^\\,|^,|^\[.*\\s|^\[.*\\,|^\[.*,/) {
                $check_key2 .= '[^\s\,]*';
            }
            $check_key2 .= ${$_}[(3 + $col_add)];
            if (${$_}[(3 + $col_add)] !~ /\$$|\\s\*$|\\s\+$|\\s$|,\*$|,\+$|,$|\[.*\\s.*\]\*$|\[.*\\s.*\]\+$|\[.*,.*\]\*$|\[.*,.*\]\+$/) {
                $check_key2 .= '[^\s\,]*';
            }
        }
        
        my @cond_c_new = ();
        $col_start = 0;
        $col_end   = 0;
        while ($line_data =~ /($check_key1)(.*)/) {
            my $next_data = $2;
            # 抽出範囲を算出
            my @split_out1 = split /($check_key1)/, $line_data, 3;
            my $split_out1_add = 0;
            if ($split_out1[0] =~ /^\s+\,*\s*$|^\,+\s*$/) {
            } else {
                if ($split_out1[0] =~ /^\s+\,*\s*|^\,+\s*/ and $split_out1[0] =~ /\s+\,*\s*$|\,+\s*$/) {
                    $split_out1_add--;
                }
            }
            $col_start = $col_start + (&get_col_data("", "$split_out1[0]")) + $split_out1_add + 1;
            my $col_split_out1 = &get_col_data("", "$split_out1[1]");
            my $col_end2 = $col_start + $col_split_out1 - 1;
            if (${$_}[(3 + $col_add)] eq '') {
                # 範囲なし
                $col_end = $col_end2;
            } elsif (${$_}[(3 + $col_add)] =~ /^\+(\d+)$/) {
                # ＋ｎ列まで
                $col_end = $col_end2 + ${$_}[(3 + $col_add)];
          } elsif (${$_}[(3 + $col_add)] =~ /^-(\d+)$/) {
                # －ｎ列まで
                $col_start = $col_start + ${$_}[(3 + $col_add)];
                $col_end   = $col_end2;
            } else {
                # 正規表現の列まで
                if ($next_data =~ /($check_key2)(.*)/) {
                    my $back_data = $2;
                    my @split_out2 = split /($check_key2)/, $next_data, 3;
                    $col_end = $col_su - (&get_col_data("", "$back_data")) + 1;
                } else {
                    $col_end = $col_su;
                }
            }
            if ($col_start < 0) {$col_start = 0}
            if ($col_end   < 0) {$col_end   = 0}
            for (my $index3=$col_start; $index3 <= $col_end; $index3++) {
                $cond_c_new[$index3] = '1';
            }
            $col_start = $col_end2;
            $line_data = $next_data;
        }
        # 抽出対象列を設定
        for (my $index2=1; $index2 <= $col_su; $index2++) {
            if ((${$_}[(1 + $col_add)] eq '' and $cond_c_new[$index2] eq '1') or (${$_}[(1 + $col_add)] ne '' and $cond_c_new[$index2] eq '')) {
                substr($extraction_data, $index2, 1) = "1";
            }
        }
    }
    return &change_2toB("$extraction_data");
}
1;
