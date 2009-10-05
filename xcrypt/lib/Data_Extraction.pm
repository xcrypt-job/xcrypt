package Data_Extraction;
use Exporter;
@ISA    = (Exporter);
@EXPORT = qw(EF);
use strict;
use threads;
use threads::shared;
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
    my $seek_number   = 0;
    my $seek_index    = 0;
    my $seek_kbn      = '';
    my $seek_buf_max  = 0;
    my @out_data_line = ();
    my $input         = '';
    my $output        = '';
    my @out_data      = ();
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
    my $Job = {"in_kbn"        =>$in_data[0],                 # 入力区分（ファイルor変数）
               "in_name"       =>$in_data[1],                 # 入力データ名（ファイル名or変数名）
               "cond_index"    =>$cond_index,                 # 抽出条件index
               "cond_data"     =>\@cond_data,                 # 抽出条件
               "cond_buf"      =>\@cond_buf,                  # 抽出バッファ
               "cond_buf_max"  =>\@cond_buf_max,              # 抽出バッファ数
               "seek_buf"      =>\@seek_buf,                  # seekバッファ
               "seek_number"   =>$seek_number,                # seek行番号
               "seek_index"    =>$seek_index,                 # seekバッファindex
               "seek_kbn"      =>$seek_kbn,                   # seek区分
               "seek_buf_max"  =>$seek_buf_max,               # seekバッファ数
               "input"         =>$input,                      # 入力データ
               "output"        =>$output,                     # 出力データ
               "out_data_line" =>\@out_data_line,             # 抽出対象データの行番号
               "out_data"      =>\@out_data};                 # 抽出対象データ
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
    
    &in_file_open($obj->{in_name});
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
    
    &in_file_close($obj->{in_name});
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
    my $line_in  = 0;
    my $line_out = 0;
    
    threads->new(sub {
        $obj->{cond_index} = 0;
        $obj->{input}      = \@input;
        $obj->{output}     = $output;
        my $line = &get_line_data($obj, $line_in);
        my $seek = 0;
        my $next_seek = tell EXTRACTION_FILE;
        my $next_line = '';
        while ($line ne 'Data_Extraction_END') {
            $line_in++;
            $next_line = &get_line_data($obj, $line_in);
            my $next_seek2 = tell EXTRACTION_FILE;
            my @result = &check_existence($obj, [$line_in, $seek, $line_in, "", $line], $next_line);
            foreach (@result) {
                $line_out++;
                while ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus)) {
                    sleep 1;
                }
                push(@{$output}, "${$_}[0],${$_}[1],$line_out,${$_}[3],${$_}[4]");
            }
            $line = $next_line;
            $seek = $next_seek;
            $next_seek = $next_seek2;
            seek EXTRACTION_FILE, ($next_seek), 0 or "$!($obj->{in_name})";
        }
        for (my $index=$#{$obj->{cond_buf}}; $index >= 0; $index--) {
            my @result = &get_existence_data($obj);
            foreach (@result) {
                $line_out++;
                while ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus)) {
                    sleep 1;
                }
                push(@{$output}, "${$_}[0],${$_}[1],$line_out,${$_}[3],${$_}[4]");
            }
        }
        push(@{$output}, 'Data_Extraction_END');
    });
}
###################################################################################################
sub existence_watch {
    my ($obj, $cond_index, $input, $output) = @_;
    my $line_in  = 0;
    my $line_out = 0;
    
    threads->new(sub {
        $obj->{cond_index} = $cond_index;
        $obj->{input}      = $input;
        $obj->{output}     = $output;
        while (1) {
            if ($#{$input} >= 1 and ($#{$input} > $obj->{seek_buf_max} or ${$input}[$#{$input}] eq 'Data_Extraction_END')) {
                my $input_data = shift(@{$input});
                $line_in++;
                if ($input_data =~ /^(.*),(.*),(.*),(.*),(.*)/) {
                    my @result = &check_existence($obj, ["$1", "$2", "$line_in", "$4", "$5"], "${$input}[0]");
                    foreach (@result) {
                        $line_out++;
                        while ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus)) {
                            sleep 1;
                        }
                        push(@{$output}, "${$_}[0],${$_}[1],$line_out,${$_}[3],${$_}[4]");
                    }
                }
            }
            if (${$input}[0] eq 'Data_Extraction_END') {
                for (my $index=$#{$obj->{cond_buf}}; $index >= 0; $index--) {
                    my @result = &get_existence_data($obj);
                    foreach (@result) {
                        $line_out++;
                        while ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus)) {
                            sleep 1;
                        }
                        push(@{$output}, "${$_}[0],${$_}[1],$line_out,${$_}[3],${$_}[4]");
                    }
                }
                push(@{$output}, 'Data_Extraction_END');
                last;
            }
        }
    });
}

###################################################################################################
sub extraction_result {
    my @return_data = ();
    
    foreach (@_) {
        if ($_ =~ /^(.*),(.*),(.*),(.*),(.*)/) {
            push(@return_data, $5);
        }
    }
    return @return_data;
}
###################################################################################################
sub check_existence {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行データ                                                                #
    #      ： $_[2] = 次行データ                                                              #
    # 処理 ： 定型抽出（行・列・ブロック抽出）、ユーザー抽出（ユーザー関数呼出し）            #
    # 返却 ： 抽出結果                                                                        #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $input_data, $next_line_data) = @_;
    my ($index_org, $seek, $index_now, $out_kbn, $line_data) = @{$input_data};
    
    if ($line_data ne 'Data_Extraction_END') {
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
    
    # 入力データをseek用にバッファ
    push(@{$obj->{seek_buf}}, $input_data);
    if ($#{$obj->{seek_buf}} > $obj->{seek_buf_max}) {
        shift(@{$obj->{seek_buf}});
    }
    
    # ユーザー抽出
    my $extraction_data = &init_extraction_data("", "$buf_data") | &get_cond_user($obj, grep{${$_}[0] eq 'USER'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
    
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
    
    # 抽出結果（抽出データ）を登録
    shift(@{$obj->{cond_buf}});
    if (&change_Bto2($extraction_data) > 0) {
        my $return_data = &get_out_data("$buf_data", &change_Bto2($extraction_data));
        return [$buf_org, $seek, "", "", "$return_data"];
    } else {
        return ();
    }
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
            if ((substr $_[1], $index, 1) eq "1") {
                $out_data .= "$col_data[$index] ";
            }
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
        if ($_[1] == ${$_}[2]) {
            return 1;
        }
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
    $obj->{seek_number} = $number;
    
    if ($number <= ${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[2]) {
        for (my $index=0; $index <= $#{$obj->{seek_buf}}; $index++) {
            if ($number == ${${$obj->{seek_buf}}[$index]}[2]) {
                seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$index]}[1]), 0 or "$!($obj->{in_name})";
                $obj->{seek_kbn}   = 'seek';
                $obj->{seek_index} = ($index * -1);
                return ${${$obj->{seek_buf}}[$index]}[1];
            }
        }
        # ユーザseekバッファに該当データ無し
        print STDERR "Seek Buffers does not have Line Number Pertinence Data($number)\n";
        exit 99;
    } else {
        if ($obj->{cond_index} > 0) {
            for (my $index=0; $index <= $#{$obj->{cond_buf}}; $index++) {
                if (${${$obj->{cond_buf}}[$index]}[4] eq 'Data_Extraction_END') {
                    # ユーザseekバッファに該当データ無し
                    print STDERR "Seek Buffers does not have Line Number Pertinence Data($number)\n";
                    exit 99;
                }
                if ($number == ${${$obj->{cond_buf}}[$index]}[2]) {
                    seek EXTRACTION_FILE, (${${$obj->{cond_buf}}[$index]}[1]), 0 or "$!($obj->{in_name})";
                    $obj->{seek_kbn}   = 'cond';
                    $obj->{seek_index} = $index;
                    return ${${$obj->{cond_buf}}[$index]}[1];
                }
            }
            while (1) {
                for (my $index=0; $index <= $#{$obj->{input}}; $index++) {
                    if (${$obj->{input}}[$index] =~ /^(.*),(.*),(.*),(.*),(.*)/) {
                        if ($number == $3) {
                            seek EXTRACTION_FILE, ($2), 0 or "$!($obj->{in_name})";
                            $obj->{seek_kbn}   = 'input';
                            $obj->{seek_index} = $index;
                            return $2;
                        }
                    }
                    if ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus) or ${$obj->{input}}[$index] eq 'Data_Extraction_END') {
                        # ユーザseekバッファに該当データ無し
                        print STDERR "Seek Buffers does not have Line Number Pertinence Data($number)\n";
                        exit 99;
                    }
                }
                sleep 1;
            }
        } else {
            seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1]), 0 or "$!($obj->{in_name})";
            my $index = ${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[2];
            my $line = &get_line_data($obj, $index);
            while ($line ne 'Data_Extraction_END') {
                $index++;
                if ($number == $index) {
                    $obj->{seek_kbn}   = 'org';
                    $obj->{seek_index} = 0;
                    return (tell EXTRACTION_FILE);
                }
                $line = &get_line_data($obj, $index);
            }
            # ユーザseekバッファに該当データ無し
            print STDERR "Seek Buffers does not have Line Number Pertinence Data($number)\n";
            exit 99;
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
        if ($_[0]->{in_kbn} eq "") {
            $line = &get_line_data($obj, ($obj->{seek_number} - 1));
        } else {
            $line = &get_line_data($obj);
        }
    } else {
        # 抽出結果
        if ($obj->{seek_index} <= 0) {
            $line = ${${$obj->{seek_buf}}[($obj->{seek_index} * -1)]}[4];
        } elsif ($obj->{seek_kbn} eq 'cond') {
            $line = ${${$obj->{cond_buf}}[$obj->{seek_index}]}[4];
        } else {
            while ($#{$obj->{input}} < $obj->{seek_index}) {
                if ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus) or ${$obj->{input}}[$#{$obj->{input}}] eq 'Data_Extraction_END') {
                    # ユーザseekバッファに該当データ無し
                    print STDERR "Seek Buffers does not have Line Number Pertinence Data($obj->{seek_number})\n";
                    exit 99;
                }
                sleep 1;
            }
            if (${$obj->{input}}[$obj->{seek_index}] =~ /^(.*),(.*),(.*),(.*),(.*)/) {
                $line = $5;
            }
        }
        $obj->{seek_index}++;
        if ($obj->{seek_kbn} eq 'cond' and $#{$obj->{cond_buf}} < $obj->{seek_index}) {
            $obj->{seek_kbn}   = 'input';
            $obj->{seek_index} = 1;
        }
    }
    $obj->{seek_number}++;
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
    $_[0]->{seek_number}++;
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
    #      ： $_[1] = 行番号                                                                  #
    #      ： $_[2] = 行データ                                                                #
    # 処理 ： 行データをオブジェクトの抽出データに追加・更新                                  #
    #-----------------------------------------------------------------------------------------#
    for (my $index1=0 ; $index1 <= $#{$_[0]->{out_data_line}}; $index1++) {
        if ($_[1] == (&change_16to10(${$_[0]->{out_data_line}}[$index1]))) {
            $_[0]->{out_data}[$index1] = "$_[2]";
            return;
        } elsif ($_[1] < (&change_16to10(${$_[0]->{out_data_line}}[$index1]))) {
            splice(@{$_[0]->{out_data_line}}, $index1, 0, (&change_10to16($_[1])));
            splice(@{$_[0]->{out_data}}, $index1, 0, "$_[2]");
            return;
        }
    }
    push(@{$_[0]->{out_data_line}}, (&change_10to16($_[1])));
    push(@{$_[0]->{out_data}}, $_[2]);
}
###################################################################################################
#   ＜＜ 抽出データ削除 ＞＞                                                                      #
###################################################################################################
sub del_data {
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #      ： $_[1] = 行番号                                                                  #
    # 処理 ： オブジェクトの抽出データから指定行を削除                                        #
    #-----------------------------------------------------------------------------------------#
    if ($_[0]->{line_now} > $_[1]) {
        for (my $index1=0 ; $index1 <= $#{$_[0]->{out_data_line}}; $index1++) {
            if ($_[1] == (&change_16to10(${$_[0]->{out_data_line}}[$index1]))) {
                splice(@{$_[0]->{out_data_line}}, $index1, 1);
                splice(@{$_[0]->{out_data}}, $index1, 1);
                return;
            }
        }
    }
    return;
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
    #      ： $_[1～]= ユーザー引数                                                           #
    # 処理 ： ユーザー関数の呼出し                                                            #
    # 返却 ： ユーザー関数が返却した抽出対象区分                                              #
    #-----------------------------------------------------------------------------------------#
    my $obj    = shift;
    my $extraction_data = "";
    
    foreach (@_) {
        # ユーザー関数の呼出し
        $obj->{seek_index} = 0;
        seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1]), 0 or "$!($obj->{in_name})";
        my $user_sub = '&'.${$_}[1].'('."\"$obj->{line_now}\"";
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
