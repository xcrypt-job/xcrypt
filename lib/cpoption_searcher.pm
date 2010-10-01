package cpoption_searcher;

use strict;
use builtin;
use File::Spec;
use Time::HiRes;
use Coro;
use Coro::Channel;

my  $matrix_file_name      = 'matrixfile';                                                    # マトリックスファイル名（排他・誘導等を定義したファイル）
my  $output_file_name      = 'seacher_result';                                                # 結果出力ファイル名
my  $compile_comand        = 'gcc';                                                           # コンパイルコマンド
my  $slp                   = 1;                                                               # sleep秒
my  $extraction_cond       = 1;                                                               # 抽出条件（1＝最上位、2＝上位２、3＝上位３）
my  $measurement_list      = 10;                                                              # 出力件数
my  $user_conditional      = '1';                                                             # ユーザー指定抽出条件 (and if条件文)
my  $measurement_time      = 'med';                                                           # 計測条件（max＝最大、min＝最小、med＝中間、avg＝平均）
my  $measurement_cnt       = 1;                                                               # 計測回数
my  @compile_keys          = ();                                                              # ユーザースクリプト内コンパイル文指定キー(compile1,compile2)
my  %templetes             = ();                                                              # ユーザースクリプト定義情報

my  $default_pattern_file_name = 'defaultfile';                                               # 初期パターンファイル名
my  $default_matrix_file_name  = $matrix_file_name;                                           # 初期マトリックスファイル名（排他・誘導等を定義したファイル）
my  $defalut_output_file_name  = $output_file_name;                                           # 初期結果出力ファイル名
my  $defalut_compile_comand    = $compile_comand;                                             # 初期コンパイルコマンド
my  $defalut_extraction_cond   = $extraction_cond;                                            # 初期抽出条件（1＝最上位、2＝上位２、3＝上位３）
my  $defalut_measurement_list  = $measurement_list;                                           # 初期出力件数
my  $defalut_user_conditional  = $user_conditional;                                           # 初期ユーザー指定抽出条件 (and if条件文)
my  $defalut_measurement_time  = $measurement_time;                                           # 初期計測条件（max＝最大、min＝最小、med＝中間、avg＝平均）
my  $defalut_measurement_cnt   = $measurement_cnt;                                            # 初期計測回数

our @compile_options       = ();                                                              # オプション情報（[オプション名,オプションデータ1,オプションデータ2,･･･]）
our %compile_patterns      = ();                                                              # パターン情報（key=オプションID、data=[オプションidx1,オプションidx2,･･･]）
my  %next_compile_patterns = ();                                                              # 次レベルへ引渡すパターン(key=オプションID、data=[オプションidx1,オプションidx2,･･･])

my  %stop_levels           = ();                                                              # グループ中実行しないレベルリスト(key=実行レベル value=不実行レベル)
our $search_level          : shared = 0;                                                      # 実行レベル番号
my  @search_level_jobs     = ();                                                              # レベル別実行ジョブ（[オプションID,･･･]）
my  $base_option_level     = 0;                                                               # ベースオプションレベル

my  $jobseq                = 0;                                                               # ジョブシーケンス番号
my  $opid_seq              = 0;                                                               # オプションIDシーケンス情報
my  %opid_jobseqs          = ();                                                              # ジョブSEQ情報（key=オプションID、data=ジョブSEQ(１からの連番)）
my  @opids                 = ();                                                              # 実行レベルオプションID一覧
my  %child_patterns        = ();                                                              # 誘導オプション時に現在のパターンを記憶するデータ
my  @matrix_files          = ();                                                              # マトリックスファイル情報
my  %setting_options       = ();                                                              # 設定済オプション情報（key=オプションID、data=[オプション,･･･]）

my  @job_execute_times     : shared = ();                                                     # ジョブ別実行時間（data=オプションID,ジョブ名,実行レベル番号,実行時間）
my  @opid_execute_times    : shared = ();                                                     # オプションID別実行時間（data=オプションID,実行時間）

###################################################################################################
#   ＜＜ 初期処理 ＞＞                                                                            #
###################################################################################################
    $user::max_range += 2;
###################################################################################################
#   ＜＜ 設定処理 ＞＞                                                                            #
###################################################################################################
sub initialize {
    my (%script_appointments) = @_;                                                           # ユーザースクリプトinitialize定義情報
    @compile_options          = ();                                                           # オプション情報（[オプション名,オプションデータ1,オプションデータ2,･･･]）
    %compile_patterns         = ();                                                           # パターン情報（key=オプションID、data=[オプションidx1,オプションidx2,･･･]）
    @matrix_files             = ();                                                           # マトリックスファイル情報
    @search_level_jobs        = ();                                                           # レベル別実行ジョブ（key=実行レベル番号、data=[オプションID,･･･]）
    %opid_jobseqs             = ();                                                           # ジョブSEQ情報（key=オプションID、data=ジョブSEQ(１からの連番)）
    my @pattern_keys = sort (grep {$_ =~ /pattern[\d]+/} keys %script_appointments);
    my @group_keys   = sort (grep {$_ =~ /group[\d]+/} keys %script_appointments);
    my @parallel_keys = sort (grep {$_ =~ /parallel[\d]+/} keys %script_appointments);
    #-----------------------------------------------------------------------------------------#
    # コンパイルコマンド
    if (exists $script_appointments{"compile_cmd"}) {
        if ($script_appointments{"compile_cmd"} =~ /^\s+$/){
            die "error : compile_cmd is only blank\n";
        }
        $compile_comand = $script_appointments{"compile_cmd"};
    } else {
        $compile_comand = $defalut_compile_comand;
    }
    
    # マトリックスファイル名
    if (exists $script_appointments{"matrix_file"}) {
        if ($script_appointments{"matrix_file"} =~ /^\s+$/){
            die "error : matrix_file_name is only blank\n";
        }
        $matrix_file_name = $script_appointments{"matrix_file"};
    } else {
        $matrix_file_name = $default_matrix_file_name;
    }
    
    # 出力ファイル名
    if (exists $script_appointments{"output_file"}) {
        if ($script_appointments{"output_file"} =~ /^\s+$/){
            die "error : output_file_name is only blank\n";
        }
        $output_file_name = $script_appointments{"output_file"};
    } else {
        $output_file_name = $defalut_output_file_name;
    }
    
    # 抽出条件
    if (exists $script_appointments{"extraction_cond"}) {
        if ($script_appointments{"extraction_cond"} =~/\D+/){
            die "syntax error : extraction_cond\n";
        }
        $extraction_cond = $script_appointments{"extraction_cond"};
    } else {
        $extraction_cond = $defalut_extraction_cond;
    }
    
    # ユーザー抽出条件
    if (exists $script_appointments{"user_conditional"}) {
        $user_conditional = $script_appointments{"user_conditional"};
    } else {
        $user_conditional = $defalut_user_conditional;
    }
    
    # 出力件数
    if (exists $script_appointments{"out_list"}) { 
        if ($script_appointments{"out_list"} =~/\D+/){
            die "syntax error : out_list\n";
        }
        $measurement_list = $script_appointments{"out_list"};
    } else {
        $measurement_list = $defalut_measurement_list;
    }
    
    # 計測時間
    if (exists $script_appointments{"measurement_time"}) {
        if ( $script_appointments{"measurement_time"} ne "max" and
             $script_appointments{"measurement_time"} ne "min" and
             $script_appointments{"measurement_time"} ne "med" and
             $script_appointments{"measurement_time"} ne "avg" ) {
            die "error ". $script_appointments{"measurement_time"}. ": not exists in measurement_time_command\n";
        }
        $measurement_time = $script_appointments{"measurement_time"};
    } else {
        $measurement_time = $defalut_measurement_time;
    }
    
    # 計測回数
    if (exists $script_appointments{"measurement_cnt"}) {
        if ($script_appointments{"measurement_cnt"} =~/\D+/) {
            die "syntax error : measurement_cnt\n";
        }
        $measurement_cnt = $script_appointments{"measurement_cnt"};
    } else {
        $measurement_cnt = $defalut_measurement_cnt;
    }
    
    # ベースオプション
    if (exists $script_appointments{"base_option"}) {
        &add_base_option($script_appointments{"base_option"});
    } else {
        $compile_patterns{0} = [];
        $next_compile_patterns{0} = [];
    }
    
    # パターンファイルをオプション情報へ反映
    if (exists $script_appointments{"pattern_file"}) {
        &get_pattern_file_data($script_appointments{"pattern_file"});
    } else {
        &get_pattern_file_data($default_pattern_file_name);
    }
    
    # グループ指定
    foreach my $group_key (@group_keys){
        my @group_patterns = split (/,/, $script_appointments{$group_key});
        foreach my $group_pattern (@group_patterns){
            if (exists $script_appointments{"$group_pattern"}) {
                if ($script_appointments{"$group_pattern"} !~ /\}/) {
                    $script_appointments{"$group_pattern"} = $script_appointments{"$group_pattern"} . '}' .$group_key;
                } else {
                    my @pattern = &cut_group_name($script_appointments{"$group_pattern"});
                    $script_appointments{"$group_pattern"} = $pattern[0] . $group_key;
                }
            } else {
                die "error : There is not the pattern name($group_pattern) that I appointed in the group\n";
            }
        }
    }
    
    # 並列実行オプション指定 パターンにパラレル名（ex. parallel1_1）をつける
    foreach my $parallel_key (@parallel_keys) {
        my $parallel_num = 0;
        my @parallel_patterns = split (/,/, $script_appointments{$parallel_key});
        foreach my $parallel_pattern (@parallel_patterns) {
            if (exists $script_appointments{"$parallel_pattern"}) {
                $parallel_num++;
                if ($parallel_pattern=~/group[\d]+/) {
                    map {$script_appointments{$_} = $script_appointments{$_} . $parallel_key . '_' . $parallel_num; $_} grep {$script_appointments{$_} =~ /$parallel_pattern/} @pattern_keys;
                } else {
                    if ($script_appointments{"$parallel_pattern"} !~ /\}/) {
                        $script_appointments{"$parallel_pattern"} .= '}';
                    }
                    $script_appointments{"$parallel_pattern"} = $script_appointments{"$parallel_pattern"} . $parallel_key . '_' . $parallel_num;
                }
            } else {
                die "error : There is not the pattern name or group name($parallel_pattern)\n";
            }
        }
    }
    
    # ユーザー指定パターンオプションをパターン化
    foreach my $pattern_key (@pattern_keys){
        if ($script_appointments{$pattern_key} eq '' or
            $script_appointments{$pattern_key} =~ /^\s+/) {
            warn "error : There is blank in the top of $pattern_key\n";
            next;
        }
        #ユーザ指定情報を解析
        my @user_compile_options = &arrangement_compile_option($script_appointments{$pattern_key});
        # オプション情報に存在するかチェック
        my $overwrite_lv = &chk_user_compile_option(@user_compile_options);
        if ($overwrite_lv >= 0) {
            # （オプション情報に存在する）
            # 既存のグループ化を解除
            my $delete_group_name = ${$compile_options[$overwrite_lv]}[0];
            @compile_options = map {${$_}[0] =~ s/$delete_group_name//; $_;} @compile_options;
            # オプション情報を更新
            $compile_options[$overwrite_lv] = \@user_compile_options;
        } else {
            # （オプション情報に存在しない）
            # オプション情報に追加
            push (@compile_options, \@user_compile_options);
        }
    }
    
    # マトリックスファイル読み込み
    &get_matrix_file();
    
    # 設定済オプションの初期設定
    @{$setting_options{0}} = ();
    &upd_setting_option(0, 0, "", "");
    
    # 並列オプションチェック
    &chk_parallel_option();
    
    # 同レベル等価オプションチェック
    &chk_exists_option();
    
    # グループ化整合性チェック
    &chk_group_consistency();
    
    # 排他オプションのグループ化
    &grouping_exclusion_option();
    
    # 同時実行オプションのグループ化
    &grouping_simultaneous_option();
    
    # 順序指定オプションによる並び替え
    &sort_compile_option();
    
    # 対になるオプションの追加
    &add_opposite_option();
    
    # 並列オプションの並び替え
    &sort_parallel_option(@parallel_keys);
    
    # オプション情報の並び換え
    &sort_group_option();
}
###################################################################################################
#   ＜＜ ベースオプション追加 ＞＞                                                                #
###################################################################################################
sub add_base_option {
    my ($base_option_str) = @_;
    my @base_options      = split (/\s/,$base_option_str);
    my @base_patterns     = ();
    %setting_options      = ();
    #-----------------------------------------------------------------------------------------#
    # ベースオプションを追加
    foreach my $base_option (@base_options) {
        push (@compile_options, ['',$base_option]);
        push (@base_patterns, 1);
        &upd_setting_option(0, "", "$base_option");
    }
    unshift (@base_patterns, '');
    $compile_patterns{0} = \@base_patterns;
    $next_compile_patterns{0} = \@base_patterns;
    
    # ベースオプション数を設定
    $base_option_level = @base_options;
    
    # search_levelを設定
    $search_level = $base_option_level;
}
###################################################################################################
#   ＜＜ パターンファイル情報取得 ＞＞                                                            #
###################################################################################################
sub get_pattern_file_data {
    my ($pattern_file_name) = @_;                                                             # パターンファイル名
    my %group_options       = ();                                                             # グループ情報（key=グループ名、data=グループ化する数）
    #-----------------------------------------------------------------------------------------#
    # OPEN
    open (PATTERN, "< $pattern_file_name") or die "get_pattern_file_data:Cannot open  $pattern_file_name";
    # パターンファイル情報を取得
    while (my $line = <PATTERN>) {
        if ($line =~ /^\#/) { next; }
        chomp $line;
        if ($line =~ /^[\s\t]*$/) { next; }
        if ($line =~ /^END$/) { last; }
        &chk_pattern_file($pattern_file_name, $line);
        # パターンをパターンファイル情報へ追加
        my @line_compile_options = &arrangement_compile_option($line);
        if ($line_compile_options[0] ne '') {
            $group_options{$line_compile_options[0]}++;
        }
        push (@compile_options, \@line_compile_options);
    }
    # CLOSE
    close(PATTERN);
    
    # グループ化正しいかチェック
    my $group_idx = 0;
    foreach my $group_option_key (keys %group_options) {
        if ($group_options{$group_option_key} == 1) {
            warn "$group_option_key is not group\n";
            @compile_options = map {${$_}[0] =~ s/$group_option_key//; $_;} @compile_options;
        } else {
            # グループ名をパターンファイルグループに統一
            $group_idx++;
            @compile_options = map {${$_}[0] =~ s/$group_option_key/pattern_file_group$group_idx/; $_;} @compile_options;
        }
    }
}
###################################################################################################
#   ＜＜ パターンファイル内コンパイルオプション構文チェック ＞＞                                  #
###################################################################################################
sub chk_pattern_file {
    my ($pattern_file_name, $compile_option_str) = @_;                                        # 配列化前コンパイルオプション
    #-----------------------------------------------------------------------------------------#
    unless ($compile_option_str =~ /^-[A-Za-z][^\s\r\{\}\[\]\(\)]*\{[^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
            $compile_option_str =~ /^-\{[A-Za-z][^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
            $compile_option_str =~ /^\{-[A-Za-z][^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
            $compile_option_str =~ /^-[A-Za-z][^\s\r\{\}\[\]]*$/ ) {
        die "syntax error : $pattern_file_name\n";
    }
}
###################################################################################################
#   ＜＜ パターンを配列化 ＞＞                                                                    #
###################################################################################################
sub arrangement_compile_option {
    my ($line)    = @_;                                                                       # 解析対象文字列
    my @arrangement_lines = ();                                                               # 解析結果（配列）
    #-----------------------------------------------------------------------------------------#
    # パターンからグループ名を切り出す
    my ($line_str, $group_name) = &cut_group_name($line);
    
    # パターンを配列化
    @arrangement_lines = &cut_space(split (/[{|}]/, $line_str));
    if ($arrangement_lines[$#arrangement_lines] eq '') {pop (@arrangement_lines);}
    foreach my $i (1..$#arrangement_lines) {
        $arrangement_lines[$i] = $arrangement_lines[0].$arrangement_lines[$i];
    }
    if ($#arrangement_lines == 0) {
        $arrangement_lines[1] = $arrangement_lines[0];
    }
    
    # グループ名を設定
    $arrangement_lines[0] = $group_name;
    
    # 配列化パターンを返却
    return @arrangement_lines;
}
###################################################################################################
#   ＜＜ パターンからグループ名を切り出す ＞＞                                                    #
###################################################################################################
sub cut_group_name {
    my ($line) = @_;                                                                          # 解析対象文字列
    #-----------------------------------------------------------------------------------------#
    if ($line =~ /\}([\S]+)$/) {
        my @arrangement_lines = split (/$1/, $line);
        return ($arrangement_lines[0], $1);
    } else {
        return ($line, '');
    }
}
###################################################################################################
#   ＜＜ 不要空白カット ＞＞                                                                      #
###################################################################################################
sub cut_space {
    my @arrangement_lines = @_;                                                               # 配列データ
    #-----------------------------------------------------------------------------------------#
    foreach my $i (1..$#arrangement_lines) {
        # 前後の空白をカット
        $arrangement_lines[$i] =~ s/^\s*(.*?)\s*$/$1/;
    }
    
    # 不要空白カット配列を返却
    return @arrangement_lines;
}
###################################################################################################
#   ＜＜ 上書きパターン有無チェック ＞＞                                                          #
###################################################################################################
sub chk_user_compile_option {
    my @user_compile_options = @_;                                                            # パターンファイル名
    #-----------------------------------------------------------------------------------------#
    foreach my $lv (0..$#compile_options) {
        if ($lv < $base_option_level) { next; }
        foreach my $i1 (1..$#{$compile_options[$lv]}) {
            foreach my $i2 (1..$#user_compile_options) {
                if (${$compile_options[$lv]}[$i1] eq $user_compile_options[$i2]) {
                    # ヒットしたindexを返却
                    return $lv;
                }
            }
        }
    }
    
    # 上書きパターン無しを返却
    return -1;
}
###################################################################################################
#   ＜＜ マトリクスファイル情報取得 ＞＞                                                          #
###################################################################################################
sub get_matrix_file {
    @matrix_files     = ();                                                                   # マトリクスファイル情報
    my @upper_options = ();                                                                   # 継承関係オプション情報（data＝[オプション,･･･]）
    my %count = ();                                                                           # マトリックスファイル行の重複チェック
    #-----------------------------------------------------------------------------------------#
    # 誘導オプション 「-O,+(-a,-b,-c)」
    # 排他オプション 「-O,-(-d,-e)」
    # OPEN
    open (MATRIX, "< $matrix_file_name") or die "get_matrix_file:Cannot open $matrix_file_name";
    # マトリクスファイル情報を取得
    while (my $line = <MATRIX>) {
        if ($line =~ /^\#/) { next; }
        chomp $line;
        if (++$count{$line} >= 2) { next; }
        $line =~ s/=\*/=.+/g;
        if ($line =~ /^[\s\t]*$/) { next; }
        if ($line =~ /^-[A-Za-z].*<.+$/) {
            push (@upper_options, [split (/</, $line)]);
            push (@matrix_files, ["","",split (/</, $line)]);
        } elsif ($line =~ /^\([^\{\}\[\]\(\)]+\)\,\+\([^\{\}\[\]\(\)]+\)$/) {
            my @matrixs = grep {$_ ne ''} &cut_space(split (/[\,\(\)]/, $line));
            my @new_matrixs = ();
            $new_matrixs[0] = [$matrixs[0],$matrixs[1]];
            @new_matrixs = (@new_matrixs, @matrixs[2..$#matrixs]);
            if ($new_matrixs[$#new_matrixs] eq '') {pop (@new_matrixs);}
            push (@matrix_files, \@new_matrixs);
        } elsif ($line =~ /(^-[A-Za-z][^\s\r\{\}\[\]\(\)]*|^)\,(\+|-|&|=|=>)\([^\{\}\[\]\(\)]+\)$/) {
            my @matrixs = &cut_space(split (/[\,\(\)]/, $line));
            if ($matrixs[$#matrixs] eq '') {pop (@matrixs);}
            push (@matrix_files, \@matrixs);
        } else {
             die "get_matrix_file : syntax error matrix_file($line) \n";
        }
    }
    # CLOSE
    close(MATRIX);
    
    # 継承関係を追加マトリックスファイル情報に反映
    my @add_matrix_files;
    foreach my $matrix_file (grep {${$_}[0] ne '' and ${$_}[1] ne ''} @matrix_files) {
        foreach my $upper_option (@upper_options) {
            my $start_idx_left = -1;
            my $start_idx_right = -1;
            foreach my $i (0..$#{$upper_option}){
                if (${$matrix_file}[0] eq ${$upper_option}[$i]) {
                    $start_idx_left = $i+1;
                    last;
                } elsif (${$matrix_file}[2] eq ${$upper_option}[$i] and ${$matrix_file}[1] eq '&') {
                    $start_idx_right = $i+1;
                    last;
                }
            }
            if ($start_idx_left != -1) {
                foreach my $upper_idx ($start_idx_left..$#{$upper_option}) {
                    my @temp_matrix_data = @{$matrix_file};
                    my @upper_matrix_files = grep {${$_}[0] eq ${$upper_option}[$upper_idx] and
                                                                     ${$_}[1] eq $temp_matrix_data[1]} @matrix_files;
                    # 対になるオプションの検索
                    if (&chk_opposite_option(\@temp_matrix_data, \@upper_matrix_files)) {
                        last;
                    }
                    $temp_matrix_data[0] = ${$upper_option}[$upper_idx];
                    push (@add_matrix_files, \@temp_matrix_data);
                }
            } elsif ($start_idx_right != -1) {
                foreach my $upper_idx ($start_idx_right..$#{$upper_option}) {
                    my @temp_matrix_data = @{$matrix_file};
                    
                    my @upper_matrix_files = grep {${$_}[2] eq ${$upper_option}[$upper_idx] and
                                                                     ${$_}[1] eq '&'} @matrix_files;
                    # 対になるオプションの検索
                    if (&chk_opposite_option(\@temp_matrix_data, \@upper_matrix_files)) {
                        last;
                    }
                    $temp_matrix_data[2] = ${$upper_option}[$upper_idx];
                    push (@add_matrix_files, \@temp_matrix_data);
                }
            }
        }
    }
    
    # 追加マトリックスファイル情報をマトリックスファイル情報へ追加
    push (@matrix_files, @add_matrix_files);
}
###################################################################################################
#   ＜＜ 対になるオプションの検索 ＞＞                                                            #
###################################################################################################
sub chk_opposite_option {
    my ($temp_matrix_data, $upper_matrix_files) = @_;
    #-----------------------------------------------------------------------------------------#
    foreach my $upper_matrix_file (@{$upper_matrix_files}) {
        foreach my $option (@{$temp_matrix_data}[2..$#{$temp_matrix_data}]) {
            if (grep {&compare_opposite_option($_, $option ) or
                         &compare_opposite_option($option, $_)} @{$upper_matrix_file}[2..$#{$upper_matrix_file}]) {
                return 1;
            }
        }
    }
    return 0;
}
###################################################################################################
#   ＜＜ 対になるオプションの文字列比較 ＞＞                                                      #
###################################################################################################
sub compare_opposite_option {
    my ($compile_option, $check_option) = @_;                                                 # チェック対象オプション、チェックオプション
    my @compile_options = split (/=/, $compile_option);                                       # チェック対象オプション（＝以降をカット）
    my @check_options   = split (/=/, $check_option);                                         # チェックオプション（＝以降をカット）
    #-----------------------------------------------------------------------------------------#    
    # チェック対象かチェック
    if ($compile_option eq $check_option) {
        # （同一オプションを検出）
        return 0;
    } elsif ($compile_option =~ /\=\.\+$/ or $check_option =~ /\=\.\+$/) {
        # （チェック対象外）
        return 0;
    }
    
    # 文字列分割し、正規表現を生成
    my $search_str = '';
    foreach my $compile_option_char (split (//, $compile_options[0])) {
        if ($search_str ne '^') { $search_str .= '(no|no_){0,1}'; }
        $search_str .= $compile_option_char;
    }
    $search_str .= '$';
    
    # 対になるオプションかチェック
    if ($check_options[0] =~ /$search_str/) {
        # （対になるオプションを検出）
        return 1;
    } else {
        # （対になるオプションでない）
        return 0;
    }
}
###################################################################################################
#   ＜＜ 並列オプションチェック ＞＞                                                            #
###################################################################################################
sub chk_parallel_option {
    #-----------------------------------------------------------------------------------------#
    # 並列化したいオプションの中に同時実行オプションがあるかチェック
    my @check_compile_options = grep {${$_}[0] =~ /parallel[\d]+_/} @compile_options;
    foreach my $matrix_file (grep {${$_}[1] =~ /[&-]/} @matrix_files) {
        my @matched_lvs = ();
        foreach my $matrix (@{$matrix_file}) {
            push (@matched_lvs, grep {grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$check_compile_options[$_]}} 0..$#check_compile_options);
        }
        my %parallel_names = ();
        grep {$parallel_names{${$check_compile_options[$_]}[0]}++} @matched_lvs;
        
        # 並列オプション間で同時実行オプションが存在した場合警告＆無効
        if (keys %parallel_names >= 2) {
            my %count = ();
            grep {$parallel_names{$_} =~ /(parallel[\d]+_)/; $count{$1}++;} keys %parallel_names;
            if (${$matrix_file}[1] eq '-' and keys %count <= 2) {
                next;
            }
            warn "can't parallel\n";
            foreach my $parallel_name (keys %parallel_names) {
                @compile_options = map {${$_}[0] =~ s/$parallel_name//g; $_} @compile_options;
            }
        }
    }
}
###################################################################################################
#   ＜＜ 同レベル等価オプションチェック ＞＞                                                      #
###################################################################################################
sub chk_exists_option {
    #-----------------------------------------------------------------------------------------#
    # 同レベルに等価オプションがあるかチェック
    foreach my $matrix_file (grep {${$_}[1] =~ /^=$/} @matrix_files) {
        foreach my $lv (0..$#compile_options) {
            if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) > 0) {
                my @temp_compile_options = (${$compile_options[$lv]}[0]);
                foreach my $op (1..$#{$compile_options[$lv]}) {
                    my $option = ${$compile_options[$lv]}[$op];
                    if ((grep {$option =~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]) == 0) {
                        push (@temp_compile_options, $option);
                    }
                }
                @{$compile_options[$lv]} = @temp_compile_options;
            }
        }
    }
}
###################################################################################################
#   ＜＜ グループ化整合性チェック ＞＞                                                            #
###################################################################################################
sub chk_group_consistency {
    my $group_name = 'add_group';                                                             # グループ名Prefix
    my $group_idx  = 0;                                                                       # グループindex
    #-----------------------------------------------------------------------------------------#
    # マトリックス通りにグループ化した場合の整合性チェック
    foreach my $matrix_file (grep {${$_}[1] =~ /[&-]/} @matrix_files) {
        my $root_level = -1;
        
        # 基点となるオプションの検索
        foreach my $lv (0..$#compile_options) {
            if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) > 0) {
                $root_level = $lv;
            }
        }
        
        # 対象となるオプションの検索
        if ( $root_level != -1 ) {
            my @matched_lvs = ();
            foreach my $lv (0..$#compile_options) {
                if (${$matrix_file}[1] eq '&' and $root_level > $lv) { next; }
                foreach my $i (2..$#{$matrix_file}){
                    if ((grep {$_ =~ /(^|\s)${$matrix_file}[$i]($|\s)/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) > 0) {
                        push (@matched_lvs, $lv);
                    }
                }
            }
            
            if (@matched_lvs != ()) {
                #ルートを含め対象オプションが見つかったレベルに対しグループ名を付ける
                $group_idx++;
                unshift (@matched_lvs, $root_level);
                foreach my $lv (@matched_lvs) {
                    if (${$compile_options[$lv]}[0] ne '') {
                        my $old_group_name = ${$compile_options[$lv]}[0];
                        if ($old_group_name =~ /(parallel[\d]+_[\d])$/) {
                            my $parallel_name = $1;
                            @compile_options = map {${$_}[0] =~ s/$old_group_name/$group_name$group_idx$parallel_name/; $_;} @compile_options;
                        } else {
                            @compile_options = map {${$_}[0] =~ s/$old_group_name/$group_name$group_idx/; $_;} @compile_options;
                        }
                    } else {
                        if (${$compile_options[$lv]}[0]=~ /(parallel[\d]+_[\d])$/) {
                            ${$compile_options[$lv]}[0] = "$group_name$group_idx" . $1;
                        } else {
                            ${$compile_options[$lv]}[0] = "$group_name$group_idx";
                        }
                    }
                }
            }
        }
    }
}
###################################################################################################
#   ＜＜ 排他オプショングループ化展開 ＞＞                                                        #
###################################################################################################
sub grouping_exclusion_option {
    #-----------------------------------------------------------------------------------------#
    #探索パターンに排他オプションがあるか検索してグループ化
    foreach my $matrix_file (grep {${$_}[1] eq '-'} @matrix_files){
        # 排他の基点になるオプションが存在するかチェック
        my @exclusion_idx_datas = [&search_compile_option(${$matrix_file}[0], 0)];
        if (${$exclusion_idx_datas[0]}[1] == 99) { next; }
        # 排他先のオプションの検索
        foreach my $i (2..$#{$matrix_file}) {
            my @exclusion_idxs = &search_compile_option(${$matrix_file}[$i], 1);
            if ($exclusion_idxs[1] != 99) {
                push (@exclusion_idx_datas, @exclusion_idxs);
            }
        }
        if (@exclusion_idx_datas > 1) {
            # （排他オプションあり）
            @exclusion_idx_datas = sort {${$a}[0] <=> ${$b}[0]} @exclusion_idx_datas;
            my @root_idxs = @{shift @exclusion_idx_datas};
            foreach my $exclusion_idxs (@exclusion_idx_datas) {
                if (${$compile_options[$root_idxs[0]]}[0] =~ /(parallel[\d]+_[\d])$/ and
                ${$compile_options[${$exclusion_idxs}[0]]}[0] =~ /(parallel[\d]+_[\d])$/ and
                ${$compile_options[$root_idxs[0]]}[0] ne ${$compile_options[${$exclusion_idxs}[0]]}[0]) {
                    next;
                }
                if ((grep {$_ eq ${$compile_options[${$exclusion_idxs}[0]]}[${$exclusion_idxs}[1]]} @{$compile_options[$root_idxs[0]]}) == ()) {
                    push (@{$compile_options[$root_idxs[0]]}, ${$compile_options[${$exclusion_idxs}[0]]}[${$exclusion_idxs}[1]]);
                }
            }
        }
    }
}
###################################################################################################
#   ＜＜ 同時実行指定オプションのグループ化 ＞＞                                                  #
###################################################################################################
sub grouping_simultaneous_option {
    #-----------------------------------------------------------------------------------------#
    # 探索パターンに同時実行指定オプションがあるか検索してグループ化
    foreach my $matrix_file (grep {${$_}[1] =~ /&/} @matrix_files) {
        # 基点となるオプションの探索
        foreach my $lv (0..$#compile_options) {
            foreach my $compile_option (@{$compile_options[$lv]}) {
                if ($compile_option =~ /(^|\s)${$matrix_file}[0]($|\s)/) {
                    # （同時実行指定オプションあり）
                    my @add_compile_options = grep {$compile_option !~ /(^|\s)$_($|\s)/} grep {my $simultaneous_option = $_; grep {grep {$_ =~ /(^|\s)$simultaneous_option($|\s)/} @{$compile_options[$_]}} $lv..$#compile_options} @{$matrix_file}[2..$#{$matrix_file}];
                    if (@add_compile_options != ()) {
                        $compile_option .= ' '. join(' ', @add_compile_options);
                    }
                }
            }
        }
    }
}
###################################################################################################
#   ＜＜オプションindex取得 ＞＞                                                                  #
###################################################################################################
sub search_compile_option {
    my ($op_name, $target) = @_;                                                              # 検索オプション名、ターゲット
    my @search_option = ();                                                                   # 検索結果
    #-----------------------------------------------------------------------------------------#
    if ($op_name eq '') { return (0,0); }
    if ($op_name =~ /=\*$/) { $op_name =~ s/=\*$/.+/; }
    my $flg_search = 0;
    foreach my $lv (0..($#compile_options)) {
        foreach my $i (1..$#{$compile_options[$lv]}) {
            if ("${$compile_options[$lv]}[$i]" =~ /^${op_name}$/) {
                # （検索オプションあり）
                if ($target eq 0) { return ($lv,$i); }
                push (@search_option, [$lv,$i]);
                $flg_search = 1;
            }
        }
    }
    
    if ($flg_search eq 1) {
        # 検索結果を返却
        return @search_option;
    } else {
        # 検索オプションなしを返却
        return (0,99);
    }
}
###################################################################################################
#   ＜＜ 順序指定オプションによる並び替え ＞＞                                                    #
###################################################################################################
sub sort_compile_option {
    #-----------------------------------------------------------------------------------------#
    # 探索パターンに順序指定オプションがあるか検索してグループ化
    foreach my $matrix_file (grep {${$_}[1] =~ /=>/} @matrix_files) {
        my $option1_lv = -1;
        my $option2_lv = -1;
        
        # オプションを検索してindex化
        foreach my $lv (0..$#compile_options) {
            my $data_max = $#{$compile_options[$lv]};
            # 起点オプション有無をチェック
            if ((grep{$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/}@{$compile_options[$lv]}[1..$data_max]) > 0) {
                # （起点オプションあり）
                # 基点となるオプションのオプション情報indexを取得
                $option1_lv = &get_compile_option_level($lv, $option2_lv);
            # 並び替え対象オプション有無をチェック
            } elsif ((grep{$_ =~ /(^|\s)${$matrix_file}[2]($|\s)/}@{$compile_options[$lv]}[1..$data_max]) > 0) {
                # 並び替え対象オプションのオプション情報indexを取得
                $option2_lv = &get_compile_option_level($lv, $option1_lv);
            }
        }
        
        # 並べ替え対象かチェック
        if ($option1_lv >= 0 and $option2_lv >= 0 and
            $option1_lv > $option2_lv) {
            # （並べ替え対象）
            my $sort_compile_option = splice (@compile_options, $option1_lv, 1);
            splice (@compile_options, $option2_lv, 0, $sort_compile_option);
        }
    }
}
###################################################################################################
#   ＜＜ 対象オプションのレベル取得 ＞＞                                                          #
###################################################################################################
sub get_compile_option_level {
    my ($lv, $optionX_lv) = @_;                                                                          # 対象オプションのレベル, 比較するオプションのレベル
    #-----------------------------------------------------------------------------------------#
    if (${$compile_options[$lv]}[0] ne '') {
        my @matched_lvs;
        if (${$compile_options[$lv]}[0] =~ /(parallel[\d]+)/) {
            #  (並列指定あり)
            @matched_lvs = grep {${${compile_options}[$_]}[0] eq $1} 0..$#compile_options;
        } else {
            # （グループ指定あり）
            my $search_group_name = ${$compile_options[$lv]}[0];
            @matched_lvs = grep {${${compile_options}[$_]}[0] eq $search_group_name} 0..$#compile_options;
        }
        
        # 比較するオプションが同一グループ内にいないかチェック
        if ($optionX_lv != -1 and $matched_lvs[0] == $optionX_lv) {
            return $lv;
        }
        # グループの先頭のレベルを返却
        return shift @matched_lvs;
    } else {
        # （グループ指定なし）
        # レベルを返却
        return $lv;
    }
}
###################################################################################################
#   ＜＜ 対になるオプションの追加 ＞＞                                                            #
###################################################################################################
sub add_opposite_option {
    #-----------------------------------------------------------------------------------------#
    foreach my $lv (0..$#compile_options) {
        if ($lv < $base_option_level) { next; }
        my $compile_option = ${$compile_options[$lv]}[$#{$compile_options[$lv]}];
        foreach my $matrix_data (@matrix_files) {
            foreach my $i (2..$#{$matrix_data}){
                if (grep {$_ =~ /(^|\s)${$matrix_data}[$i]($|\s)/} @{$compile_options[$lv]}) { next; }
                #  対になるオプションを検索
                if ((&compare_opposite_option(${$matrix_data}[$i], $compile_option)) or
                    (&compare_opposite_option($compile_option, ${$matrix_data}[$i]))) {
                    # （対になるオプションを検出）
                    push (@{$compile_options[$lv]}, ${$matrix_data}[$i]);
                }
            }
        }
    }
}
###################################################################################################
#   ＜＜ 並列オプションのソート ＞＞                                                            #
###################################################################################################
sub sort_parallel_option {
    my @parallel_keys = @_;
    #-----------------------------------------------------------------------------------------#
    foreach my $parallel_key (@parallel_keys) {
        my %parallel_names = ();
        grep{$parallel_names{${$_}[0]}++} grep {${$_}[0] =~ /${parallel_key}_/} @compile_options;
        my @matched_lvs = ();
        foreach my $parallel_name (sort keys %parallel_names) {
            foreach my $lv (0..$#compile_options) {
                if ($parallel_name eq ${$compile_options[$lv]}[0]) {
                    push (@matched_lvs, $lv);
                    last;
                }
            }
        }
        my @new_compile_options = ();
        my @delete_levels = ();
        my @sorted_matched_lvs = sort {$a <=> $b} @matched_lvs;
        foreach my $lv (0..$#compile_options) {
            if ((grep {$lv == $_} @delete_levels) != ()) { 
                next; 
            }
            if ($sorted_matched_lvs[0] == $lv) {
                foreach my $sorted_matched_lv (@sorted_matched_lvs) {
                    push (@new_compile_options, $compile_options[$sorted_matched_lv]);
                }
                push (@delete_levels, @sorted_matched_lvs);
            } else {
                push (@new_compile_options, $compile_options[$lv]);
            }
        }
        @compile_options = @new_compile_options;
    }
}
###################################################################################################
#   ＜＜ オプション情報の並び換え ＞＞                                                            #
###################################################################################################
sub sort_group_option {
    %stop_levels             = ();                                                            # 実行抑止レベル情報
    my @new_compile_options  = ();                                                            # 再生成するオプション情報
    my @delete_levels        = ();                                                            # グループ化により追加したレベルの一覧
    unshift (@compile_options, []);
    unshift (@new_compile_options, []);
    #-----------------------------------------------------------------------------------------#
    foreach my $lv (1..$#compile_options){
        if ((grep {$lv == $_} @delete_levels) != ()) { next; }
        # グループ名有無をチェック
        if (${$compile_options[$lv]}[0] ne '') {
            # （グループあり）
            my $group_name = ${$compile_options[$lv]}[0];
            my @grouping_levels = grep {${$compile_options[$_]}[0] eq $group_name} 1..$#compile_options;
            # グルーピング後削除対象
            push (@delete_levels, @grouping_levels);
            my $run_level = pop @grouping_levels;
            my @stop_level = ();
            foreach my $grouping_level (@grouping_levels) {
                # （実行抑止対象）
                push (@new_compile_options, $compile_options[$grouping_level]);
                # 実行抑止レベルを蓄積
                push (@stop_level, $#new_compile_options);
            }
            # （実行対象）
            push (@new_compile_options, $compile_options[$run_level]);
            # 実行抑止レベル情報に追加
            @{$stop_levels{$#new_compile_options}} = @stop_level;
        } else {
            # （グループなし）
            push (@new_compile_options, $compile_options[$lv]);
        }
    }
    
    # オプション情報を更新
    @compile_options = @new_compile_options;
}
###################################################################################################
#   ＜＜ 探索実行 ＞＞                                                                            #
###################################################################################################
sub cpoption_searcher {
    my %templetes = @_;
    my @jobs = &prepare(%templetes);
    &submit(@jobs);
}
###################################################################################################
#   ＜＜ ジョブ生成 ＞＞                                                                          #
###################################################################################################
sub prepare {
    %templetes = @_;
    my %parent_opids = ();
    #-----------------------------------------------------------------------------------------#
    # 実行レベルオプション展開
    # 親オプションIDを取得
    my @last_parent_opids = sort {$a <=> $b} keys(%compile_patterns);
    
    # 次のレベルが並列対象レベルかチェック
    if (${$compile_options[$search_level+1]}[0] =~ /(parallel[\d]+_)/) {
        my $parallel_name = $1;
        my %parallel_names;
        grep { $parallel_names{${$_}[0]}++} grep {${$_}[0] =~ /$parallel_name/} @compile_options;

        # オプションの組合せ展開
        foreach (keys %parallel_names) {
            %parent_opids = &dev_compile_pattern(%parent_opids);
        }
    } else {
        # オプションの組合せ展開
        %parent_opids = &dev_compile_pattern(\%parent_opids);
    }
    &optimization_compile_option(\%parent_opids);
    
    # 実行対象のオプションIDを取得
    @opids = sort {$a <=> $b} grep {$last_parent_opids[$#last_parent_opids] < $_} keys %compile_patterns;
    if (@opids == ()) { return (); }
    
    # ジョブオブジェクト生成
    return &builtin::prepare(&prepare_search(%templetes));
}
###################################################################################################
#   ＜＜ オプションのパターン化 ＞＞                                                              #
###################################################################################################
sub dev_compile_pattern {
    my (%parent_opids) = @_;                                                                    # 親オプションID
    #-----------------------------------------------------------------------------------------#
    # パターン化対象レベルを設定
    $search_level++;
    while (@{$compile_options[$search_level]} == 1) {
        $search_level++;
    }
    my $start_level = $search_level;
    foreach my $key (sort {$a <=> $b} keys %stop_levels) {
        if ($search_level >= $key) { next; }
        if ((grep{$_ eq $search_level}@{$stop_levels{$key}}) > 0) {
            $search_level = $key;
            last;
        }
    }
    
    # オプションの組合せ展開
    my %in_compile_patterns  = %next_compile_patterns;
    my @in_compile_pattern_keys = sort {$a <=> $b} keys %next_compile_patterns;
    foreach my $lv ($start_level..$search_level) {
        @{$search_level_jobs[$lv]} = ();
        if (@{$compile_options[$lv]} == 0) { next; }
        my %out_compile_patterns = ();
        foreach my $parent_opid (sort {$a <=> $b} keys %in_compile_patterns ) {
            my $parent_pattern;
            # 指定オプションを展開
            if ($parent_opid != 0) {
                if ($lv == $start_level) {
                    # （グループ化なし、又はグループ化の最初のレベル）
                    $parent_pattern = &get_compile_option($parent_opid)
                } else {
                    # （グループ化あり）
                    foreach my $i (1..$#{$in_compile_patterns{$parent_opid}}) {
                        if (${$in_compile_patterns{$parent_opid}}[$i] > 0) {
                            $parent_pattern .= ' '. "${$compile_options[$i]}[${$in_compile_patterns{$parent_opid}}[$i]]";
                        }
                    }
                }
            }
            # 同時実行オプション対象かチェック
            my $compile_options_str = join('|', @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]);
            if ($parent_pattern =~ /$compile_options_str/) {
                # （スキップ対象）
                if (exists $stop_levels{$search_level}) {
                    @{$out_compile_patterns{$parent_opid}} = @{$in_compile_patterns{$parent_opid}};
                    if ($lv == $search_level) {
                        push (@{$search_level_jobs[$lv]}, "$parent_opid");
                    }
                    next;
                } else {
                    next;
                }
            }
            if ($#{$compile_options[$lv]} eq 1) {
                @{$out_compile_patterns{$parent_opid}} = @{$in_compile_patterns{$parent_opid}};
                if ($lv == $search_level) {
                    # オプションIDをレベル別実行ジョブに登録
                    push (@{$search_level_jobs[$lv]}, "$parent_opid");
                }
            }
            foreach my $i (1..$#{$compile_options[$lv]}) {
                # 設定済(誘導含む)オプションかチェック
                my $search_level_option_index = '';
                if ((grep {${$compile_options[$lv]}[$i] =~ /(^|\s)$_(\s|$)/} @{$setting_options{$parent_opid}}) == 0 and
                    (grep {$_ =~ /(^|\s)${$compile_options[$lv]}[$i](\s|$)/} @{$setting_options{$parent_opid}}) == 0) {
                    # （未設定）
                    $search_level_option_index = $i;
                }
                # 設定すべきオプションかチェック
                my $flg_out = '';
                if ($lv == ($base_option_level + 1) or
                   ($search_level_option_index != "${$in_compile_patterns{$parent_opid}}[$lv]")) {
                    # パターン情報に登録
                    $opid_seq++;
                    @{$out_compile_patterns{$opid_seq}} = @{$in_compile_patterns{$parent_opid}};
                    @{$setting_options{$opid_seq}} = @{$setting_options{$parent_opid}};
                    if ($search_level_option_index ne ${$out_compile_patterns{$opid_seq}}[$lv]) {
                        &upd_setting_option($lv, $opid_seq, "${$compile_options[$lv]}[${$out_compile_patterns{$opid_seq}}[$lv]]", "${$compile_options[$lv]}[$search_level_option_index]");
                        ${$out_compile_patterns{$opid_seq}}[$lv] = "$search_level_option_index";
                    }
                    if ((&chk_setting_option($opid_seq, ${$compile_options[$lv]}[$search_level_option_index])) == 0) {
                        $flg_out = 1;
                        if ($lv == $search_level) {
                            # （グループ化なし、又はグループ化の最後のレベル）
                            # オプションIDをレベル別実行ジョブに登録
                            push (@{$search_level_jobs[$lv]}, "$opid_seq");
                            # 親オプションID情報に登録
                            $parent_opids{$opid_seq} = "$parent_opid";
                        }
                    } else {
                        delete $out_compile_patterns{$opid_seq};
                        delete $setting_options{$opid_seq};
                    }
                }
                if ($flg_out eq '') {
                    @{$out_compile_patterns{$parent_opid}} = @{$in_compile_patterns{$parent_opid}};
                    if ($lv == $search_level) {
                        # オプションIDをレベル別実行ジョブに登録
                        push (@{$search_level_jobs[$lv]}, "$parent_opid");
                    }
                }
            }
        }
        %in_compile_patterns = %out_compile_patterns;
        # パターン情報に追加
        if ($lv == $search_level) {
            %compile_patterns = (%compile_patterns, %out_compile_patterns);
            # 親オプションIDをレベル別実行ジョブに登録
            if ($start_level > 1 and $start_level ne $search_level) {
                push (@{$search_level_jobs[$lv]}, @in_compile_pattern_keys);
            }
        }
    }
    
    # 親オプションID情報を返却
    return \%parent_opids;
}
###################################################################################################
#   ＜＜ コンパイルオプション取得 ＞＞                                                            #
###################################################################################################
sub get_compile_option {
    my ($opid)         = @_;                                                                  # オプションID
    my $compile_option = '';                                                                  # 展開オプション
    my $opid_compile_option = '';                                                             # 返却オプション
    my @opid_compile_patterns = @{$compile_patterns{$opid}};                                  # 指定オプションIDのコンパイルパターン情報
    my %option_count = ();                                                                    # オプション名重複チェック用
    #-----------------------------------------------------------------------------------------#
    # 指定オプションを展開
    foreach my $i (1..$#opid_compile_patterns) {
        if ($opid_compile_patterns[$i] > 0) {
            # （オプションの指定あり（誘導オプションはnull））
            if ((++$option_count{"${$compile_options[$i]}[$opid_compile_patterns[$i]]"}) <  2) {
                $compile_option .= ' '. "${$compile_options[$i]}[$opid_compile_patterns[$i]]";
            }
        }
    }
    
    my @opid_compile_options = ();
    foreach my $compile_option2 (split(/ /, $compile_option)) {
        if ((grep {$_ =~ /(^|\s)$compile_option2($|\s)/} @{$setting_options{$opid}}) > 0 and
            (grep {$_ =~ /(^|\s)$compile_option2($|\s)/} @opid_compile_options) == 0) {
            push (@opid_compile_options, $compile_option2);
        }
    }
    foreach my $compile_option2 (@opid_compile_options) {
        $opid_compile_option .= ' ' . $compile_option2;
    }
    
    # 展開オプションを返却
    return $opid_compile_option;
}
###################################################################################################
#   ＜＜ 設定済オプションのチェック ＞＞                                                          #
###################################################################################################
sub chk_setting_option {
    my ($opid, $option) = @_;
    my $chk_flg         = '';
    #-----------------------------------------------------------------------------------------#
    # 探索パターンにオプションがあるか検索
    foreach my $matrix_file (grep {${$_}[1] =~ /^=>$/} @matrix_files) {
        # 起点オプション検索
        if ((grep {$option =~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]) > 0) {
            foreach my $matrix (@{$matrix_file}[2..$#{$matrix_file}]) {
                if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$setting_options{$opid}}) > 0) {
                    if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$setting_options{$opid}}) == ()) {
                        $chk_flg = 1;
                        last;
                    }
                }
            }
        }
    }
    if ($chk_flg eq 1) { return 1; }
    foreach my $matrix_file (grep {${$_}[1] =~ /^(=|&|-)$/} @matrix_files) {
        #オプション検索
        if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$setting_options{$opid}}) == ()) {
            next;
        }
        foreach my $chk_matrix (grep {${$_}[0] =~ /(^|\s)${$matrix_file}[0]($|\s)/ and ${$_}[1] eq ${$matrix_file}[1]} @matrix_files) {
            $chk_flg = '';
            if (${$chk_matrix}[1] =~ /&/) {
                foreach my $matrix (@{$chk_matrix}[2..$#{$chk_matrix}]) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$setting_options{$opid}}) == ()) {
                        $chk_flg = 1;
                        last;
                    }
                }
                if ($chk_flg eq '') { last; }
            } elsif (${$chk_matrix}[1] =~ /=/) {
                foreach my $matrix (@{$chk_matrix}[2..$#{$chk_matrix}]) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$setting_options{$opid}}) == ()) {
                        last;
                    }
                    $chk_flg = 1;
                }
                if ($chk_flg eq '') { last; }
            } else {
                foreach my $matrix (@{$chk_matrix}[2..$#{$chk_matrix}]) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$setting_options{$opid}}) == ()) {
                        next;
                    }
                    $chk_flg = 1;
                    last;
                }
                if ($chk_flg eq '') { last; }
            }
        }
        if ($chk_flg eq 1) { return 1; }
    }
    return 0;
}
###################################################################################################
#   ＜＜ パターン文字列内に対象オプションが全て存在するか調べる ＞＞                              #
###################################################################################################
sub chk_exists_all_search_option {
    my ($pattern, $matrix_file) = @_;
    #-----------------------------------------------------------------------------------------#
    # 等価オプションが全て存在するかチェック
    foreach my $option (@{$matrix_file}[2..$#{$matrix_file}]) {
        if ($pattern !~ /(^|\s)$option($|\s)/) {
            # （等価オプションなし）
            return 0;
        }
    }
    
    # 等価オプションありを返却
    return 1;
}
###################################################################################################
#   ＜＜ パターン文字列内に対象オプションが存在するか調べる ＞＞                                  #
###################################################################################################
sub chk_exists_search_option {
    my ($pattern, $matrix_file) = @_;
    #-----------------------------------------------------------------------------------------#
    # 排他となるオプションが存在するかチェック
    foreach my $option (@{$matrix_file}[2..$#{$matrix_file}]) {
        if ($pattern =~ /(^|\s)$option($|\s)/) {
            # 排他オプションありを返却
            return 1;
        }
    }
    
    # （排他オプションなし）
    return 0;
}
###################################################################################################
#   ＜＜ 設定済オプション情報の更新 ＞＞                                                              #
###################################################################################################
sub upd_setting_option {
    my ($lv, $opid, $old_option, $new_option) = @_;                                           # チェックレベル、オプションID、旧オプション、新オプション
    my @unset_options = ();                                                                   # 誘導解除オプション
    my @set_options   = ($new_option);                                                        # 追加誘導オプション
    #-----------------------------------------------------------------------------------------#
    if ($old_option ne '') {
        push (@unset_options, $old_option);
    } else {
        foreach my $setting_option (@{$setting_options{$opid}}[1..$#{$setting_options{$opid}}]) {
            if ($setting_option ne '' and
               (&compare_opposite_option($setting_option, $new_option) or
                &compare_opposite_option($new_option, $setting_option))) {
                push (@unset_options, $setting_option);
            }
        }
    }
    # 追加誘導オプションをチェック
    foreach my $set_option (@set_options) {
        foreach my $matrix_file (grep {${$_}[1] =~ /[\+]/} @matrix_files) {
            if ((ref (${$matrix_file}[0]) eq 'ARRAY')){
                my $flg_add = 1;
                foreach my $matrix (@{${$matrix_file}[0]}) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$setting_options{$opid}}) == 0) {
                         $flg_add = 0;
                         last;
                    }
                }
                if ($flg_add == 1) {
                    push (@set_options, @{$matrix_file}[2..$#{$matrix_file}]);
                }
            } else {
                if ("$set_option" eq "${$matrix_file}[0]") {
                    push (@set_options, @{$matrix_file}[2..$#{$matrix_file}]);
                }
            }
        }
    }
    my @in_set_option = @set_options;
    @set_options = ();
    for (my $i = $#in_set_option; $i >= 0; $i--) {
        foreach my $set_option (@set_options) {
            if ((&compare_opposite_option($set_option, $in_set_option[$i])) or
                (&compare_opposite_option($in_set_option[$i], $set_option))) {
                last;
            }
        }
        push (@set_options, $in_set_option[$i]);
    }
    
    # 誘導解除オプションをチェック
    foreach my $set_option (@set_options) {
        foreach my $setting_option (@{$setting_options{$opid}}[1..$#{$setting_options{$opid}}]) {
            if ($set_option ne '' and
               (&compare_opposite_option($setting_option, $set_option) or
                &compare_opposite_option($set_option, $setting_option))) {
                if ($setting_option ne '') {
                    push (@unset_options, $setting_option);
                }
            }
        }
    }
    foreach my $matrix_file (grep {${$_}[1] eq ''} @matrix_files) {
        if ((grep {$new_option =~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]) > 0) {
            my @upper_options = (grep {$new_option !~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]);
            foreach my $upper_option (@upper_options) {
                if ((grep {$_ =~ /(^|\s)$upper_option($|\s)/} @{$setting_options{$opid}}[1..$#{$setting_options{$opid}}]) > 0) {
                    push (@unset_options, $upper_option);
                }
            }
        }
        foreach my $set_option (@set_options) {
            if ($new_option eq $set_option) { next; }
            if ((grep {$set_option =~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]) > 0) {
                my @upper_options = (grep {$new_option !~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]);
                push (@unset_options, @upper_options);
            }
        }
    }
    loop1:
    foreach my $unset_option (@unset_options) {
        loop2:
        foreach my $matrix_file (grep {${$_}[1] =~ /[\+]/} @matrix_files) {
            if ((ref (${$matrix_file}[0]) eq 'ARRAY')){
                foreach my $matrix (@{${$matrix_file}[0]}) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$setting_options{$opid}}[1..$#{$setting_options{$opid}}]) == 0) {
                         next loop2;
                    }
                }
            } else {
                if ($unset_option ne ${$matrix_file}[0]) {
                    next;
                }
            }
            loop3:
            foreach my $matrix (@{$matrix_file}[2..$#{$matrix_file}]) {
                my $parent_lv = $lv - 1;
                if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @unset_options) > 0) { next; }
                loop4:
                foreach my $check_lv (0..$parent_lv) {
                    if (${$compile_options[$check_lv]}[$compile_patterns{$check_lv}] =~ /(^|\s)$matrix($|\s)/) {
                        next loop3;
                    }
                    loop5:
                    foreach my $setting_option (@{$setting_options{$opid}}) {
                        if ((grep {$setting_option =~ /(^|\s)$_($|\s)/} @unset_options) > 0) { next; }
                        foreach my $matrix_file2 (grep {$setting_option =~ /(^|\s)${$_}[0]($|\s)/ and ${$_}[1] =~ /[\+]/} @matrix_files) {
                            if ((grep {$matrix =~ /(^|\s)$_($|\s)/} @{$matrix_file2}[2..$#{$matrix_file2}]) > 0) {
                                next loop3;
                            }
                        }
                        loop6:
                        foreach my $matrix_file2 (grep {(ref (${$_}[0]) eq 'ARRAY') and ${$_}[1] =~ /[\+]/} @matrix_files) {
                            loop7:
                            foreach my $matrix2 (@{${$matrix_file2}[0]}) {
                                if ($setting_option !~ /(^|\s)$matrix2($|\s)/) {
                                    next loop6;
                                }
                            }
                            if ((grep {$matrix =~ /(^|\s)$_($|\s)/} @{$matrix_file2}[2..$#{$matrix_file2}]) > 0) {
                                next loop3;
                            }
                        }
                    }
                }
                push (@unset_options, $matrix);
            }
        }
    }
    
    # 旧オプションが存在するかチェック
    if ((grep {$_ =~ /^$old_option$/} @{$setting_options{$opid}}) == 0) {
        # （存在しない）
        push (@{$setting_options{$opid}}, "$new_option");
    } else {
        # （存在する）
        my @idx = map {$_ =~ /^$old_option$/; $_;} @{$setting_options{$opid}};
        ${$setting_options{$idx[0]}} = "$new_option";
    }
    
    # 設定済オプション情報を更新
    my @deleted_options = ();
    foreach my $setting_option (@{$setting_options{$opid}}) {
        if ((grep {$_ =~ /^$setting_option$/} @unset_options) == 0) {
            push (@deleted_options, "$setting_option");
        }
    }
    @{$setting_options{$opid}} = @deleted_options;
    foreach my $set_option (@set_options) {
        if ((grep {$_ =~ /^$set_option$/} @deleted_options) == 0) {
            push (@{$setting_options{$opid}}, "$set_option");
        }
    }
}
###################################################################################################
#   ＜＜ 誘導オプションチェック ＞＞                                                              #
###################################################################################################
sub optimization_compile_option {
    my ($parent_opids) = @_;                                                                  # 親オプションID
    #-----------------------------------------------------------------------------------------#
    # レベル内のオプションIDをサマリ
    my %count = ();
    @{$search_level_jobs[$search_level]} = grep {$_ ne ''} @{$search_level_jobs[$search_level]};
    @{$search_level_jobs[$search_level]} = grep {!$count{$_}++} @{$search_level_jobs[$search_level]};
    
    # 誘導処理によって同一となってしまう指定を削除
    my @check_opid = ();
    foreach my $key (keys %stop_levels) {
        foreach my $opid (@{$search_level_jobs[$key]}) {
            push (@check_opid, $opid);
        }
    }
    push (@check_opid, @{$search_level_jobs[$search_level]});
    %count = ();
    my @sorted_check_opid  = sort {$a <=> $b} grep {!$count{$_}++} @check_opid;
    
    for (my $i1 = $#sorted_check_opid; $i1 > 1; $i1--) {
        if (!exists $compile_patterns{$sorted_check_opid[$i1]}) { next; }
        foreach my $i2 (0..($i1 - 1)) {
            if (!exists $compile_patterns{$sorted_check_opid[$i2]}) { next; }
            my $synonym_flg = 0;
            foreach my $i (1..$#{$setting_options{$sorted_check_opid[$i1]}} ) {
                if ((grep {$_ =~ /(^|\s)${$setting_options{$sorted_check_opid[$i1]}}[$i]($|\s)/} @{$setting_options{$sorted_check_opid[$i2]}}) == 0) {
                    $synonym_flg = 1;
                    last;
                }
            }
            if ($synonym_flg == 0) {
                # 比較対象を親に変更
                &upd_search_level_jobs($#{$compile_patterns{$sorted_check_opid[$i1]}}, $sorted_check_opid[$i1], $parent_opids);
                # 変更したパターンを削除
                delete $compile_patterns{$sorted_check_opid[$i1]};
                my @new_search_level_jobs = ();
                foreach my $i (0..$#{$search_level_jobs[$search_level]}) {
                    if ($sorted_check_opid[$i1] ne ${$search_level_jobs[$search_level]}[$i]) {
                        push (@new_search_level_jobs, ${$search_level_jobs[$search_level]}[$i]);
                    }
                }
                @{$search_level_jobs[$search_level]} = @new_search_level_jobs;
                last;
            }
        }
    }
}
###################################################################################################
#   ＜＜ グループ内の誘導オプションチェック ＞＞                                                  #
###################################################################################################
sub chk_group_option {
    my $group_name        = shift;
    my (@compile_pattern) = @_;                                                  # グループ名、パターン
    #-----------------------------------------------------------------------------------------#
    my @group_lvs = grep {${${compile_options}[$_]}[0] eq $group_name} 0..$#compile_options;
    # グループの最終レベルかチェック
    if ($search_level < $group_lvs[$#group_lvs]) { return 1; }
    
    # グループ内が誘導オプションのみかチェック
    if ((grep{$_ > 0}@compile_pattern[$group_lvs[0]..$search_level]) > 0) {
        # （誘導オプション以外あり）
        return 1;
    }
    return 0;
}
###################################################################################################
#   ＜＜ 比較対象を親に変更 ＞＞                                                                  #
###################################################################################################
sub upd_search_level_jobs {
    my ($lv, $opid, $parent_opids) = @_;                                                      # レベル、オプションID、親オプションID情報
    my $parent_opid = ${$parent_opids}{$opid};                                                # 親オプションID
    #-----------------------------------------------------------------------------------------#
    # オプションIDのindexを取得
    my $change = &get_search_level_jobs_index($lv, $opid);
    
    #レベル別実行ジョブに親オプションIDが登録されていない場合親の親を辿る
    for (my $parent_lv = $lv-1; $parent_lv > 0; $parent_lv--) {
        if (grep {${$search_level_jobs[$parent_lv]}[$_] == $parent_opid} 0..$#{$search_level_jobs[$parent_lv]}) {
            ${$search_level_jobs[$lv]}[$change] = $parent_opid;
            last;
        }
        $parent_opid = ${$parent_opids}{$parent_opid};
    }
    
    $child_patterns{$parent_opid} = $compile_patterns{$opid};
}
###################################################################################################
#   ＜＜ オプションIDのindexを取得 ＞＞                                                           #
###################################################################################################
sub get_search_level_jobs_index {
    my ($lb, $opid) = @_;                                                                     # レベル、オプションID
    #-----------------------------------------------------------------------------------------#
    foreach my $i (0..$#{$search_level_jobs[$lb]}) {
        # レベル内にオプションIDがあるかチェック
        if ($opid eq ${$search_level_jobs[$lb]}[$i]) {
            # indexを返却
            return $i;
        }
    }
    return -1;
}
###################################################################################################
#   ＜＜ prepare前処理 ＞＞                                                                       #
###################################################################################################
# ユーザースクリプトのチェック、cpoption_seacher用の情報追加
sub prepare_search {
    my (%job)     = @_;
    my @range     = ();                                                                       # rangeへ追加するオプション配列
    @compile_keys = grep {$_ =~ /^compile[\d]+$/} keys %job;
    #-----------------------------------------------------------------------------------------#
    # コンパイル文が正しいかチェック
    &chk_compile_str(%job);
    
    # ジョブseq情報を生成
    foreach my $opid (@opids) {
        $jobseq++;
        $opid_jobseqs{$opid} = "$jobseq";
        push (@range, $jobseq);
    }
    
    # オプション配列をレンジに追加
    my @sorted_range_key = sort {$a <=> $b} grep {$_ =~ /^RANGE[\d]+$/} keys %job;
    if (@sorted_range_key == ()) {
        $job{"RANGE0"} = \@range;
        if ($measurement_cnt >= 2) {
            $job{"RANGE1"} = [1..$measurement_cnt];
        }
    } else {
        $sorted_range_key[$#sorted_range_key] =~ /^RANGE([\d]+)$/;
        my $max_range_num = $1;
        $job{"RANGE" . ($max_range_num + 1)} = \@range;
        if ($measurement_cnt >= 2) {
            $job{"RANGE" . ($max_range_num + 2)} = [1..$measurement_cnt];
        }
    }
    
    my $copy_opid = 1;
    foreach my $range_key (@sorted_range_key){
        $copy_opid *= @{$job{"$range_key"}};
    }
    my @new_opids = ();
    foreach my $i (1..$copy_opid){
        foreach my $opid (@opids) {
            foreach (1..$measurement_cnt) {
                push (@new_opids, $opid);
            }
        }
        # @new_opids = (@new_opids, @opids);
    }
    @opids = @new_opids;
    
    return %job;
}
###################################################################################################
#   ＜＜ コンパイル文チェック ＞＞                                                                #
###################################################################################################
sub chk_compile_str {
    my (%job) = @_;                                                                           # コンパイル文 -o ** $OP **.o | -c $OP **.c
    #-----------------------------------------------------------------------------------------#
    foreach my $compile_key (@compile_keys) {
        unless ($job{$compile_key} =~ /^-o/ or $job{$compile_key} =~ /^-c/) {
            return 1;
        }
        unless ($job{$compile_key} =~ /^-o \S+? \$OP \S+/ or $job{$compile_key} =~ /^-c \$OP \S+/) {
            die "syntax error : $compile_key \n"
        }
    }
    return 1;
}
###################################################################################################
#   ＜＜ オブジェクト定義 ＞＞                                                                    #
###################################################################################################
sub new {
    my $class     = shift;
    my $self      = shift;
    $self->{opid} = shift @opids;
    #-----------------------------------------------------------------------------------------#
    # NEXT::new
    $self = $class->NEXT::new($self);
    return bless $self, $class;
}
###################################################################################################
#   ＜＜ ジョブ実行 ＞＞                                                                          #
###################################################################################################
sub submit {
    my @array = @_;                                                                           # 実行レベルジョブオブジェクト
    #-----------------------------------------------------------------------------------------#
    # オブジェクトをスレッドごとに実行
    &builtin::submit(@array);
    
    # 実行レベルジョブが全て終了するまで待機
    &builtin::sync(@array);
    
    # 実行レベルジョブ評価
    my @jobs = ();
    foreach my $check_opid (@{$search_level_jobs["${search_level}"]}) {
        # オプションID毎の実行結果を取得
        my @opid_job_execute_times_data = grep {$_ =~ /^$check_opid/} @job_execute_times;
        if ($#opid_job_execute_times_data >= 0) {
            my $opid_execute_times_data = &get_opid_execute_time(@opid_job_execute_times_data);
            push (@jobs, [$check_opid, $opid_execute_times_data]);
            # オプションID別実行時間に登録
            push (@opid_execute_times, "$check_opid,$opid_execute_times_data");
        }
    }
    
    # 次のレベルが存在する場合 prepare submit sync 実行
    if ($search_level < $#compile_options) {
        # 実行結果を早い順に並べる
        my @sorted_jobs  = sort {${$a}[1] <=> ${$b}[1]} grep {${$_}[1] != 0} @jobs;
        my @next_pattern_jobs = ();
        my %temp_next_compile_patterns = %next_compile_patterns;
        %next_compile_patterns = ();
        my $cnt = 0;
        # 次レベルへ引渡すパターンを設定 
        foreach my $i (0..$#sorted_jobs) {
            if ($extraction_cond > $cnt and
                eval ($user_conditional) ) {
                push (@next_pattern_jobs, $sorted_jobs[$i]);
                @{$next_compile_patterns{${$sorted_jobs[$i]}[0]}} = @{$compile_patterns{${$sorted_jobs[$i]}[0]}};
                $cnt++;
            }
        }
        # 現レベルで次レベルへ引き渡すパターンがない場合、前レベルのパターンを設定
        if (%next_compile_patterns == ()) {
            %next_compile_patterns = %temp_next_compile_patterns;
        }
        # 次レベルを実行
        &cpoption_searcher(%templetes);
    } else {
        # 次のレベルが存在しない場合 結果出力
        # （全ジョブ完了）
        # 結果出力
        if ($#opid_execute_times >= 0) {
            &output_result();
        }
    }
}
###################################################################################################
#   ＜＜ ジョブ前処理 ＞＞                                                                        #
###################################################################################################
sub before {}
###################################################################################################
#   ＜＜ ジョブ実行 ＞＞                                                                          #
###################################################################################################
sub start {
    my $self = shift;
    #-----------------------------------------------------------------------------------------#
    # NEXT::start
    $self->NEXT::start();
}
###################################################################################################
#   ＜＜ スクリプト生成 ＞＞                                                                      #
###################################################################################################
# コンパイル、実行時間取得
sub make_jobscript_body {
    my $self = shift;
    my @body = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};
    #-----------------------------------------------------------------------------------------#
    ## Job script body
    # Chdir to the job's working directory
    my $wkdir_str = $self->{workdir};
    if (defined ($cfg{jobscript_workdir})) {
        my $js_wkdir = $cfg{jobscript_workdir};
        unless (ref ($js_wkdir)) {
            $wkdir_str = $js_wkdir;
        } elsif (ref ($js_wkdir) eq 'CODE') {
            $wkdir_str = &$js_wkdir($self);
        } else {
            warn "Error in config file $self->{env}->{sched}: jobscript_workdir is neither scalar nor CODE."
        }
    }
    unless ($self->{rhost} eq '') {
        $wkdir_str = File::Spec->catfile( $self->{rwd}, $wkdir_str );
    }
    push (@body, "cd ". $wkdir_str);
    # Set the job's status to "running"
    push (@body, "sleep 1"); # running が早すぎて queued がなかなか勝てないため
    # Compile the source
    foreach my $compile_key (@compile_keys) {
        if ($self->{$compile_key}) {
            my $OP;
            if ($self->{$compile_key} =~ /^-o/ ||
                $self->{$compile_key} =~ /^-c/) {
                $OP = &get_compile_option($self->{opid});
                $self->{$compile_key} =~ s/\$OP/$OP/;
            } else {
                $self->{$compile_key} = '-o' . ' ' . $self->{exe} . ' ' . &get_compile_option($self->{opid}) . ' ' . $self->{$compile_key};
            }
            my $cmd = $compile_comand . ' ' . $self->{$compile_key};
            push (@body, $cmd);
        }
    }
    # Do before_in_job
    if ($self->{before_in_job}) {
        push (@body, "perl $self->{before_in_job_file}");
    }
    my $cmd = 'if [ ! -f "'. $self->{exe}. '" ]; then';
    push (@body, $cmd);
    push (@body, "\t".jobsched::inventory_write_cmdline($self, 'aborted'). " || exit 1");
    push (@body, "\t".'kill -9 $$');
    push (@body, 'else');
    push (@body, "\t".jobsched::inventory_write_cmdline($self, 'running'). " || exit 1");
    push (@body, 'fi');
    # Execute the program
    foreach my $j (0 .. $user::max_exe) {
        if ($self->{"exe$j"}) {
            my @args = ();
            for ( my $i = 0; $i <= $user::max_arg; $i++) {
                if ( $self->{"arg$j".'_'."$i"} ) {
                    push(@args, $self->{"arg$j".'_'."$i"});
                }
            }
            push (@body, "sleep 1");
            # timeコマンド結果(標準エラー出力)をファイルに出力
            my $cmd = '/usr/bin/time ' . $self->{"exe$j"} . ' ' . join(' ', @args) . ' 2>./' . $self->{id}. '.time';
            push (@body, $cmd);
        }
    }
    # Do after_in_job
    if ( $self->{after_in_job} ) { push (@body, "perl $self->{after_in_job_file}"); }
    # Set the job's status to "done" (should set to "aborted" when failed?)
    push (@body,  'if [ ! -f "./'. $self->{id}. '.time' . '" ]; then');
    push (@body, "\t".jobsched::inventory_write_cmdline($self, 'aborted'). " || exit 1");
    push (@body, "\t".'kill -9 $$');
    push (@body, 'else');
    push (@body, "\t".jobsched::inventory_write_cmdline($self, 'done'). " || exit 1");
    push (@body, 'fi');
    $self->{jobscript_body} = \@body;
}
###################################################################################################
#   ＜＜ ジョブ後処理 ＞＞                                                                        #
###################################################################################################
sub after {
    my $self = shift;                                                                         # オブジェクト
    #-----------------------------------------------------------------------------------------#
    # ジョブ毎の実行結果を登録
    if ((&jobsched::get_job_status) eq "aborted") { return; }
    my @execute_time = &get_execute_time($self);
    if ($#execute_time >= 0) {
        push (@job_execute_times, @execute_time);
    }
}
###################################################################################################
#   ＜＜ 実行時間取得 ＞＞                                                                        #
###################################################################################################
sub get_execute_time {
    my $self          = shift;                                                                # オブジェクト
    my @execute_times = ();                                                                   # 実行時間情報
    my $line_cnt      = 0;                                                                    # 行カウンタ
    my $opid          = $self->{opid};                                                        # オプションID
    #-----------------------------------------------------------------------------------------#
    # OPEN
    my $execute_time_file =  File::Spec->catfile( $self->{workdir}, $self->{id} . '.time' );
    open (EXECUTE_TIME, "< $execute_time_file") or warn "Cannot open  $execute_time_file";
    # 実行時間取得
    my @execute_time_datas = <EXECUTE_TIME>;
    foreach my $execute_time_data (@execute_time_datas) {
        $line_cnt++;
        if ($execute_time_data =~ /^Command terminated by signal 9/) { return (); }
        #「9.99user 9.99system ･･･」から実行時間(user＋system)を取得
        if ($execute_time_data =~ /^([0-9\.]+)user\s+([0-9\.]+)system/) {
            my $pg_time = ($1 + $2);
            #my $pg_time = $1;
            push (@execute_times, "$opid,$self->{id},$search_level,$pg_time");
        } elsif ($execute_time_data =~ /^([0-9\.]+)u\s+([0-9\.]+)s/) {
            my $pg_time = ($1 + $2);
            #my $pg_time = $1;
            push (@execute_times, "$opid,$self->{id},$search_level,$pg_time");
        }
    }
    # CLOSE
    close (EXECUTE_TIME);
    return @execute_times;
}
###################################################################################################
#   ＜＜ 実行時間取得 ＞＞                                                                        #
###################################################################################################
sub get_opid_execute_time {
    my @execute_times = ();
    foreach my $pg_time_data (@_) {
        my @pg_time_data = split(/,/,$pg_time_data);
        push (@execute_times, $pg_time_data[$#pg_time_data]);
    }
    my @sorted_execute_times  = sort {$a <=> $b} @execute_times;                              # 昇順化実行時間
    #-----------------------------------------------------------------------------------------#
    # 計測条件に従い結果算出し、配列(ジョブ名､実行時間)を返却
    if ($measurement_time eq 'max') {
        # （最大）
        return "$sorted_execute_times[$#sorted_execute_times]";
    } elsif ($measurement_time eq 'min') {
        # （最小）
        return "$sorted_execute_times[0]";
    } elsif ($measurement_time eq 'med') {
        # （中間）
        my $execute_time_index = int(($#sorted_execute_times / 2) + 0.5);
        return "$sorted_execute_times[$execute_time_index]";
    } else {
        # （平均）
        my $total_time = 0;
        foreach my $execute_time_data (@sorted_execute_times) {
            $total_time += $execute_time_data;
        }
        my $return_time = sprintf("%.2f", ($total_time / ($#sorted_execute_times+ 1)));
        return $return_time;
    }
}
###################################################################################################
#   ＜＜ 検索結果出力 ＞＞                                                                        #
###################################################################################################
sub output_result {
    my @execute_times       = ();                                                             # 実行結果
    my %check_opid          = ();
    my @output_time_datas   = ();                                                             # 時間情報
    my @output_option_datas = ();                                                             # オプション情報
    #-----------------------------------------------------------------------------------------#
    foreach my $opid_time_data (@opid_execute_times) {
        my @opid_time_data = split(/,/,$opid_time_data);
        if ($opid_time_data[1] == 0) { next; }
        if (exists $check_opid{$opid_time_data[0]}) { next; }
        $check_opid{$opid_time_data[0]} = $opid_time_data[$#opid_time_data];
        push (@execute_times, [$opid_time_data[0], $opid_time_data[$#opid_time_data]]);
    }
    if (@execute_times == ()) { return; }
    my @sorted_jobs = sort {${$a}[1] <=> ${$b}[1]} @execute_times;                            # 昇順化実行結果
    my $min         = ${$sorted_jobs[0]}[1];
    my $max     = ${$sorted_jobs[$#sorted_jobs]}[1];
    my $gap = ($max + $min) / 2;
    my $magnification = 0;
    if ($gap <= 0.50) {
        $magnification = 0.01;
    } elsif ($gap <= 5) {
        $magnification = 0.1;
    } elsif ($gap <= 50) {
        $magnification = 1;
    } elsif ($gap <= 100) {
        $magnification = 10;
    } else {
        $magnification = 100;
    }
    
    # 検索結果を編集
    my $jobs = $#sorted_jobs;
    if ($measurement_list > $jobs) {
        $measurement_list = $jobs;
    }
    my $max_opid_digit = ${$sorted_jobs[$#sorted_jobs]}[0] =~ tr/0-9/0-9/;
    if ($max_opid_digit < 3) {$max_opid_digit = 3}
    my $max_time_digit = ${$sorted_jobs[$#sorted_jobs]}[1]  =~ tr/0-9\./0-9\./;
    foreach my $i (0..$measurement_list) {
        # スケール算出
        my $scale_mark = '*';
        my $scale = $scale_mark;
        foreach my $j (1..int(${$sorted_jobs[$i]}[1]/$magnification)){
            $scale .= $scale_mark;
        }
        # 時間情報へ保存
        push (@output_time_datas  , sprintf("%${max_opid_digit}d %${max_time_digit }.2f %s", $opid_jobseqs{${$sorted_jobs[$i]}[0]}, ${$sorted_jobs[$i]}[1], $scale));
        # オプション情報へ保存
        my $opid_compile_option = &get_compile_option(${$sorted_jobs[$i]}[0]);
        push (@output_option_datas, sprintf("%${max_opid_digit}d%s", $opid_jobseqs{${$sorted_jobs[$i]}[0]}, $opid_compile_option));
    }
    
    # OPEN
    open (RESULT, "> $output_file_name") or die "Cannot open  $output_file_name";
    # 編集結果を出力
    print RESULT "[探索結果]\n";
    print RESULT sprintf("%-${max_opid_digit}s %s \n", 'No.', 'TIME');
    print RESULT "--------------------------------------------------\n";
    foreach my $output_time_data (@output_time_datas) {
        print RESULT "$output_time_data\n";
    }
    print RESULT "\n";
    print RESULT "[オプション情報]\n";
    print RESULT sprintf("%-${max_opid_digit}s %s \n", 'No.', 'OPTION');
    print RESULT "--------------------------------------------------\n";
    foreach my $output_option_data (@output_option_datas) {
        print RESULT "$output_option_data\n";
    }
    # CLOSE
    close(RESULT);
}
1;
