package application_cpoption_searcher;

use strict;
use builtin;
use File::Spec;
use Time::HiRes;
use Coro;
use Coro::Channel;
use common;
use application_time_searcher;
use base qw(Exporter);
our @EXPORT = qw(initialize searcher set_initial_searcher get_search_information get_evaluation_value
                 entry_search_pattern initially finally evaluation output_result);

my  $search_matrix_file    = 'matrixfile';                                                    # マトリックスファイル名（排他・誘導等を定義したファイル）
my  $search_result         = 'search_result';                                                 # 結果出力ファイル名
my  $compile_comand        = 'frt';                                                           # コンパイルコマンド
my  $slp                   = 1;                                                               # sleep秒
my  $add_pair_options      = 1;                                                               # 対になるコンパイルオプション追加（1＝追加する、2＝追加しない）
my  @compile_keys          = ();                                                              # ユーザースクリプト内コンパイル文指定キー(compile1,compile2)
my  $jobseq                = 0;                                                               # ジョブシーケンス番号
my  $opid_seq              = 0;                                                               # オプションIDシーケンス情報
my  $comparison_target     = 0;                                                               # 比較対象

sub set_initial_searcher {
###################################################################################################
#   ＜＜ 探索初期設定 ＞＞                                                                        #
#-------------------------------------------------------------------------------------------------#
#   処理 ： テンプレートから探索用テンプレートを初期設定                                          #
#   引数 ： $_[0] ＝ テンプレート                                                                 #
#        ： $_[1] ＝ 探索作業用情報（←探索用テンプレート）                                       #
#   返却 ： 探索作業用情報 [ , 探索作業用情報２ [ , 探索作業用情報３ [ , ･･･ ] ] ]                #
###################################################################################################
    my %template            = %{shift(@_)};                                                   # テンプレート
    my %working_information = %{shift(@_)};                                                   # 探索作業用情報（←探索用テンプレート）
    my @compile_options     = ();                                                             # コンパイルオプション情報
    my $idx = -1;
    #-----------------------------------------------------------------------------------------#
    # 比較対象をチェック
    if (!exists $working_information{comparison_target}) { $working_information{comparison_target} = $comparison_target; }
    #if ($working_information{comparison_target} =~ /\D+/) { die "syntax error : comparison_target\n"; }
    if ($working_information{comparison_target} =~ /\D+/) { print "syntax error : comparison_target\n"; exit 255; }
    $searcher::shared_working_information{comparison_target} = $working_information{comparison_target};
    # Start Level
    $working_information{start_level} = -1;                                                   # 探索スタートレベル
    # RANGEをworking_informationへ退避、RANGEから探索範囲を初期設定
    foreach my $key (sort grep {$_ =~ /^RANGE[\d]+$/} keys %template) {
        @{$working_information{$key}} = @{$template{$key}};
        $key =~ /^RANGE([\d]+)$/;
        $idx = $1;
    }
    # argをworking_informationへ退避、argから探索範囲を初期設定
    foreach my $key (sort grep {$_ =~ /^arg[\d_]+\@*$/} keys %template) {
        if (ref ($template{$key}) eq 'ARRAY') {
            # Array
            @{$working_information{$key}} = @{$template{$key}};
            $idx++;
            $working_information{"link_RANGE$idx"} = $key;
            $searcher::shared_working_information{"link_RANGE$idx"} = $key;
            @{$working_information{"RANGE$idx"}} = (0..$#{$template{$key}});
        }
    }
    # コンパイルオプションを付与するargをチェック
    @{$searcher::shared_working_information{option_arg_key}} = grep {$_ =~ /^arg/ and $template{$_} eq 'compile_option'} keys %template;
    foreach my $key (@{$searcher::shared_working_information{option_arg_key}}) {
        delete $template{$key};
        $idx++;
        $working_information{"link_RANGE$idx"} = "$key";
        $searcher::shared_working_information{"link_RANGE$idx"} = "$key";
    }
    $searcher::shared_working_information{jobseq}                = -1;                        # ジョブSEQ
    %{$searcher::shared_working_information{stop_levels}}        = ();                        # 実行抑止レベル情報
    @{$searcher::shared_working_information{search_level_jobs}}  = ();                        # レベル別実行ジョブ（key=実行レベル番号、data=[オプションID,･･･]）
    @{$searcher::shared_working_information{compile_patterns_0}} = ();                        # パターン情報（key=オプションID、data=[オプションidx1,オプションidx2,･･･]）
    @{$searcher::shared_working_information{set_option_0}}       = ();                        # 設定済オプション情報（key=オプションID、data=[オプション,･･･]）
    # マトリックスファイルからマトリックス情報を取得
    my @matrix_data = ();
    if (exists $working_information{search_matrix_file}) {
        #if ($working_information{search_matrix_file} =~ /^\s+$/) { die "error : search_matrix_file is only blank\n"; }
        if ($working_information{search_matrix_file} =~ /^\s+$/) { print "error : search_matrix_file is only blank\n"; exit 255; }
        @matrix_data = &get_matrix_file("$working_information{search_matrix_file}");
    }
    # ユーザー指定のマトリックス情報を追加
    foreach my $matrix_key (sort grep {$_ =~ /matrix[\d]+/} keys %working_information) {
        push(@matrix_data, "$working_information{$matrix_key}");
    }
    # マトリックス情報へ反映
    @{$searcher::shared_working_information{matrix_files}} = &set_matrix_data(@matrix_data);
    # 対になるコンパイルオプション追加
    if (exists $working_information{add_pair_options}) { $working_information{add_pair_options} = $add_pair_options; }
    # 設定済オプションの初期設定
    if (exists $working_information{base_option}) {
        # ベースオプションあり
        my @base_options  = split (/\s/, $working_information{base_option});
        my @base_patterns = ();
        foreach my $base_option (@base_options) {
            push (@compile_options, ['',$base_option]);
            push (@base_patterns, 1);
            &upd_setting_option(0, 0, "", "$base_option");
        }
        unshift (@base_patterns, '');
        $searcher::shared_working_information{compile_patterns_0} = \@base_patterns;
        ${$working_information{next_compile_patterns}}{0} = \@base_patterns;
        # 探索開始レベルを設定
        $working_information{start_level} = @base_options;
    } else {
        # ベースオプションなし
        @{${$working_information{next_compile_patterns}}{0}} = ();
        &upd_setting_option(0, 0, "", "");
        # 探索開始レベルを設定
        $working_information{start_level} = 0;
    }
    # パターンファイルをオプション情報へ反映
    if (exists $working_information{search_pattern_file}) {
        @compile_options = &get_pattern_file_data($working_information{search_pattern_file}, @compile_options);
    }
    # グループ指定（group）
    foreach my $group_key (sort grep {$_ =~ /group[\d]+/} keys %working_information){
        foreach my $pattern_key (split (/,/, $working_information{$group_key})) {
            # 指定パターン名の存在確認
            if (exists $working_information{$pattern_key}) {
                # 指定パターンにグループ名付与
                my ($pattern_data, $group_name) = &cut_group_name($working_information{$pattern_key});
                $working_information{$pattern_key} = $pattern_data . $group_key;
            }
        }
    }
    # 並列実行指定（parallel）
    foreach my $parallel_key (sort grep {$_ =~ /parallel[\d]+/} keys %working_information) {
        my $parallel_num = 0;
        foreach my $pattern_key (split (/,/, $working_information{$parallel_key})) {
            #if (! exists $working_information{$pattern_key}) { die "error : There is not the pattern name or group name($pattern_key)\n"; }
            if (! exists $working_information{$pattern_key}) { print "error : There is not the pattern name or group name($pattern_key)\n"; exit 255; }
            $parallel_num++;
            # 「パラレル名_連番」をグループ名に追加付与
            if ($pattern_key =~ /group[\d]+/) {
                map {$working_information{$_} = $working_information{$_} . $parallel_key . '_' . $parallel_num; $_} grep {$working_information{$_} =~ /$pattern_key/} keys %working_information;
            } else {
                $working_information{$pattern_key} = $working_information{$pattern_key} . $parallel_key . '_' . $parallel_num;
            }
        }
    }
    # ユーザー指定パターンオプションをパターン化
    foreach my $pattern_key (sort grep {$_ =~ /pattern[\d]+/} keys %working_information){
        if ($working_information{$pattern_key} =~ /^\S+/) {
            # ユーザ指定情報を解析
            if ($working_information{$pattern_key} !~ /\}/) { $working_information{$pattern_key} = '{' . $working_information{$pattern_key} . '}'; }
            my @user_compile_options = &arrangement_compile_option($working_information{$pattern_key});
            # オプション情報に存在するかチェック
            my $lv = &chk_user_compile_option($working_information{start_level}, \@compile_options, \@user_compile_options);
            if ($lv >= 0) {
                # 既存のグループ化を解除
                my $delete_group_name = ${$compile_options[$lv]}[0];
                @compile_options = map {${$_}[0] =~ s/$delete_group_name//; $_;} @compile_options;
                # オプション情報を更新
                $compile_options[$lv] = \@user_compile_options;
            } else {
                # オプション情報に追加
                push (@compile_options, \@user_compile_options);
            }
        } else {
            #die "error : There is blank in the top of $pattern_key\n";
            print "error : There is blank in the top of $pattern_key\n";
            exit 255;
        }
    }
    # 並列オプションチェック
    @compile_options = &chk_parallel_option(@compile_options);
    # 同レベル等価オプションチェック
    @compile_options = &chk_exists_option(@compile_options);
    # グループ化整合性チェック
    @compile_options = &chk_group_consistency(@compile_options);
    # 排他オプションのグループ化
    @compile_options = &grouping_exclusion_option(@compile_options);
    # 同時実行オプションのグループ化
    @compile_options = &grouping_simultaneous_option(@compile_options);
    # 順序指定オプションによる並び替え
    @compile_options = &sort_compile_option(@compile_options);
    # 対になるオプションの追加
    if ($working_information{add_pair_options} eq '1') { @compile_options = &add_opposite_option(\@compile_options, $working_information{start_level}); }
    # 並列オプションの並び替え
    @compile_options = &sort_parallel_option(\@compile_options, (sort grep {$_ =~ /parallel[\d]+/} keys %working_information));
    # オプション情報の並び換え
    @compile_options = &sort_group_option(@compile_options,);
    for (my $i = 0; $i <= $#compile_options; $i++) {
        @{$searcher::shared_working_information{"compile_options_$i"}} = @{$compile_options[$i]};
    }
    $searcher::shared_working_information{compile_options_max} = $#compile_options;
    ($working_information{start_level}, $working_information{search_level}) = &next_search_level($working_information{start_level});
    #-----------------------------------------------------------------------------------------#
    # Return（探索作業用情報）
    return \%working_information;
}
sub get_pattern_file_data {
###################################################################################################
#   ＜＜ パターンファイル情報取得 ＞＞                                                            #
###################################################################################################
    my $search_pattern_file = shift;                                                          # パターンファイル名
    my @compile_options     = @_;                                                             # コンパイルパターン情報
    my $compile_option_base = $#compile_options;
    my %group_options       = ();                                                             # グループ情報（key=グループ名、data=グループ化する数）
    #-----------------------------------------------------------------------------------------#
    # Open
    #open (PATTERN, "< $search_pattern_file") or die "get_pattern_file_data : Cannot open $search_pattern_file\n";
    open (PATTERN, "< $search_pattern_file") or print "get_pattern_file_data : Cannot open $search_pattern_file\n";
    # パターンファイル情報を取得
    while (my $line = <PATTERN>) {
        if ($line =~ /^\#/) { next; }
        chomp $line;
        if ($line =~ /^[\s\t]*$/) { next; }
        if ($line =~ /^END$/) { last; }
        #unless ($line =~ /^-[A-Za-z][^\s\r\{\}\[\]\(\)]*\{[^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
        #        $line =~ /^-\{[A-Za-z][^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
        #        $line =~ /^\{-[A-Za-z][^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
        #        $line =~ /^-[A-Za-z][^\s\r\{\}\[\]]*$/ ) {
        #    die "syntax error : $search_pattern_file\n";
        unless ($line =~ /^-[A-Za-z][^\s\r\{\}\(\)]*\{[^\{\}]*\}[^\s\r\{\}\(\)]*$/ or
                $line =~ /^-\{[A-Za-z][^\{\}]*\}[^\s\r\{\}\(\)]*$/ or
                $line =~ /^\{-[A-Za-z][^\{\}]*\}[^\s\r\{\}\(\)]*$/ or
                $line =~ /^-[A-Za-z][^\s\r\{\}]*$/ ) {
            print "syntax error : $search_pattern_file($line)\n";
            exit 255;
        }
        # パターンをパターンファイル情報へ追加
        my @line_compile_options = &arrangement_compile_option($line);
        foreach my $matrix_file (grep {${$_}[1] =~ /-/} @{$searcher::shared_working_information{matrix_files}}) {
            foreach my $lv (0..$compile_option_base) {
                my @line_compile_options_upd = ($line_compile_options[0]);
                foreach my $op2 (1..$#line_compile_options) {
                    if ((grep {$line_compile_options[$op2] =~ /(^|\s)$_($|\s)/} @{$matrix_file}) > 0) {
                        my $flg = 0;
                        foreach my $op (1..$#{$compile_options[$lv]}) {
                            if ((grep {${$compile_options[$lv]}[$op] =~ /(^|\s)$_($|\s)/} @{$matrix_file}) > 0) { $flg = 1; }
                        }
                        if ($flg == 0) {
                            push(@line_compile_options_upd, $line_compile_options[$op2]);
                        }
                    } else {
                            push(@line_compile_options_upd, $line_compile_options[$op2]);
                    }
                }
                @line_compile_options = @line_compile_options_upd;
            }
        }
        if ($#line_compile_options > 0) {
            if ($line_compile_options[0] ne '') { $group_options{$line_compile_options[0]}++; }
            push (@compile_options, \@line_compile_options);
        }
    }
    # Close
    close(PATTERN);
    
    # グループ化正しいかチェック
    my $group_idx = 0;
    foreach my $group_option_key (keys %group_options) {
        if ($group_options{$group_option_key} > 1) {
            # グループ名をパターンファイルグループに統一
            $group_idx++;
            @compile_options = map {${$_}[0] =~ s/$group_option_key/pattern_file_group$group_idx/; $_;} @compile_options;
        } else {
            warn "$group_option_key is not group\n";
            @compile_options = map {${$_}[0] =~ s/$group_option_key//; $_;} @compile_options;
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub arrangement_compile_option {
###################################################################################################
#   ＜＜ パターンを配列化 ＞＞                                                                    #
###################################################################################################
    my ($line)            = @_;                                                               # パターン情報（文字列）
    my @arrangement_lines = ();                                                               # 配列化情報
    #-----------------------------------------------------------------------------------------#
    # パターンからグループ名を切り出す
    my ($line_str, $group_name) = &cut_group_name($line);
    # パターンを配列化
    @arrangement_lines = &cut_space(split (/[{|}]/, $line_str));
    if ($arrangement_lines[$#arrangement_lines] eq '') {pop (@arrangement_lines);}
    foreach my $i (1..$#arrangement_lines) { $arrangement_lines[$i] = $arrangement_lines[0].$arrangement_lines[$i]; }
    if ($#arrangement_lines == 0) { $arrangement_lines[1] = $arrangement_lines[0]; }
    # グループ名を設定
    $arrangement_lines[0] = $group_name;
    #-----------------------------------------------------------------------------------------#
    # Return（配列化情報）
    return @arrangement_lines;
}
sub cut_group_name {
###################################################################################################
#   ＜＜ パターンからグループ名を切り出す ＞＞                                                    #
###################################################################################################
    my ($line) = @_;                                                                          # 解析対象文字列
    #-----------------------------------------------------------------------------------------#
    if ($line =~ /\}([\S]+)$/) {
        my @arrangement_lines = split (/$1/, $line);
        return ($arrangement_lines[0], $1);
    } else {
        return ($line, '');
    }
}
sub cut_space {
###################################################################################################
#   ＜＜ 不要空白カット ＞＞                                                                      #
###################################################################################################
    my @arrangement_lines = @_;                                                               # 配列データ
    #-----------------------------------------------------------------------------------------#
    foreach my $i (1..$#arrangement_lines) { $arrangement_lines[$i] =~ s/^\s*(.*?)\s*$/$1/; }
    #-----------------------------------------------------------------------------------------#
    # Return
    return @arrangement_lines;
}
sub chk_user_compile_option {
###################################################################################################
#   ＜＜ 上書きパターン有無チェック ＞＞                                                          #
###################################################################################################
    my $start_level          = shift(@_);
    my @compile_options      = @{shift(@_)};
    my @user_compile_options = @{shift(@_)};
    #-----------------------------------------------------------------------------------------#
    foreach my $lv ($start_level..$#compile_options) {
        foreach my $i (1..$#user_compile_options) {
            if ((grep {$_ =~ /^$user_compile_options[$i]$/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) > 0) { 
                return $lv; }
        }
    }
    #-----------------------------------------------------------------------------------------#
    # 上書きパターン無しを返却
    return -1;
}
sub get_matrix_file {
###################################################################################################
#   ＜＜ マトリックスファイル情報を取得 ＞＞                                                      #
###################################################################################################
    my $search_matrix_file = shift;                                                           # マトリクスファイル名
    my @matrix_files       = ();                                                              # マトリクスファイル情報
    my %count              = ();                                                              # マトリックスファイル行の重複チェック
    #-----------------------------------------------------------------------------------------#
    # OPEN
    #open (MATRIX, "< $search_matrix_file") or die "get_matrix_file : Cannot open $search_matrix_file\n";
    open (MATRIX, "< $search_matrix_file") or print "get_matrix_file : Cannot open $search_matrix_file\n";
    # マトリクスファイル情報を取得
    while (my $line = <MATRIX>) {
        if ($line =~ /^\#/) { next; }
        chomp $line;
        if (++$count{$line} >= 2) { next; }
        if ($line =~ /^[\s\t]*$/) { next; }
        push (@matrix_files, "$line");
    }
    # CLOSE
    close(MATRIX);
    #-----------------------------------------------------------------------------------------#
    # Return（マトリクスファイル情報）
    return @matrix_files;
}
sub set_matrix_data {
###################################################################################################
#   ＜＜ マトリックス情報の設定 ＞＞                                                              #
###################################################################################################
    my @matrix_data   = @_;                                                                   # マトリクスファイル情報
    my @matrix_files  = ();
    my @upper_options = ();                                                                   # 継承関係オプション情報（data＝[オプション,･･･]）
    my %count         = ();                                                                   # マトリックスファイル行の重複チェック
    #-----------------------------------------------------------------------------------------#
    # 誘導オプション 「-O,+(-a,-b,-c)」
    # 排他オプション 「-O,-(-d,-e)」
    foreach my $line (@matrix_data) {
        if ($line =~ /^-[A-Za-z].*<.+$/) {
print "a\n";

            push (@upper_options, [split (/</, $line)]);
            push (@matrix_files, ["","",split (/</, $line)]);
        } elsif ($line =~ /^\([^\{\}\[\]\(\)]+\)\,\+\([^\{\}\[\]\(\)]+\)$/) {
print "b\n";

            my @matrixs = grep {$_ ne ''} &cut_space(split (/[\,\(\)]/, $line));
            my @new_matrixs = ();
            $new_matrixs[0] = [$matrixs[0],$matrixs[1]];
            @new_matrixs = (@new_matrixs, @matrixs[2..$#matrixs]);
            if ($new_matrixs[$#new_matrixs] eq '') {pop (@new_matrixs);}
            push (@matrix_files, \@new_matrixs);
        } elsif ($line =~ /(^-[A-Za-z][^\s\r\{\}\[\]\(\)]*|^)\,(\+|-|&|=|=>)\([^\{\}\[\]\(\)]+\)$/) {
print "c\n";

            my @matrixs = &cut_space(split (/[\,\(\)]/, $line));
            if ($matrixs[$#matrixs] eq '') {pop (@matrixs);}
            push (@matrix_files, \@matrixs);
            my @matrixs2 = @matrixs;
            if ($matrixs2[1] =~ /^=$/) {
                $matrixs2[1] = '+';
                push (@matrix_files, \@matrixs2);
            }
        } else {
             #die "get_matrix_file : syntax error matrix_file($line)\n";
             print "get_matrix_file : syntax error matrix_file($line)\n";
             exit 255;
        }
    }
    # 継承関係を追加マトリックスファイル情報に反映
    my @add_matrix_files;
    foreach my $matrix_file (grep {${$_}[1] eq '='} @matrix_files) {
        foreach my $chk_matrix (grep {${$_}[1] eq '-'} @matrix_files) {
            if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$chk_matrix}[2..$#{$chk_matrix}]) > 0) {
                my @temp_matrix_data = @{$matrix_file};
                $temp_matrix_data[0] = ${$chk_matrix}[0];
                $temp_matrix_data[1] = '-';
                push (@add_matrix_files, \@temp_matrix_data);
            } elsif (${$matrix_file}[0] eq ${$chk_matrix}[0]) {
                my @temp_matrix_data = @{$matrix_file};
                $temp_matrix_data[0] = ${$chk_matrix}[2];
                $temp_matrix_data[1] = '-';
                push (@add_matrix_files, \@temp_matrix_data);
            }
        }
    }
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
                    my @upper_matrix_files = grep {${$_}[0] eq ${$upper_option}[$upper_idx] and ${$_}[1] eq $temp_matrix_data[1]} @matrix_files;
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
                    my @upper_matrix_files = grep {${$_}[2] eq ${$upper_option}[$upper_idx] and ${$_}[1] eq '&'} @matrix_files;
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
    #-----------------------------------------------------------------------------------------#
    # Return（マトリクスファイル情報）
    return @matrix_files;
}
sub chk_opposite_option {
###################################################################################################
#   ＜＜ 対になるオプションの検索 ＞＞                                                            #
###################################################################################################
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
sub compare_opposite_option {
###################################################################################################
#   ＜＜ 対になるオプションの文字列比較 ＞＞                                                      #
###################################################################################################
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
        if ($search_str ne '^') { $search_str .= '(no|no_|no-){0,1}'; }
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
sub chk_parallel_option {
###################################################################################################
#   ＜＜ 並列オプションチェック ＞＞                                                              #
###################################################################################################
    my @compile_options       = @_;                                                           # コンパイルオプション情報
    my @check_compile_options = grep {${$_}[0] =~ /parallel[\d]+_/} @compile_options;         # parallel情報
    #-----------------------------------------------------------------------------------------#
    # 並列化したいオプションの中に同時実行オプションがあるかチェック
    foreach my $matrix_file (grep {${$_}[1] =~ /[&-]/} @{$searcher::shared_working_information{matrix_files}}) {
        my @matched_lvs = ();
        foreach my $matrix (@{$matrix_file}) {
            push (@matched_lvs, grep {grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$check_compile_options[$_]}} 0..$#check_compile_options);
        }
        my %parallel_names = ();
        grep {$parallel_names{${$check_compile_options[$_]}[0]}++} @matched_lvs;
        # 並列オプション間で同時実行オプションが存在した場合警告＆無効化
        if (keys %parallel_names < 2) { next; }
        my %count = ();
        grep {$parallel_names{$_} =~ /(parallel[\d]+_)/; $count{$1}++;} keys %parallel_names;
        if (${$matrix_file}[1] eq '-' and keys %count <= 2) { next; }
        warn "can't parallel\n";
        foreach my $parallel_name (keys %parallel_names) { @compile_options = map {${$_}[0] =~ s/$parallel_name//g; $_} @compile_options; }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub chk_exists_option {
###################################################################################################
#   ＜＜ 同レベル等価オプションチェック ＞＞                                                      #
###################################################################################################
    my @compile_options = @_;                                                                 # コンパイルオプション情報
    #-----------------------------------------------------------------------------------------#
    # 同レベルに等価オプションがあるかチェック
    foreach my $matrix_file (grep {${$_}[1] =~ /^=$/} @{$searcher::shared_working_information{matrix_files}}) {
        foreach my $lv (0..$#compile_options) {
            if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) == 0) { next; }
            my @temp_compile_options = (${$compile_options[$lv]}[0]);
            foreach my $op (1..$#{$compile_options[$lv]}) {
                if ((grep {${$compile_options[$lv]}[$op] =~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]) > 0) { next; }
                push (@temp_compile_options, ${$compile_options[$lv]}[$op]);
            }
            @{$compile_options[$lv]} = @temp_compile_options;
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub chk_group_consistency {
###################################################################################################
#   ＜＜ グループ化整合性チェック ＞＞                                                            #
###################################################################################################
    my @compile_options = @_;                                                                 # コンパイルオプション情報
    my $group_name = 'add_group';                                                             # グループ名Prefix
    my $group_idx  = 0;                                                                       # グループindex
    #-----------------------------------------------------------------------------------------#
    # マトリックス通りにグループ化した場合の整合性チェック
    foreach my $matrix_file (grep {${$_}[1] =~ /[&-]/} @{$searcher::shared_working_information{matrix_files}}) {
        # 基点となるオプションの検索
        my $root_level = -1;
        foreach my $lv (0..$#compile_options) {
            if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) == 0) { next; }
            $root_level = $lv;
            last;
        }
        if ( $root_level < 0 ) { next; }
        # 対象となるオプションの検索
        my @matched_lvs = ();
        foreach my $lv (0..$#compile_options) {
            if (${$matrix_file}[1] eq '&' and $root_level > $lv) { next; }
            foreach my $i (2..$#{$matrix_file}){
                if ((grep {$_ =~ /(^|\s)${$matrix_file}[$i]($|\s)/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) == 0) { next; }
                push (@matched_lvs, $lv);
            }
        }
        if ($#matched_lvs < 0) { next; }
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
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub grouping_exclusion_option {
###################################################################################################
#   ＜＜ 排他オプショングループ化展開 ＞＞                                                        #
###################################################################################################
    my @compile_options = @_;                                                                 # コンパイルオプション情報
    #-----------------------------------------------------------------------------------------#
    #探索パターンに排他オプションがあるか検索してグループ化
    foreach my $matrix_file (grep {${$_}[1] eq '-'} @{$searcher::shared_working_information{matrix_files}}){
        # 排他の起点になるオプションが存在するかチェック
        my @exclusion_idx_datas = [&search_compile_option(${$matrix_file}[0], 0, \@compile_options)];
        if (${$exclusion_idx_datas[0]}[1] == 9999) { next; }
        # 排他先のオプションの検索
        foreach my $i (2..$#{$matrix_file}) {
            my @exclusion_idxs = &search_compile_option(${$matrix_file}[$i], 1, \@compile_options);
            if ($exclusion_idxs[1] < 9999) { push (@exclusion_idx_datas, @exclusion_idxs); }
        }
        if (@exclusion_idx_datas <= 0) { next; }
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
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub grouping_simultaneous_option {
###################################################################################################
#   ＜＜ 同時実行指定オプションのグループ化 ＞＞                                                  #
###################################################################################################
    my @compile_options = @_;                                                                 # コンパイルオプション情報
    #-----------------------------------------------------------------------------------------#
    # 探索パターンに同時実行指定オプションがあるか検索してグループ化
    foreach my $matrix_file (grep {${$_}[1] =~ /&/} @{$searcher::shared_working_information{matrix_files}}) {
        # 起点オプションを検索
        my @exclusion_idxs = &search_compile_option(${$matrix_file}[0], 1, \@compile_options);
        if ($exclusion_idxs[1] == 9999) { next; }
        # 同時実行指定オプションを検索
        foreach my $idx (@exclusion_idxs) {
            my $compile_option = ${$compile_options[${$idx}[0]]}[${$idx}[1]];
            my @add_compile_options = grep {$compile_option !~ /(^|\s)$_($|\s)/}
                                      grep {my $simultaneous_option = $_;
                                           grep { grep {$_ =~ /(^|\s)$simultaneous_option($|\s)/} @{$compile_options[$_]}
                                                } ${$idx}[0]..$#compile_options;
                                           } @{$matrix_file}[2..$#{$matrix_file}];
            if (@add_compile_options > ()) {
                $compile_option .= ' '. join(' ', @add_compile_options);
                ${$compile_options[${$idx}[0]]}[${$idx}[1]] = $compile_option;
            }
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub search_compile_option {
###################################################################################################
#   ＜＜オプションindex取得 ＞＞                                                                  #
###################################################################################################
    my $op_name         = shift;                                                              # 検索オプション名
    my $target          = shift;                                                              # ターゲット
    my @compile_options = @{shift(@_)};                                                       # コンパイルオプション情報
    my @search_option   = ();                                                                 # 検索結果
    #-----------------------------------------------------------------------------------------#
    if ($op_name =~ /=\*$/) { $op_name =~ s/=\*$/.+/; }
    foreach my $lv (0..($#compile_options)) {
        foreach my $i (1..$#{$compile_options[$lv]}) {
            if ("${$compile_options[$lv]}[$i]" !~ /^${op_name}$/) { next; }
            if ($target eq 0) {
                #-----------------------------------------------------------------------------#
                # Return（起点オプション）
                return ($lv,$i);
            }
            push (@search_option, [$lv,$i]);
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（対象オプション）
    if (@search_option > ()) {
        return @search_option;
    } else {
        return (0,9999);
    }
}
sub sort_compile_option {
###################################################################################################
#   ＜＜ 順序指定オプションによる並び替え ＞＞                                                    #
###################################################################################################
    my @compile_options = @_;
    #-----------------------------------------------------------------------------------------#
    # 探索パターンに順序指定オプションがあるか検索してグループ化
    foreach my $matrix_file (grep {${$_}[1] =~ /=>/} @{$searcher::shared_working_information{matrix_files}}) {
        my $option1_lv = -1;
        my $option2_lv = -1;
        # オプションを検索してindex化
        foreach my $lv (0..$#compile_options) {
            my $data_max = $#{$compile_options[$lv]};
            # 起点オプション有無をチェック
            if ((grep{$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/}@{$compile_options[$lv]}[1..$data_max]) > 0) {
                # （起点オプションあり）
                # 基点となるオプションのオプション情報indexを取得
                $option1_lv = &get_compile_option_level($lv, $option2_lv, @compile_options);
            # 並び替え対象オプション有無をチェック
            } elsif ((grep{$_ =~ /(^|\s)${$matrix_file}[2]($|\s)/}@{$compile_options[$lv]}[1..$data_max]) > 0) {
                # 並び替え対象オプションのオプション情報indexを取得
                $option2_lv = &get_compile_option_level($lv, $option1_lv, @compile_options);
            }
        }
        
        # 並べ替え対象かチェック
        if ($option1_lv >= 0 and $option2_lv >= 0 and $option1_lv > $option2_lv) {
            # （並べ替え対象）
            my $sort_compile_option = splice (@compile_options, $option1_lv, 1);
            splice (@compile_options, $option2_lv, 0, $sort_compile_option);
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub get_compile_option_level {
###################################################################################################
#   ＜＜ 対象オプションのレベル取得 ＞＞                                                          #
###################################################################################################
    my $lv              = shift;                                                                          # 対象オプションのレベル, 比較するオプションのレベル
    my $optionX_lv      = shift;                                                                          # 対象オプションのレベル, 比較するオプションのレベル
    my @compile_options = @_;
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
sub add_opposite_option {
###################################################################################################
#   ＜＜ 対になるオプションの追加 ＞＞                                                            #
###################################################################################################
    my @compile_options = @{shift(@_)};
    my $start_level     = @_;                                                            # パターンファイル名
    #-----------------------------------------------------------------------------------------#
    foreach my $lv ($start_level..$#compile_options) {
        my $compile_option = ${$compile_options[$lv]}[$#{$compile_options[$lv]}];
        foreach my $matrix_data (@{$searcher::shared_working_information{matrix_files}}) {
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
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub sort_parallel_option {
###################################################################################################
#   ＜＜ 並列オプションのソート ＞＞                                                              #
###################################################################################################
    my @compile_options = @{shift(@_)};
    my @parallel_keys   = @_;
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
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub sort_group_option {
###################################################################################################
#   ＜＜ オプション情報の並び換え ＞＞                                                            #
###################################################################################################
    my @compile_options = @_;
    %{$searcher::shared_working_information{stop_levels}} = ();                               # 実行抑止レベル情報
    my @new_compile_options  = ();                                                            # 再生成するオプション情報
    my @delete_levels        = ();                                                            # グループ化により追加したレベルの一覧
    unshift (@compile_options, []);
    unshift (@new_compile_options, []);
    #-----------------------------------------------------------------------------------------#
    foreach my $lv (1..$#compile_options){
        if ((grep {$lv == $_} @delete_levels) != ()) { next; }
        # グループ名有無をチェック
        if (${$compile_options[$lv]}[0] =~ /^(group[\d]+|pattern_file_group[\d]+)/) {
            # （グループあり）
            my $group_name = $1;
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
            @{${$searcher::shared_working_information{stop_levels}}{$#new_compile_options}} = @stop_level;
        } else {
            # （グループなし）
            push (@new_compile_options, $compile_options[$lv]);
        }
    }
    
    # オプション情報を更新
    @compile_options = @new_compile_options;
    #-----------------------------------------------------------------------------------------#
    # Return（コンパイルオプション情報）
    return @compile_options;
}
sub entry_search_pattern {
###################################################################################################
#   ＜＜ 探索パターン設定 ＞＞                                                                    #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 探索(prepare)するパターンを設定                                                       #
#   引数 ： $_[0] ＝ テンプレート                                                                 #
#        ： $_[1] ＝ 探索用テンプレート                                                           #
#   返却 ： テンプレート                                                                          #
###################################################################################################
    my %template            = %{shift(@_)};
    my %working_information = %{shift(@_)};
    my @parent_opkey        = sort grep {$_ =~ /^compile_patterns_(.+)/} keys %searcher::shared_working_information;
    my %parent_opids        = ();
    my %parent_opids_add    = ();
    my %parent_opids_out    = ();
    #-----------------------------------------------------------------------------------------#
    # オプションの組合せ展開
    if (${$searcher::shared_working_information{"compile_options_$working_information{start_level}"}}[0] =~ /(parallel[\d]+_)/) {
        # 次のレベルが並列対象
        my $parallel_name = $1;
        my @compile_options_key = (sort grep {$_ =~ /compile_options_\d/} keys %searcher::shared_working_information);
        my @parallel_key = (sort grep {${$searcher::shared_working_information{$_}}[0] =~ /$parallel_name/} @compile_options_key);
        $parallel_key[$#parallel_key] =~ /compile_options_(\d+)/;
        for (my $i = 0; $i <= $#parallel_key; $i++) {
            if ($#parallel_key > $i and
                ${$searcher::shared_working_information{$parallel_key[$i]}}[0] =~ /^group/ and
                ${$searcher::shared_working_information{$parallel_key[$i]}}[0] eq ${$searcher::shared_working_information{$parallel_key[($i + 1)]}}[0]) { next; }
            %parent_opids = &dev_compile_pattern(\%working_information, %parent_opids);
            if ($parallel_key[$#parallel_key] ne $parallel_key[$i]) {
               ($working_information{start_level}, $working_information{search_level}) = &next_search_level($working_information{search_level});
                foreach my $key (keys %parent_opids) {
                    $parent_opids_add{$key} = $parent_opids{$key};
                }
                %parent_opids = ();
            }
        }
        
        foreach my $key (keys %parent_opids_add) {
            $parent_opids{$key} = $parent_opids_add{$key};
        }
    } else {
        %parent_opids = &dev_compile_pattern(\%working_information, ());
    }
    # 誘導オプションチェック
    &optimization_compile_option(\%parent_opids, $working_information{search_level});
    # 実行対象のオプションIDを取得
    my @opids = ();
    if (exists $working_information{base_option} and $searcher::shared_working_information{last_opids} == 0) {
        push (@opids, 0);
    }
    my @opids_temp = sort grep {$_ =~ /^compile_patterns_/} keys %searcher::shared_working_information;
    foreach my $key (@opids_temp) {
        if ((grep {$_ =~ /^$key$/} @parent_opkey) == 0) {
            $key =~ s/^compile_patterns_//;
            push (@opids, $key);
            $searcher::shared_working_information{last_opids} = $key;
        }
    }
    foreach my $key (sort grep {$_ =~ /^RANGE[\d]+$/} keys %working_information) {
        $template{$key} = [0..$#{$working_information{$key}}];
    }
    # ジョブseq情報を生成
    my @set_range = ();
    foreach my $opid (@opids) {
        $searcher::shared_working_information{jobseq}++;
        $searcher::shared_working_information{"jobseq_$searcher::shared_working_information{jobseq}"} = $opid;
        # ユーザ指定のargにコンパイルオプションを設定
        my $opid_compile_option = &get_compile_option($opid);
        foreach my $arg_key (@{$searcher::shared_working_information{option_arg_key}}) {
            ${$searcher::shared_working_information{$arg_key}}[$searcher::shared_working_information{jobseq}] = "$opid_compile_option";
        }
        push (@set_range, $searcher::shared_working_information{jobseq});
    }
    # RANGEへジョブseq(＝argのindex)を設定
    foreach my $arg_key (@{$searcher::shared_working_information{option_arg_key}}) {
        foreach my $key (sort grep {$_ =~ /^link_RANGE[\d]+$/ and $working_information{$_} eq "$arg_key"} keys %searcher::shared_working_information) {
            $key =~ /^link_(RANGE[\d]+)$/;
            $template{$1} = \@set_range;
        }
        $template{"$arg_key\@"} = \@{$searcher::shared_working_information{$arg_key}};
    }
    #-----------------------------------------------------------------------------------------#
    # Return（テンプレート）
    return %template;
}
sub next_search_level {
###################################################################################################
    my $search_level = shift;
    #-----------------------------------------------------------------------------------------#
    $search_level++;
    while ($searcher::shared_working_information{compile_options_max} > $search_level and @{$searcher::shared_working_information{"compile_options_$search_level"}} == 1) {
        $search_level++;
    }
    my $start_level = $search_level;
    foreach my $key (sort {$a <=> $b} keys %{$searcher::shared_working_information{stop_levels}}) {
        if ($search_level >= $key) { next; }
        if ((grep{$_ eq $search_level} @{${$searcher::shared_working_information{stop_levels}}{$key}}) <= 0) { next; }
        $search_level = $key;
        last;
    }
    #-----------------------------------------------------------------------------------------#
    # Return（探索スタートレベル、実行レベル）
    return $start_level, $search_level;
}
sub dev_compile_pattern {
###################################################################################################
#   ＜＜ オプションのパターン化 ＞＞                                                              #
###################################################################################################
    my %working_information = %{shift(@_)};
    my %parent_opids        = @_; 
    #-----------------------------------------------------------------------------------------#
    # オプションの組合せ展開
    my %in_compile_patterns  = %{$working_information{next_compile_patterns}};
    my @in_compile_patterns_keys = sort {$a <=> $b} keys %{$working_information{next_compile_patterns}};
    foreach my $lv ($working_information{start_level}..$working_information{search_level}) {
        @{${$searcher::shared_working_information{search_level_jobs}}[$lv]} = ();
        if (!exists $searcher::shared_working_information{"compile_options_$lv"}) { next; }
        if (@{$searcher::shared_working_information{"compile_options_$lv"}} == 0) { next; }
        my @cpop = @{$searcher::shared_working_information{"compile_options_$lv"}};
        my %out_compile_patterns = ();
        foreach my $parent_opid (sort {$a <=> $b} keys %in_compile_patterns ) {
            my $parent_pattern;
            # 指定オプションを展開
            if ($parent_opid ne "0") {
                if ($lv == $working_information{start_level}) {
                    # （グループ化なし、又はグループ化の最初のレベル）
                    $parent_pattern = &get_compile_option($parent_opid)
                } else {
                    # （グループ化あり）
                    foreach my $i (1..$#{$in_compile_patterns{$parent_opid}}) {
                        if (${$in_compile_patterns{$parent_opid}}[$i] > 0) {
                            my @cpop_str = @{$searcher::shared_working_information{"compile_options_$i"}};
                            $parent_pattern .= ' '. $cpop_str[${$in_compile_patterns{$parent_opid}}[$i]];
                        }
                    }
                }
            }
            # 同時実行オプション対象かチェック
            my $compile_options_str = '(^|\s)'.join('(\s|$)|(^|\s)', @cpop[1..$#cpop]).'(\s|$)';
            if ($parent_pattern =~ /$compile_options_str/) {
                # （スキップ対象）
                if (exists ${$searcher::shared_working_information{stop_levels}}{$working_information{search_level}}) {
                    @{$out_compile_patterns{$parent_opid}} = @{$in_compile_patterns{$parent_opid}};
                    if ($lv == $working_information{search_level}) {
                        push (@{$searcher::shared_working_information{"search_level_jobs_$lv"}}, "$parent_opid");
                    }
                    next;
                }
            }
            if ($#cpop eq 1) {
                @{$out_compile_patterns{$parent_opid}} = @{$in_compile_patterns{$parent_opid}};
                if ($lv == $working_information{search_level}) {
                    # オプションIDをレベル別実行ジョブに登録
                    push (@{$searcher::shared_working_information{"search_level_jobs_$lv"}}, "$parent_opid");
                }
            }
            foreach my $i (1..$#cpop) {
                # 設定済(誘導含む)オプションかチェック
                my $search_level_option_index = '';
                if ((grep {$cpop[$i] =~ /(^|\s)$_(\s|$|\*)/} @{$searcher::shared_working_information{"set_option_$parent_opid"}}) == 0 and
                    (grep {$_ =~ /(^|\s)$cpop[$i](\s|$|\*)/} @{$searcher::shared_working_information{"set_option_$parent_opid"}}) == 0) {
                    # （未設定）
                    $search_level_option_index = $i;
                    if (!exists $searcher::shared_working_information{"search_level_$working_information{search_level}"}) { @{$searcher::shared_working_information{"search_level_$working_information{search_level}"}} = (); }
                    foreach my $key (grep {$_ =~ /^jobseq_/} keys %searcher::shared_working_information) {
                        if ($parent_opid eq $searcher::shared_working_information{$key}) {
                            foreach my $key2 (keys %{$searcher::shared_working_information{result_jobseq}}) {
                                if ($key eq "jobseq_${$searcher::shared_working_information{result_jobseq}}{$key2}") {
                                    push (@{$searcher::shared_working_information{"search_level_$working_information{search_level}"}}, $key2);
                                }
                            }
                        }
                    }
                }
                # 設定すべきオプションかチェック
                my $flg_out = '';
                if ($lv == ($working_information{start_level} + 1) or
                   ($search_level_option_index != "${$in_compile_patterns{$parent_opid}}[$lv]")) {
                    # パターン情報に登録
                    $opid_seq++;
                    @{$out_compile_patterns{$opid_seq}} = @{$in_compile_patterns{$parent_opid}};
                    @{$searcher::shared_working_information{"set_option_$opid_seq"}} = @{$searcher::shared_working_information{"set_option_$parent_opid"}};
                    if ($search_level_option_index ne ${$out_compile_patterns{$opid_seq}}[$lv]) {
                        &upd_setting_option($lv, $opid_seq, "$cpop[${$out_compile_patterns{$opid_seq}}[$lv]]", "$cpop[$search_level_option_index]");
                        ${$out_compile_patterns{$opid_seq}}[$lv] = "$search_level_option_index";
                    }
                    if ((&chk_setting_option($opid_seq, $cpop[$search_level_option_index])) == 0) {
                        $flg_out = 1;
                        if ($lv == $working_information{search_level}) {
                            # （グループ化なし、又はグループ化の最後のレベル）
                            # オプションIDをレベル別実行ジョブに登録
                            push (@{$searcher::shared_working_information{"search_level_jobs_$lv"}}, "$opid_seq");
                            # 親オプションID情報に登録
                            $parent_opids{$opid_seq} = "$parent_opid";
                        }
                    } else {
                        delete $out_compile_patterns{$opid_seq};
                        delete $searcher::shared_working_information{"set_option_$opid_seq"};
                    }
                }
                if ($flg_out eq '') {
                    @{$out_compile_patterns{$parent_opid}} = @{$in_compile_patterns{$parent_opid}};
                    if ($lv == $working_information{search_level}) {
                        # オプションIDをレベル別実行ジョブに登録
                        push (@{$searcher::shared_working_information{"search_level_jobs_$lv"}}, "$parent_opid");
                    }
                }
            }
        }
        %in_compile_patterns = %out_compile_patterns;
        # パターン情報に追加
        if ($lv == $working_information{search_level}) {
            foreach my $key (keys %out_compile_patterns) {
                $searcher::shared_working_information{"compile_patterns_$key"} = $out_compile_patterns{$key};
            }
            # 親オプションIDをレベル別実行ジョブに登録
            if ($working_information{start_level} > 1) {
                push (@{$searcher::shared_working_information{"search_level_jobs_$lv"}}, @in_compile_patterns_keys);
            }
        }
    }
    
    #-----------------------------------------------------------------------------------------#
    # Return（親オプションID情報）
    return %parent_opids;
}
sub get_compile_option {
###################################################################################################
#   ＜＜ コンパイルオプション取得 ＞＞                                                            #
###################################################################################################
    my ($opid)         = @_;                                                                  # オプションID
    my $compile_option = '';                                                                  # 展開オプション
    my $opid_compile_option = '';                                                             # 返却オプション
    my @opid_compile_patterns = @{$searcher::shared_working_information{"compile_patterns_$opid"}};    # 指定オプションIDのコンパイルパターン情報
    my %option_count = ();                                                                    # オプション名重複チェック用
    #-----------------------------------------------------------------------------------------#
    # 指定オプションを展開
    foreach my $i (1..$#opid_compile_patterns) {
        if ($opid_compile_patterns[$i] > 0) {
            # （オプションの指定あり（誘導オプションはnull））
            my @cpop = @{$searcher::shared_working_information{"compile_options_$i"}};
            if ((++$option_count{"$cpop[$opid_compile_patterns[$i]]"}) <  2) {
                $compile_option .= ' '. "$cpop[$opid_compile_patterns[$i]]";
            }
        }
    }
    
    my @opid_compile_options = ();
    foreach my $compile_option2 (split(/ /, $compile_option)) {
        if ((grep {$_ =~ /(^|\s)$compile_option2($|\s|\*)/} @{$searcher::shared_working_information{"set_option_$opid"}}) > 0 and
            (grep {$_ =~ /(^|\s)$compile_option2($|\s|\*)/} @opid_compile_options) == 0) {
            push (@opid_compile_options, $compile_option2);
        }
    }
    foreach my $compile_option2 (@opid_compile_options) {
        $opid_compile_option .= ' ' . $compile_option2;
    }
    #-----------------------------------------------------------------------------------------#
    # Return（展開オプション）
    return $opid_compile_option;
}
sub chk_setting_option {
###################################################################################################
#   ＜＜ 設定済オプションのチェック ＞＞                                                          #
###################################################################################################
    my ($opid, $option) = @_;
    my $chk_flg         = '';
    #-----------------------------------------------------------------------------------------#
    # 探索パターンにオプションがあるか検索
    foreach my $matrix_file (grep {${$_}[1] =~ /^=>$/} @{$searcher::shared_working_information{matrix_files}}) {
        # 起点オプション検索
        if ((grep {$option =~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]) > 0) {
            foreach my $matrix (@{$matrix_file}[2..$#{$matrix_file}]) {
                if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) > 0) {
                    if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) == ()) {
                        return 1;
                    }
                }
            }
        }
    }
    foreach my $matrix_file (grep {${$_}[1] =~ /^(&|-)$/} @{$searcher::shared_working_information{matrix_files}}) {
        #オプション検索
        if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) == ()) { next; }
        foreach my $chk_matrix (grep {${$_}[0] =~ /(^|\s)${$matrix_file}[0]($|\s)/ and ${$_}[1] eq ${$matrix_file}[1]} @{$searcher::shared_working_information{matrix_files}}) {
            $chk_flg = '';
            # 同時実行
            if (${$chk_matrix}[1] =~ /&/) {
                foreach my $matrix (@{$chk_matrix}[2..$#{$chk_matrix}]) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) == ()) { $chk_flg = 1; last; }
                }
                if ($chk_flg eq '') {
                    foreach my $check (@{$chk_matrix}[2..$#{$chk_matrix}]) {
                        if (($check !~ /(^|\s)$option($|\s)/) and ($option !~ /(^|\s)$check($|\s)/)) {
                            if ((&compare_opposite_option($check, $option)) or
                                (&compare_opposite_option($option, $check))) {
                                $chk_flg = 1;
                                last;
                            }
                        }
                    }
                    if ($chk_flg eq '') { last; }
                }
            # 等価
            } elsif (${$chk_matrix}[1] =~ /=/) {
                foreach my $matrix (@{$chk_matrix}[2..$#{$chk_matrix}]) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) == ()) { $chk_flg = ''; last; }
                    $chk_flg = 1;
                }
                if ($chk_flg eq '') { last; }
            # 排他
            } else {
                foreach my $matrix (@{$chk_matrix}[2..$#{$chk_matrix}]) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) == ()) { next; }
                    $chk_flg = 1;
                    last;
                }
            }
        }
        if ($chk_flg eq 1) {
            return 1;
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return
    return 0;
}
sub upd_setting_option {
###################################################################################################
#   ＜＜ 設定済オプション情報の更新 ＞＞                                                          #
###################################################################################################
    my ($lv, $opid, $old_option, $new_option) = @_;                                           # チェックレベル、オプションID、旧オプション、新オプション
    my @unset_options = ();                                                                   # 誘導解除オプション
    my @set_options   = ($new_option);                                                        # 追加誘導オプション
    #-----------------------------------------------------------------------------------------#
    if ($old_option ne '') {
        push (@unset_options, $old_option);
    } else {
        foreach my $setting_option (@{$searcher::shared_working_information{"set_option_$opid"}}) {
            if ($new_option ne '' and $setting_option ne '' and
               (&compare_opposite_option($setting_option, $new_option) or
                &compare_opposite_option($new_option, $setting_option))) {
                push (@unset_options, $setting_option);
            }
        }
    }
    # 追加誘導オプションをチェック
    foreach my $set_option (@set_options) {
        foreach my $matrix_file (grep {${$_}[1] =~ /[\+]/} @{$searcher::shared_working_information{matrix_files}}) {
            if ((ref (${$matrix_file}[0]) eq 'ARRAY')){
                my $flg_add = 1;
                foreach my $matrix (@{${$matrix_file}[0]}) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) == 0) {
                         $flg_add = 0;
                         last;
                    }
                }
                if ($flg_add == 1) {
                    foreach my $chk_option (@{$matrix_file}[2..$#{$matrix_file}]) {
                        if ((grep {$_ =~ /(^|\s)$chk_option($|\s)/} @set_options) == 0) {
                            push (@set_options, $chk_option);
                        }
                    }
                }
            } else {
                if ("$set_option" eq "${$matrix_file}[0]") {
                    foreach my $chk_option (@{$matrix_file}[2..$#{$matrix_file}]) {
                        if ((grep {$_ =~ /(^|\s)$chk_option($|\s)/} @set_options) == 0) {
                            push (@set_options, $chk_option);
                        }
                    }
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
        foreach my $setting_option (@{$searcher::shared_working_information{"set_option_$opid"}}) {
            if ($set_option ne '' and $setting_option ne '' and
               (&compare_opposite_option("$setting_option", "$set_option") or
                &compare_opposite_option("$set_option", "$setting_option"))) {
                if ($setting_option ne '') {
                    push (@unset_options, $setting_option);
                }
            }
        }
    }
    foreach my $matrix_file (grep {${$_}[1] eq ''} @{$searcher::shared_working_information{matrix_files}}) {
        if ((grep {$new_option =~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]) > 0) {
            my @upper_options = (grep {$new_option !~ /(^|\s)$_($|\s)/} @{$matrix_file}[2..$#{$matrix_file}]);
            foreach my $upper_option (@upper_options) {
                if ((grep {$_ =~ /(^|\s)$upper_option($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) > 0) {
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
        foreach my $matrix_file (grep {${$_}[1] =~ /[\+]/} @{$searcher::shared_working_information{matrix_files}}) {
            if ((ref (${$matrix_file}[0]) eq 'ARRAY')){
                foreach my $matrix (@{${$matrix_file}[0]}) {
                    if ((grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$searcher::shared_working_information{"set_option_$opid"}}) == 0) {
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
                    if (${$searcher::shared_working_information{"compile_options_$check_lv"}}[$searcher::shared_working_information{"compile_patterns_$check_lv"}] =~ /(^|\s)$matrix($|\s)/) {
                        next loop3;
                    }
                    loop5:
                    foreach my $setting_option (@{$searcher::shared_working_information{"set_option_$opid"}}) {
                        if ((grep {$setting_option =~ /(^|\s)$_($|\s)/} @unset_options) > 0) { next; }
                        foreach my $matrix_file2 (grep {$setting_option =~ /(^|\s)${$_}[0]($|\s)/ and ${$_}[1] =~ /[\+]/} @{$searcher::shared_working_information{matrix_files}}) {
                            if ((grep {$matrix =~ /(^|\s)$_($|\s)/} @{$matrix_file2}[2..$#{$matrix_file2}]) > 0) {
                                next loop3;
                            }
                        }
                        loop6:
                        foreach my $matrix_file2 (grep {(ref (${$_}[0]) eq 'ARRAY') and ${$_}[1] =~ /[\+]/} @{$searcher::shared_working_information{matrix_files}}) {
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
    if ($old_option eq '' or
       (grep {$_ =~ /^$old_option$/} @{$searcher::shared_working_information{"set_option_$opid"}}) == 0) {
        # （存在しない）
        push (@{$searcher::shared_working_information{"set_option_$opid"}}, "$new_option");
    } else {
        # （存在する）
        @{$searcher::shared_working_information{"set_option_$opid"}} = map {$_ =~ s/^$old_option$/$new_option/; $_;} @{$searcher::shared_working_information{"set_option_$opid"}};
    }
    
    # 設定済オプション情報を更新
    my @deleted_options = ();
    foreach my $setting_option (@{$searcher::shared_working_information{"set_option_$opid"}}) {
        if ((grep {$_ =~ /^$setting_option$/} @unset_options) == 0) {
            push (@deleted_options, "$setting_option");
        }
    }
    @{$searcher::shared_working_information{"set_option_$opid"}} = @deleted_options;
    foreach my $set_option (@set_options) {
        if ((grep {$_ =~ /^$set_option$/} @deleted_options) == 0) {
            push (@{$searcher::shared_working_information{"set_option_$opid"}}, "$set_option");
        }
    }
}
sub optimization_compile_option {
###################################################################################################
#   ＜＜ 誘導オプションチェック ＞＞                                                              #
###################################################################################################
    my $parent_opids = shift;
    my $search_level = shift;
    #-----------------------------------------------------------------------------------------#
    # レベル内のオプションIDをサマリ
    my %count = ();
    @{$searcher::shared_working_information{"search_level_jobs_$search_level"}} = grep {$_ ne ''}      @{$searcher::shared_working_information{"search_level_jobs_$search_level"}};
    @{$searcher::shared_working_information{"search_level_jobs_$search_level"}} = grep {!$count{$_}++} @{$searcher::shared_working_information{"search_level_jobs_$search_level"}};
    
    # 誘導処理によって同一となってしまう指定を削除
    my @check_opid = ();
    foreach my $key (keys %{$searcher::shared_working_information{stop_levels}}) {
        if (exists $searcher::shared_working_information{"search_level_jobs_$key"}) {
            foreach my $opid (@{$searcher::shared_working_information{"search_level_jobs_$key"}}) {
                push (@check_opid, $opid);
            }
        }
    }
    push (@check_opid, @{$searcher::shared_working_information{"search_level_jobs_$search_level"}});
    %count = ();
    my @sorted_check_opid  = sort {$a <=> $b} grep {!$count{$_}++} @check_opid;
    my @search_level_jobs = sort grep {$_ =~ /search_level_jobs_/} keys %searcher::shared_working_information;
    for (my $i1 = $#sorted_check_opid; $i1 > 1; $i1--) {
        if (!exists $searcher::shared_working_information{"compile_patterns_$sorted_check_opid[$i1]"}) { next; }
        foreach my $i2 (0..($i1 - 1)) {
            if (!exists $searcher::shared_working_information{"compile_patterns_$sorted_check_opid[$i2]"}) { next; }
            my $synonym_flg = 0;
            foreach my $i (1..$#{$searcher::shared_working_information{"set_option_$sorted_check_opid[$i1]"}} ) {
                if ((grep {$_ =~ /(^|\s)${$searcher::shared_working_information{"set_option_$sorted_check_opid[$i1]"}}[$i]($|\s)/} @{$searcher::shared_working_information{"set_option_$sorted_check_opid[$i2]"}}) == 0) {
                    $synonym_flg = 1;
                    last;
                }
            }
            if ($synonym_flg == 0) {
                if (${$parent_opids}{$sorted_check_opid[$i1]} < ${$parent_opids}{$sorted_check_opid[$i2]}) { next; }
                # 比較対象を親に変更
                &upd_search_level_jobs($#{$searcher::shared_working_information{"compile_patterns_$sorted_check_opid[$i1]"}}, $sorted_check_opid[$i1], $parent_opids);
                # 変更したパターンを削除
                delete $searcher::shared_working_information{"compile_patterns_$sorted_check_opid[$i1]"};
                my @new_search_level_jobs = ();
                foreach my $i (0..$#{$searcher::shared_working_information{"search_level_jobs_$search_level"}}) {
                    if ($sorted_check_opid[$i1] ne ${$searcher::shared_working_information{"search_level_jobs_$search_level"}}[$i]) {
                        push (@new_search_level_jobs, ${$searcher::shared_working_information{"search_level_jobs_$search_level"}}[$i]);
                    }
                }
                @{$searcher::shared_working_information{"search_level_jobs_$search_level"}} = @new_search_level_jobs;
                last;
            }
        }
    }
}
sub upd_search_level_jobs {
###################################################################################################
#   ＜＜ 比較対象を親に変更 ＞＞                                                                  #
###################################################################################################
    my ($lv, $opid, $parent_opids) = @_;                                                      # レベル、オプションID、親オプションID情報
    my $parent_opid = ${$parent_opids}{$opid};                                                # 親オプションID
    #-----------------------------------------------------------------------------------------#
    # オプションIDのindexを取得
    my $change = &get_search_level_jobs_index($lv, $opid);
    
    #レベル別実行ジョブに親オプションIDが登録されていない場合親の親を辿る
    for (my $parent_lv = $lv-1; $parent_lv > 0; $parent_lv--) {
        if (grep {${$searcher::shared_working_information{"search_level_jobs_$parent_lv"}}[$_] == $parent_opid} 0..$#{$searcher::shared_working_information{"search_level_jobs_$parent_lv"}}) {
            ${$searcher::shared_working_information{"search_level_jobs_$lv"}}[$change] = $parent_opid;
            last;
        }
        $parent_opid = ${$parent_opids}{$parent_opid};
    }
}
sub get_search_level_jobs_index {
###################################################################################################
#   ＜＜ オプションIDのindexを取得 ＞＞                                                           #
###################################################################################################
    my ($lb, $opid) = @_;                                                                     # レベル、オプションID
    #-----------------------------------------------------------------------------------------#
    foreach my $i (0..$#{$searcher::shared_working_information{"search_level_jobs_$lb"}}) {
        # レベル内にオプションIDがあるかチェック
        if ($opid eq ${$searcher::shared_working_information{"search_level_jobs_$lb"}}[$i]) { return $i; }
    }
    return -1;
}
sub finally {
###################################################################################################
    my $self = shift;
    my $id   = $self->{id};
    my $cnt  = 1;
    if ($searcher::shared_working_information{measurement_cnt} > 1) {
        $self->{id} =~ /(.+)_([\d]+)$/;
        $id  = $1;
        $cnt = $2;
    }
    #-----------------------------------------------------------------------------------------#
    foreach my $key (@{$searcher::shared_working_information{option_arg_key}}) {
        my @link_key = grep {$_ =~ /^link_RANGE/ and $searcher::shared_working_information{$_} eq "$key"} keys %searcher::shared_working_information;
        if ($#link_key >= 0) {
            $link_key[0] =~ /link_RANGE([\d]+)$/;
            ${$searcher::shared_working_information{result_jobseq}}{$id} = ${${$self}{VALUE}}[$1];
        }
    }
    if (!exists ${$searcher::shared_working_information{result}}{$id}) { %{${$searcher::shared_working_information{result}}{$id}} = (); }
    ${${$searcher::shared_working_information{result}}{$id}}{$cnt} = eval('&'.$searcher::base_package.'::get_evaluation_value($self, \%$searcher::shared_working_information);');

}
sub get_evaluation_value {
###################################################################################################
#   ＜＜ 評価データの取得 ＞＞                                                                    #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 評価データ(timeコマンド結果など)を取得し、返却する                                    #
#   引数 ： $_[0] ＝ $self                                                                        #
#        ： $_[1] ＝ %shared_working_information                                                  #
#   返却 ： $evaluation_value                                                                     #
###################################################################################################
    my $self                       = shift;
    my %shared_working_information = %{shift(@_)};
    my $evaluation_value           = '';
    #-----------------------------------------------------------------------------------------#
    # Open
    my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};
    my $wkdir_str = File::Spec->catfile($self->{env}->{wd}, $self->{workdir});
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
    my $evaluation_data_file =  File::Spec->catfile( $wkdir_str, $self->{id} . '.evaluation' );
    if (!-e "$evaluation_data_file") { return (); }
    open (EVALUATION_DATA, "< $evaluation_data_file") or warn "Cannot open  $evaluation_data_file";
    # 実行時間取得
    my $tim = 0;
    my $cnt = 0;
    my @line_datas = <EVALUATION_DATA>;
    foreach my $line_data (@line_datas) {
        if ($line_data =~ /^Command terminated by signal 9/) { return ''; }
        #「9.99user 9.99system ･･･」から実行時間(user＋system)を取得
        if ($line_data =~ /^([0-9\.]+)(user|u)\s+([0-9\.]+)(system|s)\s/) {
            if ($shared_working_information{comparison_target} == 1) { $3 = 0; }
            if ($shared_working_information{comparison_target} == 2) { $1 = 0; }
            $cnt++;
            $evaluation_value = ($1 + $3);
        } elsif ($line_data =~ /^user\s+([0-9\.]+)/) {
            if ($shared_working_information{comparison_target} == 2) { $1 = 0; }
            $tim = $1;
        } elsif ($line_data =~ /^sys\s+([0-9\.]+)/) {
            if ($shared_working_information{comparison_target} == 1) { $1 = 0; }
            $tim += $1;
            $cnt++;
            $evaluation_value = $tim;
            $tim = 0;
        }
    }
    # Close
    close (EVALUATION_DATA);
    #-----------------------------------------------------------------------------------------#
    # Return
    return $evaluation_value;
}
sub evaluation {
###################################################################################################
#   ＜＜ 結果評価 ＞＞                                                                            #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 評価データを評価・判定し、次回の探索範囲を探索用テンプレートへ設定                    #
#   引数 ： $_[0] ＝ %template                                                                    #
#        ： $_[1] ＝ %working_information                                                         #
#        ： $_[2] ＝ %shared_working_information                                                  #
#   返却 ： $working_information [ , %working_information [ , %working_information [ , ･･･ ] ] ]  #
###################################################################################################
    my %template                   = %{shift(@_)};
    my %working_information        = %{shift(@_)};
    my %shared_working_information = %{shift(@_)};
    #-----------------------------------------------------------------------------------------#
    # Get Result_Data
    my %result_data = ();
    foreach my $key (@{$shared_working_information{"search_level_$working_information{search_level}"}}) {
        my $cnt  = 1;
        if ($shared_working_information{measurement_cnt} > 1) {
            $key =~ /(.+)_([\d]+)$/;
            $key = $1;
            $cnt = $2;
        }
        if (exists $result_data{$key}) { next; }
        if (${$shared_working_information{result}}{$key} == ()) { next; }
        $result_data{$key} = ${$shared_working_information{result}}{$key};
    }
    # Sort Judgment_Data
    my %judgment_data       = &get_judgment_data($shared_working_information{extraction_data}, \%result_data);
    my @sorted_judgment_key = ();
    if ($working_information{measurement_order} eq 'asc') {
        @sorted_judgment_key = sort {$judgment_data{$a} <=> $judgment_data{$b}} grep {$judgment_data{$_} != 0} keys %judgment_data;
    } else {
        @sorted_judgment_key = sort {$judgment_data{$b} <=> $judgment_data{$a}} grep {$judgment_data{$_} != 0} keys %judgment_data;
    }
    
    # 探索終了判定
    my $parallel_name = '';
    if (${$searcher::shared_working_information{"compile_options_$working_information{search_level}"}}[0] =~ /(parallel[\d]+_)/) {
        # 並列
        $parallel_name = $1;
        while (${$searcher::shared_working_information{"compile_options_$working_information{start_level}"}}[0] =~ /$parallel_name/) {
           ($working_information{start_level}, $working_information{search_level}) = &next_search_level($working_information{search_level});
        }
    } else {
       ($working_information{start_level}, $working_information{search_level}) = &next_search_level($working_information{search_level});
    }
    if ($shared_working_information{compile_options_max} < $working_information{search_level}) { return (); }
    my @next_pattern_jobs                          = ();
    my %temp_next_compile_patterns                 = %{$working_information{next_compile_patterns}};
    %{$working_information{next_compile_patterns}} = ();
    # 探索結果評価
    my $value = '';
    my $cnt   = 0;
    for (my $x = 0; $x <= $#sorted_judgment_key and $cnt < $working_information{extraction_cond}; $x++) {
        my $judgment_value = $judgment_data{$sorted_judgment_key[$x]};
        if ($value ne $judgment_value) {
            $value = $judgment_value;
            $cnt++;
        }
        my $id = ${$shared_working_information{result_jobseq}}{$sorted_judgment_key[$x]};
        my $opid = $shared_working_information{"jobseq_$id"};
        ${$working_information{next_compile_patterns}}{$opid} = $shared_working_information{"compile_patterns_$opid"};
    }
    #-----------------------------------------------------------------------------------------#
    # Return
    return \%working_information;
}
sub get_judgment_data {
###################################################################################################
#   ＜＜ 判定対象データの取得 ＞＞                                                                #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 評価データから判定対象データを取得                                                    #
#   引数 ： $_[1] ＝ 評価対象（max＝最大、min＝最小、med＝中間、avg＝平均、sum=合計）             #
#        ： $_[2] ＝ 評価データ                                                                   #
#   返却 ： 判定対象データ                                                                        #
###################################################################################################
    my $extraction_data = shift;
    my %result           = %{shift(@_)};
    my %judgment_data    = ();
    #-----------------------------------------------------------------------------------------#
    foreach my $k (keys %result) {
        my @sorted_result = sort {$a <=> $b} values %{$result{$k}};
        # 計測条件に従い結果算出
        if ($extraction_data eq 'max') {
            # （最大）
            $judgment_data{$k} = "$sorted_result[$#sorted_result]";
        } elsif ($extraction_data eq 'min') {
            # （最小）
            $judgment_data{$k} = "$sorted_result[0]";
        } elsif ($extraction_data eq 'med') {
            # （中間）
            $judgment_data{$k} = "$sorted_result[int(($#sorted_result / 2) + 0.5)]";
        } elsif ($extraction_data eq 'avg') {
            # （平均）
            my $total_time = 0;
            foreach my $d (@sorted_result) {$total_time += $d}
            $judgment_data{$k} = sprintf("%.5f", ($total_time / ($#sorted_result + 1)));
        } elsif ($extraction_data eq 'sum') {
            # （合計）
            $judgment_data{$k} = 0;
            foreach my $value (@sorted_result) { $judgment_data{$k} += $value; }
        } else {
            # （指定回）
            $judgment_data{$k} = ${$result{$k}}{$extraction_data};
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（判定対象データ）
    return %judgment_data;
}
sub output_result {
###################################################################################################
#   ＜＜ 探索結果出力 ＞＞                                                                        #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 評価データから探索結果を作成し、指定ファイルへ出力                                    #
#   引数 ： $_[0] ＝ %shared_working_information                                                  #
###################################################################################################
    my %shared_working_information = @_;
    my %judgment_data = &get_judgment_data($shared_working_information{extraction_data}, \%{$shared_working_information{result}});
    #-----------------------------------------------------------------------------------------#
    # Sort(Ascending or Descending)
    my $cnt = 0;
    my $out = 0;
    my $tim = '';
    my @sorted_judgment_key = ();
    if ($shared_working_information{measurement_order} eq 'asc') {
        @sorted_judgment_key = sort {$judgment_data{$a} <=> $judgment_data{$b}} grep {$judgment_data{$_} != 0} keys %judgment_data;
    } else {
        @sorted_judgment_key = sort {$judgment_data{$b} <=> $judgment_data{$a}} grep {$judgment_data{$_} != 0} keys %judgment_data;
    }
    foreach my $i (0..$#sorted_judgment_key) {
        my $judgment_value = $judgment_data{$sorted_judgment_key[$i]};
        if ($tim ne $judgment_value) {
            $tim = $judgment_value;
            $cnt++;
        }
        if ($cnt >= $shared_working_information{measurement_list} or $cnt == $#sorted_judgment_key) {
            $out = $i;
            last;
        }
    }
    my ($scale_unit, $scale_max, $scale_min) = &get_scale_unit($judgment_data{$sorted_judgment_key[$out]}, $judgment_data{$sorted_judgment_key[0]});
    # Edit Result Data
    if ($shared_working_information{measurement_list} > $#sorted_judgment_key) { $shared_working_information{measurement_list} = $#sorted_judgment_key; }
    my $max_opid_digit = 3;
    my @splited_times = ();
    my $max_time_digit = 0;
    my $max_time_digit_float = 0;
    foreach my $k (@sorted_judgment_key) {
        if ($max_opid_digit < length($k)) { $max_opid_digit = length($k); }
        @splited_times = split(/\./, $judgment_data{$k});
        if ($max_time_digit < length($splited_times[0])) { $max_time_digit = length($splited_times[0]); }
        if ($max_time_digit_float < length($splited_times[1])) { $max_time_digit_float = length($splited_times[1]); }
    }
    # Output
    my @output_time_datas = ();
    my @output_option_datas = ();
    foreach my $i (0..$out) {
        # Scale Calculation
        my $scale_mark = '*';
        my $scale = $scale_mark;
        foreach my $j (1..int(($judgment_data{$sorted_judgment_key[$i]} - $scale_min)/$scale_unit)) { $scale .= $scale_mark; }
        # Save Result
        @splited_times = split(/\./, $judgment_data{$sorted_judgment_key[$i]});
        if ($splited_times[1] eq '') { $splited_times[1] = '0'; }
        push (@output_time_datas, sprintf("%-${max_opid_digit}s %${max_time_digit}s.%-${max_time_digit_float}s %s", $sorted_judgment_key[$i], $splited_times[0], $splited_times[1], $scale));
        my $option = &get_compile_option($shared_working_information{"jobseq_${$shared_working_information{result_jobseq}}{$sorted_judgment_key[$i]}"});
        push (@output_option_datas, sprintf("%-${max_opid_digit}s%s", $sorted_judgment_key[$i], "$option"));
    }
    # Open
    #open (RESULT, "> $shared_working_information{search_result}") or die "Cannot open $shared_working_information{search_result}";
    open (RESULT, "> $shared_working_information{search_result}") or print "Cannot open $shared_working_information{search_result}\n";
    # Output Result
    print RESULT "[探索結果]\n";
    print RESULT "----------------------------------------------------------------------------------------------------\n";
    foreach my $output_time_data   (@output_time_datas)   { print RESULT "$output_time_data\n"; }
    print RESULT "\n";
    print RESULT "[Option]\n";
    print RESULT "----------------------------------------------------------------------------------------------------\n";
    foreach my $output_option_data (@output_option_datas) { print RESULT "$output_option_data\n"; }
    # Close
    close(RESULT);
}
sub get_scale_unit {
###################################################################################################
#   ＜＜ スケール単位を算出 ＞＞                                                                  #
#-------------------------------------------------------------------------------------------------#
#   引数 ： $_[0] ＝ 最大値                                                                       #
#        ： $_[1] ＝ 最小値                                                                       #
#   返却 ： スケール単位、最大値、最小値                                                          #
###################################################################################################
    my ($max, $min) = @_;
    my $scale_unit  = 0;
    #-----------------------------------------------------------------------------------------#
    my $gap = ($max - $min) / 2;
    if      ($gap <= 0.10)    { $scale_unit = 0.01;
    } elsif ($gap <= 0.50)    { $scale_unit = 0.05;
    } elsif ($gap <= 1)       { $scale_unit = 0.1;
    } elsif ($gap <= 5)       { $scale_unit = 0.5;
    } elsif ($gap <= 10)      { $scale_unit = 1;
    } elsif ($gap <= 50)      { $scale_unit = 5;
    } elsif ($gap <= 100)     { $scale_unit = 10;
    } elsif ($gap <= 500)     { $scale_unit = 50;
    } elsif ($gap <= 1000)    { $scale_unit = 100;
    } elsif ($gap <= 5000)    { $scale_unit = 500;
    } elsif ($gap <= 10000)   { $scale_unit = 1000;
    } elsif ($gap <= 50000)   { $scale_unit = 5000;
    } elsif ($gap <= 100000)  { $scale_unit = 10000;
    } elsif ($gap <= 500000)  { $scale_unit = 50000;
    } elsif ($gap <= 1000000) { $scale_unit = 100000;
    } elsif ($gap <= 5000000) { $scale_unit = 500000;
    } else                    { $scale_unit = 1000000;
    }
    #-----------------------------------------------------------------------------------------#
    # Return
    if ($min < $max) { return $scale_unit, $max, $min;
    } else           { return $scale_unit, $min, $max;
    }
}
1;
