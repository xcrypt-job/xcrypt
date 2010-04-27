############################################
# ＜＜入力データ生成＞＞                   #
# Ver=0.3 2010/02/04                       #
############################################
package data_generator;
use strict;
use File::Spec;
use File::Basename;
use Cwd;

###################################################################################################
#   ＜＜ 置換えファイル定義 ＞＞                                                                  #
###################################################################################################
sub new{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = クラス名                                                                #
    #         $_[1] = 雛形ファイル名                                                          #
    #         $_[2] = 生成ファイル格納ディレクトリ名                                          #
    # 処理 ： オブジェクト定義（置換えファイル定義）                                          #
    # 返却 ： オブジェクト                                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my $class             = shift;                                                            # クラス名
    my $infile            = shift;                                                            # 雛形ファイル名
    my $outdir            = shift;                                                            # 生成ファイル格納ディレクトリ名
    my $outfile           = File::Spec->catfile("$outdir", (basename($infile)));              # 生成ファイル名
    my @replace_datas     = ();                                                               # 置換え情報(配列)
    my @insert_datas      = ();                                                               # 挿入情報(配列)
    my $value_options_all = undef;                                                            # 標準表示書式
    
    ####################
    # ファイルチェック #
    ####################
    # 雛形ファイルチェック
    if (!-e "$infile") {
        # ファイル無し
        print STDERR "Input file($infile) not found\n";
        exit 99;
    } elsif (!-r "$infile") {
        # ファイルに読込み権限無し
        print STDERR "Input file($infile) is not read authority\n";
        exit 99;
    }
    # 生成ファイルチェック
    if (!-d "$outdir") {
        # ディレクトリ無し
        print STDERR "Output file directory($outdir) not found\n";
        exit 99;
    } elsif (!-w "$outdir") {
        # ディレクトリに書込み権限無し
        print STDERR "Output file directory($outdir) is not write authority\n";
        exit 99;
    } elsif (-e "$outfile" and !-w "$outfile") {
        # ファイルに書込み権限無し
        print STDERR "Output file($outfile) is not write authority\n";
        exit 99;
    }
    
    ####################
    # オブジェクト定義 #
    ####################
    my $job = {"infile"            =>$infile,                                                 # 雛形ファイル名
               "outfile"           =>$outfile,                                                # 生成ファイル名
               "replace_datas"     =>\@replace_datas,                                         # 置換え情報
               "insert_datas"      =>\@insert_datas,                                          # 挿入情報
               "value_options_all" =>$value_options_all};                                     # 標準表示書式
    return bless $job, $class;
}
###################################################################################################
#   ＜＜ 変数名指定によるデータ置換え ＞＞                                                        #
###################################################################################################
sub replace_key_value{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #         $_[1] = 変数名                                                                  #
    #         $_[2] = 置換え文字列                                                            #
    #         $_[3] = 文字列表示書式                                                          #
    # 処理 ： 変数名チェック、配列登録                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my $self   = shift;                                                                       # オブジェクト
    my $key    = shift;                                                                       # 変数名
    my $value  = shift;                                                                       # 置換え文字列
    my $format = shift;                                                                       # 文字列表示書式
    
    # 変数名チェック
    &check_key_name("$key");
    
    ############
    # 配列登録 #
    ############
    my %replace_data       = ();
    $replace_data{'key'}   = "$key";
    $replace_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{replace_datas}}, \%replace_data);
}
###################################################################################################
#   ＜＜ 行・列番号指定による文字列置換え ＞＞                                                    #
###################################################################################################
sub replace_line_column{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #         $_[1] = 行番号                                                                  #
    #         $_[2] = 列番号                                                                  #
    #         $_[3] = 置換え文字列                                                            #
    #         $_[4] = 文字列表示書式                                                          #
    # 処理 ： 行番号チェック、文字列番号チェック、配列登録                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my $self   = shift;                                                                       # オブジェクト
    my $num    = shift;                                                                       # 行番号
    my $col    = shift;                                                                       # 列番号
    my $value  = shift;                                                                       # 置換え文字列
    my $format = shift;                                                                       # 文字列表示書式
    
    # 行番号チェック
    &check_number("$num", "Line");
    # 列番号チェック
    &check_number("$col", "Character string");
    
    ############
    # 配列登録 #
    ############
    my %replace_data       = ();
    $replace_data{'num'}   = "$num";
    $replace_data{'col'}   = "$col";
    $replace_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{replace_datas}}, \%replace_data);
}
###################################################################################################
#   ＜＜ 行番号指定による行置換え ＞＞                                                            #
###################################################################################################
sub replace_line{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #         $_[1] = 行番号                                                                  #
    #         $_[2] = 置換え文字列                                                            #
    #         $_[3] = 文字列表示書式                                                          #
    # 処理 ： 行番号チェック、配列登録                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my $self   = shift;                                                                       # オブジェクト
    my $num    = shift;                                                                       # 行番号
    my $value  = shift;                                                                       # 置換え文字列
    my $format = shift;                                                                       # 文字列表示書式
    
    # 行番号チェック
    &check_number("$num", "Line");
    
    ############
    # 配列登録 #
    ############
    my %replace_data       = ();
    $replace_data{'num'}   = "$num";
    $replace_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{replace_datas}}, \%replace_data);
}
###################################################################################################
#   ＜＜ 行番号指定による行挿入 ＞＞                                                              #
###################################################################################################
sub insert_line{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #         $_[1] = 行番号                                                                  #
    #         $_[2] = 置換え文字列                                                            #
    #         $_[3] = 文字列表示書式                                                          #
    # 処理 ： 行番号チェック、配列登録                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my $self   = shift;                                                                       # オブジェクト
    my $num    = shift;                                                                       # 行番号
    my $value  = shift;                                                                       # 置換え文字列
    my $format = shift;                                                                       # 文字列表示書式
    
    # 行番号チェック
    &check_number("$num", "Line");
    
    ############
    # 配列登録 #
    ############
    my %insert_data       = ();
    $insert_data{'num'}   = "$num";
    $insert_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{insert_datas}}, \%insert_data);
}
###################################################################################################
#   ＜＜ 標準表示書式指定 ＞＞                                                                    #
###################################################################################################
sub set_default_format{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    #         $_[1] = 標準表示書式                                                            #
    # 処理 ： 標準表示書式を登録                                                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my $self   = shift;                                                                       # オブジェクト
    my $format = shift;                                                                       # 文字列表示書式
    
    ############
    # 情報登録 #
    ############
    $self->{value_option_all} = "$format";
}
###################################################################################################
#   ＜＜ 置換え ＞＞                                                                              #
###################################################################################################
sub execute{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = オブジェクト                                                            #
    # 処理 ： 雛形ファイルを指示に従い変換し、生成ファイルへ出力                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my $self      = shift;                                                                    # オブジェクト
    my $in_cnt    = 0;                                                                        # 入力行番号
    my $rep_data  = undef;                                                                    # 置換え対象データ
    my $out_data  = '';                                                                       # 置換え後データ
    
    ################
    # ファイルOPEN #
    ################
    # 雛形ファイルOPEN
    if (!open (BASE_FILE, "< $self->{infile}")) {
        # ファイルOPENエラー
        print STDERR "Input file($self->{infile}) cannot open file\n";
        exit 99;
    }
    # 雛形ファイルの共用ロック
    flock(BASE_FILE, 1);
    # 生成ファイルOPEN
    if (!open (CREATE_FILE, "+> $self->{outfile}")) {
        # ファイルOPENエラー
        print STDERR "Output file($self->{outfile}) cannot open file\n";
        exit 99;
    }
    # 生成ファイルの排他ロック
    flock(CREATE_FILE, 2);
    
    ##################
    # Insert/Replace #
    ##################
    while (my $in_data = <BASE_FILE>){
        $in_cnt++;
        $rep_data = "$in_data";
        # 改行コードを削除
        if ((substr $in_data, -1) eq "\n") {
            chomp $rep_data;
        }
        ### Insert ###
        foreach my $insert_data(@{$self->{insert_datas}}) {
            if ((exists $insert_data->{num}) and $in_cnt == $insert_data->{num}) {
                #============#
                # 行挿入対象 #
                #============#
                $out_data = &value_evaluation("$insert_data->{value}", "$self->{value_option_all}");
                print CREATE_FILE "$out_data\n";
            }
        }
        ### Replace ###
        foreach my $replace_data(@{$self->{replace_datas}}) {
            my @out_datas1 = ();
            my @out_datas2 = ();
            
            # 置換え処理の振分け
            if ((exists $replace_data->{num}) and $in_cnt == $replace_data->{num}) {
                #====================#
                # 行指定による置換え #
                #====================#
                if (!exists $replace_data->{col}) {
                    #----------#
                    # 行置換え #
                    #----------#
                    $rep_data = $replace_data->{value};
                } else {
                    #--------------#
                    # 文字列置換え #
                    #--------------#
                    # スペース、タブ、改行区切りでデータ分割
                    @out_datas1 = split /\s+\,*\s*|\,+\s*/, $rep_data;
                    if ($out_datas1[($replace_data->{col} - 1)] eq '') {
                        next;
                       #print STDERR "Replace Data Not Found(Line=$replace_data->{num} Colum=$replace_data->{col})\n";
                       #exit 99;
                    }
                    my $out_datas1_su = @out_datas1;
                    # ターゲット文字列でデータ分割
                    my $out_datas2_first = undef;
                    my $out_datas2_last  = undef;
                    my $split_col = $replace_data->{col} - 1;
                    if ($replace_data->{col} eq 1) {
                        @out_datas2 = split /($out_datas1[$split_col]\s|$out_datas1[$split_col]\,)/, $rep_data, 2;
                        $out_datas2_first = '';
                        $out_datas2_last  = substr $out_datas2[1], -1;
                    } elsif ($replace_data->{col} < $out_datas1_su) {
                        @out_datas2       = split /(\s$out_datas1[$split_col]\s|\,$out_datas1[$split_col]\,|\s$out_datas1[$split_col]\s|\,$out_datas1[$split_col]\s)/, $rep_data, 2;
                        $out_datas2_first = substr $out_datas2[1], 0, 1;
                        $out_datas2_last  = substr $out_datas2[1], -1;
                    } else {
                        @out_datas2       = split /\s$out_datas1[$split_col]\n|\,$out_datas1[$split_col]\n/, $rep_data, 2;
                        $out_datas2_first = substr $out_datas2[1], 0, 1;
                        $out_datas2_last  = '';
                        $out_datas2[2]    = '';
                    }
                    # 文字列置換え
                    $rep_data = $out_datas2[0].$out_datas2_first.$replace_data->{value}.$out_datas2_last.$out_datas2[2];
                }
            } elsif (exists $replace_data->{key}) {
                #======================#
                # 変数指定による置換え #
                #======================#
                # 変数名でデータ分割
                my $set_name = '';
                my @key_datas = split /([\(\)\:])/, $replace_data->{key};
                if ("$key_datas[0]" ne "$replace_data->{key}") {
                    foreach my $key_data(@key_datas) {
                        if ("$key_data" eq "\(") {
                            $set_name .= "\\(";
                        } elsif ("$key_data" eq "\)") {
                            $set_name .= "\\)";
                        } elsif ("$key_data" eq "\:") {
                            $set_name .= "\\:";
                        } else {
                            $set_name .= "$key_data";
                        }
                    }
                } else {
                    $set_name = $replace_data->{key};
                }
                @out_datas1 = split /(${set_name}\s+=\s*|${set_name}=\s*)/, "$rep_data", 2;
                
                # 文字列置換え
                if ($out_datas1[0] ne $rep_data and ($out_datas1[0] eq '' or (substr $out_datas1[0], -1) eq ' ' or (substr $out_datas1[0], -1) eq ',')) {
                    #----------------#
                    # 該当変数名あり #
                    #----------------#
                    # 文字定数かチェック
                    if ($out_datas1[2] =~ /^[\"\']/) {
                        #･･････････････#
                        # クォートあり #
                        #･･････････････#
                        my $out_quote = substr $out_datas1[2], 0, 1;
                        $out_data     = substr $out_datas1[2], 1;
                        chomp $out_data;
                        @out_datas2 = split /($out_quote\s|$out_quote\,)/, "$out_data", 2;
                        $out_data   = $out_datas1[0].$out_datas1[1].$out_quote.$replace_data->{value}.$out_quote;
                    } else {
                        #･･････････････#
                        # クォートなし #
                        #･･････････････#
                        @out_datas2 = split /(,|\s)/, "$out_datas1[2]", 2;
                        if ($replace_data->{value} =~ /^\((.*)\)$/) {
                            # （カッコあり(複素数)）
                            my @out_datas3 = split /(\s+\,*\s*|\,+\s*)/, $1;
                            $out_data      = $out_datas1[0].$out_datas1[1].'(';
                            for (my $index2=0; $index2 <= $#out_datas3; $index2++) {
                                if (($index2%2 ? "1" : "2") == 2) {
                                    if ($out_datas3[$index2] =~ /^[\+-]*\d+\.*\d*[DdEeQq\+-_]*\d*$|^[\+-]*\.\d*[DdEeQq\+-_]*\d*$/) {
                                        $out_data .= $out_datas3[$index2];
                                    } else {
                                        $out_data .= '"'.$out_datas3[$index2].'"';
                                    }
                                } else {
                                    $out_data .= $out_datas3[$index2];
                                }
                            }
                            $out_data .= ')';
                        } else {
                            # （カッコなし(実数、単精度実数、倍精度実数、8バイト整数)）
                            if ($replace_data->{value} =~ /^[\+-]*\d+\.*\d*[DdEeQq\+-_]*\d*$|^[\+-]*\.\d*[DdEeQq\+-_]*\d*$/) {
                                $out_data = $out_datas1[0].$out_datas1[1].$replace_data->{value};
                            } else {
                                $out_data = $out_datas1[0].$out_datas1[1].'"'.$replace_data->{value}.'"';
                            }
                        }
                    }
                    $out_data .= (substr $out_datas2[1], -1);
                    if ($out_datas2[2] ne '') {
                        $out_data .= $out_datas2[2];
                    }
                    $rep_data = $out_data;
                }
            }
        }
        if ((substr $in_data, -1) eq "\n") {
            $rep_data .= "\n";
        }
        
        # 雛形データに書かれた変数の評価
        $out_data = &value_evaluation("$rep_data", "$self->{value_option_all}");
        print CREATE_FILE "$out_data";
    }
    
    ################
    # ファイルOPEN #
    ################
    close(CREATE_FILE);
    close(BASE_FILE);
}
###################################################################################################
#   ＜＜ 変数名チェック ＞＞                                                                      #
###################################################################################################
sub check_key_name{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 変数名                                                                  #
    # 処理 ： 変数名チェック                                                                  #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] !~ /^[a-zA-Z]/) {
        print STDERR "There is not the top of the variable name in the alphabet ($_[0])\n";
        exit 99;
    }
}
###################################################################################################
#   ＜＜ 数字チェック ＞＞                                                                        #
###################################################################################################
sub check_number{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 行番号or列番号                                                          #
    #      ： $_[1] = チェック対象                                                            #
    # 処理 ： 数字チェック                                                                    #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] !~ /\d/ or $_[0] == 0) {
        print STDERR "$_[1] number is not a number ($_[0])\n";
        exit 99;
    }
}
###################################################################################################
#   ＜＜ 文字列の評価 ＞＞                                                                        #
###################################################################################################
sub value_evaluation{
    #-----------------------------------------------------------------------------------------#
    # 引数 ： $_[0] = 文字列                                                                  #
    #         $_[1] = 文字列表示書式                                                          #
    # 処理 ： 文字列の評価                                                                    #
    # 返却 ： 評価後の値                                                                      #
    #-----------------------------------------------------------------------------------------#
    ############
    # 変数定義 #
    ############
    my @in_values = ();                                                                       # 入力データ(配列)
    $in_values[1] = $_[0];                                                                    # 評価対象データ
    my $in_value  = undef;                                                                    # 変数名変換後入力データ
    my $in_option = $_[1];                                                                    # 文字列表示書式
    my $out_value = '';                                                                       # 評価後データ
    
    ############################
    # グローバル変数表記に変更 #
    ############################
    do {
        @in_values = split /\$/, "$in_values[1]", 2;
        $in_value .= $in_values[0];
        if ($in_values[1] ne '') {
            #==============#
            # 変数表記あり #
            #==============#
            my $in_value0_last = substr $in_values[0], -1;
            if ($in_value0_last ne '\\') {
                my @in_evaluations    = ();
                my $check_evaluation  = '';
                my $check_evaluation2 = '';
                my $check_data        = '';
                my $out_evaluation    = undef;
                my $in_value1_first   = substr $in_values[1], 0, 1;
                if ($in_value1_first eq '{') {
                    $in_values[1] = substr $in_values[1], 1;
                }
                my @in_evaluations = split /[\$\s\}\,\.\#\%\&\'\"\!\+\-\*\/\;\:\@\\\=\>\<\@\?\(\)]/, "$in_values[1]", 2;
                $check_data        = $in_evaluations[0];
                @in_evaluations    = split /$check_data/, "$in_values[1]", 2;
                my $in_evaluations1_first = substr $in_evaluations[1], 0, 1;
                if ($in_evaluations1_first eq '}') {
                    $in_evaluations[1] = substr $in_evaluations[1], 1;
                }
                $check_evaluation = '${'.$check_data.'};';
                if (eval ($check_evaluation)) {
                    #===============#
                    # local変数あり #
                    #===============#
                    $check_evaluation2 = '$out_evaluation = ${'.$check_data.'};';
                    eval ($check_evaluation2);
                    $in_value    .= $out_evaluation;
                    $in_values[1] = $in_evaluations[1];
                } else {
                    #===============#
                    # local変数なし #
                    #===============#
                    $check_evaluation2 = '$out_evaluation = ${main::'.$check_data.'};';
                    eval ($check_evaluation2);
                    $in_value    .= $out_evaluation;
                    $in_values[1] = $in_evaluations[1];
                }
            }
        }
    } while ($in_values[1] ne '');
    
    ################
    # 文字列の評価 # ※計算式の評価場所は、"%"で前後を囲ってある
    ################
    @in_values    = ();
    $in_values[1] = $in_value;
    $in_value     = undef;
    $out_value    = '';
    do {
        @in_values  = split /[\%]/, "$in_values[1]", 2;
        $out_value .= $in_values[0];
        if ($in_values[1] =~ /\%/) {
            #==============#
            # 評価対象あり #
            #==============#
            my @in_values2     = split /[\%]/, "$in_values[1]", 2;
            if ($in_values2[0] =~ /[0-9]/ and $in_values2[0] !~ /[a-zA-Z]/ and $in_values2[0] =~ /[\+\-\*\/]/) {
                #------------#
                # 計算式あり #
                #------------#
                my $rep_value      = undef;
                my $out_value_data = undef;
                if ($in_option eq '') {
                    #･･････････････#
                    # 書式指定なし #
                    #･･････････････#
                    $out_value_data = '$rep_value = sprintf '.$in_values2[0].';';
                } else {
                    #･･････････････#
                    # 書式指定あり #
                    #･･････････････#
                    $out_value_data = '$rep_value = sprintf "\%'.$in_option.'",'.$in_values2[0].';';
                }
                eval($out_value_data);
                $out_value   .= $rep_value;
                $in_values[1] = $in_values2[1];
            } else {
                #------------#
                # 計算式なし #
                #------------#
                $out_value   .= $in_values2[0];
                $in_values[1] = $in_values2[1];
            }
        } else {
            #==============#
            # 評価対象なし #
            #==============#
            $out_value   .= $in_values[1];
            $in_values[1] = '';
        }
    } while ($in_values[1] ne '');
    
    ################
    # 評価結果返却 #
    ################
    return "$out_value";
}
1;
