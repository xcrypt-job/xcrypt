package Data_Generation;
use Exporter;
@ISA = (Exporter);
@EXPORT = qw(CF $Before);
use strict;
use File::Spec;
use File::Basename;
use Cwd;

#------------< 変数の定義 >------------
my $args = undef;                                                     # アーギュメント情報
my $Before = undef;                                                   # オブジェクト名

#------------------------------------------------------------------------------#
#   ＜＜ CF(置換えファイル定義コマンド)の定義 ＞＞                             #
#------------------------------------------------------------------------------#
sub CF{
    ############################################
    # $_[0] = 雛形ファイル名                   #
    # $_[1] = 生成フォルダ名                   #
    ############################################
    my $this = (caller 1)[3];
    $this =~ s/.*:://;
    my $infile            = shift;
    my $outfile           = shift;
    my $replace           = 0;
    my @key_names         = ();
    my @line_nos          = ();
    my @line_cols         = ();
    my @value_datas       = ();
    my $value_options_all = ();
    
    # オブジェクト定義
    my $Job = {"this"              =>$this,                                    # 呼出しサブルーチン名
               "infile"            =>$infile,                                  # 雛形ファイル名
               "outfile"           =>$outfile,                                 # 生成ファイル名
               "replace"           =>$replace,                                 # 置換え配列要素数
               "key_names"         =>\@key_names,                              # 変数名指定置換え用の変数名（配列）
               "line_nos"          =>\@line_nos,                               # 行番号指定置換え用の行番号（配列）
               "line_cols"         =>\@line_cols,                              # 行番号指定置換え用の文字列番号（配列）
               "value_datas"       =>\@value_datas,                            # 置換え文字列（配列）
               "value_options_all" =>$value_options_all};                      # 文字列表示書式（全体）
    bless $Job;
    return $Job;
}
#------------------------------------------------------------------------------#
#   ＜＜ KR(変数名指定コマンド)の定義 ＞＞                                     #
#------------------------------------------------------------------------------#
sub KR{
    ############################################
    # $_[0] = オブジェクト                     #
    # $_[1] = 変数名                           #
    # $_[2] = 置換え文字列                     #
    # $_[3] = 文字列表示書式                   #
    ############################################
    # 変数名チェック
    if ($_[1] !~ /^[a-zA-Z]/) {
        print STDERR "There is not the top of the variable name in the alphabet \($_[1]\)\n";
        exit 99;
    }
    
    # 配列に格納
    $_[0]->{replace}++;
    my @key_names = @{$_[0]->{key_names}};
    $key_names[$_[0]->{replace}] = $_[1];
    @{$_[0]->{key_names}} = @key_names;
    my @value_datas = @{$_[0]->{value_datas}};
    $value_datas[$_[0]->{replace}] = &Value_Evaluation("$_[2]", "$_[3]");
    @{$_[0]->{value_datas}} = @value_datas;
}
#------------------------------------------------------------------------------#
#   ＜＜ LR(行・文字列番号(ｎ番目)指定コマンド)の定義 ＞＞                     #
#------------------------------------------------------------------------------#
sub LR{
    ############################################
    # $_[0] = オブジェクト                     #
    # $_[1] = 行番号                           #
    # $_[2] = 文字列番号                       #
    # $_[3] = 置換え文字列                     #
    # $_[4] = 文字列表示書式                   #
    ############################################
    # 行番号チェック
    if ($_[1] !~ /\d/ or $_[1] == 0) {
        print STDERR "Line number is not a number \($_[1]\)\n";
        exit 99;
    }
    # 文字列番号チェック
    if ($_[2] !~ /\d/ or $_[2] == 0) {
        print STDERR "Character string number is not a number \($_[2]\)\n";
        exit 99;
    }
    
    # 配列に格納
    $_[0]->{replace}++;
    my @line_nos = @{$_[0]->{line_nos}};
    $line_nos[$_[0]->{replace}] = $_[1];
    @{$_[0]->{line_nos}} = @line_nos;
    my @line_cols = @{$_[0]->{line_cols}};
    $line_cols[$_[0]->{replace}] = $_[2];
    @{$_[0]->{line_cols}} = @line_cols;
    my @value_datas = @{$_[0]->{value_datas}};
    $value_datas[$_[0]->{replace}] = &Value_Evaluation("$_[3]", "$_[4]");
    @{$_[0]->{value_datas}} = @value_datas;
}
#------------------------------------------------------------------------------#
#   ＜＜ CO(ベース文字列表示書式指定コマンド)の定義 ＞＞                       #
#------------------------------------------------------------------------------#
sub CO{
    ############################################
    # $_[0] = オブジェクト                     #
    # $_[1] = 文字列表示書式                   #
    ############################################
    $_[0]->{value_option_all} = $_[1];
}
#------------------------------------------------------------------------------#
#   ＜＜ do(置換え指示コマンド)の定義 ＞＞                                     #
#------------------------------------------------------------------------------#
sub do{
    ############################################
    # 引数なし                                 #
    ############################################
    my @key_names     = @{$_[0]->{key_names}};
    my @line_nos      = @{$_[0]->{line_nos}};
    my @line_cols     = @{$_[0]->{line_cols}};
    my @value_datas   = @{$_[0]->{value_datas}};
    
    # 雛形ファイルOPEN
    if (!-e "$_[0]->{infile}") {
        # 入力ファイル無し
        print STDERR "Input file($_[0]->{infile}) not found\n";
        exit 99;
    } elsif (!-r "$_[0]->{infile}") {
        # 入力ファイルに読込み権限無し
        print STDERR "Input file($_[0]->{infile}) is not read authority\n";
        exit 99;
    } elsif (!open (BASE_FILE, "< $_[0]->{infile}")) {
        # 入力ファイルOPENエラー
        print STDERR "Input file($_[0]->{infile}) cannot open file\n";
        exit 99;
    }
    # 雛形ファイルの共用ロック
    flock(BASE_FILE, 1);
    
    # 生成ファイルOPEN
    my $outfile = File::Spec->catfile("$_[0]->{outfile}", (basename($_[0]->{infile})));
    if (!-d "$_[0]->{outfile}") {
        # 出力ディレクトリ無し
        print STDERR "Output file directory($_[0]->{outfile}) not found\n";
        exit 99;
    } elsif (!-w "$_[0]->{outfile}") {
        # 出力ディレクトリに書込み権限無し
        print STDERR "Output file directory($_[0]->{outfile}) is not write authority\n";
        exit 99;
    } elsif (-e "$outfile" and !-w "$outfile") {
        # 出力ファイルに書込み権限無し
        print STDERR "Output file($outfile) is not write authority\n";
        exit 99;
    } elsif (!open (CREATE_FILE, "+> $outfile")) {
        # 出力ファイルOPENエラー
        print STDERR "Output file($outfile) cannot open file\n";
        exit 99;
    }
    # 生成ファイルの排他ロック
    flock(CREATE_FILE, 2);
    
    # 雛形データを１行単位に入力
    my $line_cnt      = 0;
    my $replace_data  = undef;
    my $outfile_data  = '';
    my $outfile_quote = undef;
    while (my $line = <BASE_FILE>){
        $line_cnt++;
        $replace_data = "$line";
        if ((substr $line, -1) eq "\n") {
            chomp $replace_data;
        }
        # 行データに対して置換えを行う
        for (my $index1=0 ; $index1 <= $_[0]->{replace}; $index1++) {
            my @outfile_datas1 = ();
            my @outfile_datas2 = ();
            
            # 置換え処理の判断
            if ($line_cnt == $line_nos[$index1]) {
                # ＜行指定による置換え＞
                # スペース、タブ、改行区切りでデータ分割
                @outfile_datas1 = split /\s+\,*\s*|\,+\s*/, $replace_data;
                if ($outfile_datas1[($line_cols[$index1] - 1)] eq '') {
                    print STDERR "Replace Data Not Found(Line=$line_nos[$index1] colum=$line_cols[$index1])\n";
                    exit 99;
                }
                my $outfile_datas1_su = @outfile_datas1;
                
                # ターゲット文字列でデータ分割
                my $outfile_datas2_first = undef;
                my $outfile_datas2_last  = undef;
                if ($line_cols[$index1] eq 1) {
                    @outfile_datas2 = split /($outfile_datas1[($line_cols[$index1] - 1)]\s|$outfile_datas1[($line_cols[$index1] - 1)]\,)/, $replace_data, 2;
                    $outfile_datas2_first = '';
                    $outfile_datas2_last  = substr $outfile_datas2[1], -1;
                } elsif ($line_cols[$index1] < $outfile_datas1_su) {
                    @outfile_datas2 = split /(\s$outfile_datas1[($line_cols[$index1] - 1)]\s|\,$outfile_datas1[($line_cols[$index1] - 1)]\,|\s$outfile_datas1[($line_cols[$index1] - 1)]\s|\,$outfile_datas1[($line_cols[$index1] - 1)]\s)/, $replace_data, 2;
                    $outfile_datas2_first = substr $outfile_datas2[1], 0, 1;
                    $outfile_datas2_last  = substr $outfile_datas2[1], -1;
                } else {
                    @outfile_datas2 = split /\s$outfile_datas1[($line_cols[$index1] - 1)]\n|\,$outfile_datas1[($line_cols[$index1] - 1)]\n/, $replace_data, 2;
                    $outfile_datas2_first = substr $outfile_datas2[1], 0, 1;
                    $outfile_datas2_last  = '';
                    $outfile_datas2[2] = "\n";
                }
                # 文字列置換え
                $replace_data = $outfile_datas2[0].$outfile_datas2_first.$value_datas[$index1].$outfile_datas2_last.$outfile_datas2[2];
            } elsif ($key_names[$index1] ne '') {
                # ＜変数指定による置換え＞
                # 変数名でデータ分割
                my $set_name = '';
                my @key_datas = split /([\(\)\:])/, $key_names[$index1];
                if ("$key_datas[0]" ne "$key_names[$index1]") {
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
                    $set_name = $key_names[$index1];
                }
                @outfile_datas1 = split /(${set_name}\s+=\s*|${set_name}=\s*)/, "$replace_data", 2;
                
                # 文字列置換え
                if ($outfile_datas1[0] ne $replace_data and ($outfile_datas1[0] eq '' or (substr $outfile_datas1[0], -1) eq ' ' or (substr $outfile_datas1[0], -1) eq ',')) {
                    # （該当変数名あり）
                    # 文字定数かチェック
                    if ($outfile_datas1[2] =~ /^[\"\']/) {
                        # （クォートあり）
                        $outfile_quote = substr $outfile_datas1[2], 0, 1;
                        $outfile_data = substr $outfile_datas1[2], 1;
                        chomp $outfile_data;
                        @outfile_datas2 = split /($outfile_quote\s|$outfile_quote\,)/, "$outfile_data", 2;
                        $outfile_data = $outfile_datas1[0].$outfile_datas1[1].$outfile_quote.$value_datas[$index1].$outfile_quote;
                    } else {
                        # （クォートなし）
                        #@outfile_datas2 = split /(\s)/, "$outfile_datas1[2]", 2;
                        #if ($value_datas[$index1] =~ /\D$/) {
                        #    $outfile_data = $outfile_datas1[0].$outfile_datas1[1].'"'.$value_datas[$index1].'"';
                        #} else {
                        #    $outfile_data = $outfile_datas1[0].$outfile_datas1[1].$value_datas[$index1];
                        #}
                        @outfile_datas2 = split /(,|\s)/, "$outfile_datas1[2]", 2;
                        if ($value_datas[$index1] =~ /^[\+-]*\d+\.*\d*$/) {
                            $outfile_data = $outfile_datas1[0].$outfile_datas1[1].$value_datas[$index1];
                        } else {
                            $outfile_data = $outfile_datas1[0].$outfile_datas1[1].'"'.$value_datas[$index1].'"';
                        }
                    }
                    #if ($outfile_datas2[2] ne '') {
                    #    $outfile_data .= (substr $outfile_datas2[1], -1).$outfile_datas2[2];
                    #}
                    $outfile_data .= (substr $outfile_datas2[1], -1);
                    if ($outfile_datas2[2] ne '') {
                        $outfile_data .= $outfile_datas2[2];
                    }
                    $replace_data = $outfile_data;
                }
            }
        }
        if ((substr $line, -1) eq "\n") {
            $replace_data .= "\n";
        }
        
        # 雛形データに書かれた変数の評価
        $outfile_data = &Value_Evaluation("$replace_data", "$_[0]->{value_option_all}");
        print CREATE_FILE "$outfile_data";
    }
    close(CREATE_FILE);
    close(BASE_FILE);
}
#------------------------------------------------------------------------------#
#   ＜＜ Value_Evaluation(置換え文字列の評価コマンド)の定義 ＞＞               #
#------------------------------------------------------------------------------#
sub Value_Evaluation{
    ############################################
    # $_[0] = 値（置換え文字列 or 雛形データ） #
    # $_[1] = 文字列表示書式                   #
    ############################################
    my $in_value  = undef;
    my $in_option = $_[1];
    my $out_value = '';
    
    # グローバル変数表記に変更
    my @in_values = ();
    $in_values[1] = $_[0];
    do {
        @in_values = split /\$/, "$in_values[1]", 2;
        $in_value .= $in_values[0];
        if ($in_values[1] ne '') {
            my $in_value0_last = substr $in_values[0], -1;
            if ($in_value0_last ne '\\') {
                my @in_Evaluations = ();
                my $check_Evaluation = '';
                my $check_Evaluation2 = '';
                my $check_data = '';
                my $out_Evaluation = undef;
                my $in_value1_first = substr $in_values[1], 0, 1;
                if ($in_value1_first eq '{') {
                    $in_values[1] = substr $in_values[1], 1;
                }
                my @in_Evaluations = split /[\$\s\}\,\.\#\%\&\'\"\!\+\-\*\/\;\:\@\\\=\>\<\@\?\(\)]/, "$in_values[1]", 2;
                $check_data = $in_Evaluations[0];
                @in_Evaluations = split /$check_data/, "$in_values[1]", 2;
                my $in_Evaluations1_first = substr $in_Evaluations[1], 0, 1;
                if ($in_Evaluations1_first eq '}') {
                    $in_Evaluations[1] = substr $in_Evaluations[1], 1;
                }
                $check_Evaluation = '${'.$check_data.'};';
                if (eval ($check_Evaluation)) {
                    $check_Evaluation2 = '$out_Evaluation = ${'.$check_data.'};';
                    eval ($check_Evaluation2);
                    $in_value .= $out_Evaluation;
                    $in_values[1] = $in_Evaluations[1];
                } else {
                    $check_Evaluation2 = '$out_Evaluation = ${main::'.$check_data.'};';
                    eval ($check_Evaluation2);
                    $in_value .= $out_Evaluation;
                    $in_values[1] = $in_Evaluations[1];
                }
            }
        }
    } while ($in_values[1] ne '');
    
    # 置換え文字列の評価
    @in_values = ();
    $in_values[1] = $in_value;
    $in_value = undef;
    $out_value = '';
    do {
        @in_values = split /[\%]/, "$in_values[1]", 2;
        $out_value .= $in_values[0];
        if ($in_values[1] =~ /\%/) {
            my @in_values2 = split /[\%]/, "$in_values[1]", 2;
            if ($in_values2[0] =~ /[0-9]/ and $in_values2[0] !~ /[a-zA-Z]/ and $in_values2[0] =~ /[\+\-\*\/]/) {
                my $rep_value = undef;
                my $out_value_data = undef;
                if ($in_option eq '') {
                    $out_value_data = '$rep_value = sprintf '.$in_values2[0].';';
                } else {
                    $out_value_data = '$rep_value = sprintf "\%'.$in_option.'",'.$in_values2[0].';';
                }
                eval($out_value_data);
                $out_value .= $rep_value;
                $in_values[1] = $in_values2[1];
            } else {
                $out_value .= $in_values2[0];
                $in_values[1] = $in_values2[1];
            }
        } else {
            $out_value .= $in_values[1];
            $in_values[1] = '';
        }
    } while ($in_values[1] ne '');
    
    return "$out_value";
}
1;
