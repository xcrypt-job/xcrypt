package searcher;

use strict;
use builtin;
use File::Spec;
use Time::HiRes;
use NEXT;
use Coro;
use Coro::Channel;
use Coro::Signal;
use Coro::AnyEvent;
use Cwd;
use common;
use Data::Dumper;
$Data::Dumper::Deparse  = 1;
$Data::Dumper::Deepcopy = 1;
$Data::Dumper::Maxdepth = 5;
use base qw(Exporter);
our @EXPORT = qw(initialize searcher set_initial_searcher get_search_information get_evaluation_value initialize2
                 entry_search_pattern initially finally evaluation output_result);

our %shared_working_information : shared = ();                                                    # 探索定義情報
our $bulk_cnt                   = 0;                                                              # bulk時用のbulkジョブ名連番
my  %template                   = ();                                                             # テンプレート
my  $search_information_file    = '';                                                             # 探索情報ファイル名
my  $extraction_data            = 'med';                                                          # 評価対象（max＝最大、min＝最小、med＝中間、avg＝平均、sum=合計）
my  $extraction_cond            = 2;                                                              # 評価条件（1＝最上位、2＝上位２、3＝上位３）
my  $measurement_order          = 'asc';                                                          # 整列順序（asc＝昇順、dec＝降順）
my  $measurement_cnt            = 1;                                                              # 計測回数
my  $measurement_list           = 10;                                                             # 出力件数
my  $search_result              = 'seacher_result';                                               # 結果出力ファイル名

# ベースライブラリ名を取得
our $base_package               = '';                                                             # ベースライブラリ名
my  $cnt                        = 0;
while ($base_package eq '') {
    $cnt++;
    my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller($cnt);
    if ($package eq 'base') {
        $evaltext =~ s/\.pm//;
        $evaltext =~ s/require //;
        $evaltext =~ s/\n;//;
        $base_package = $evaltext;
    }
}
if ($base_package eq 'searcher') {
    die "error : The individual function library is not specified.\n";
}
sub initialize {
###################################################################################################
#   ＜＜ 初期設定 ＞＞                                                                            #
#-------------------------------------------------------------------------------------------------#
#   処理 ： ユーザーが定義した探索定義情報を探索用テンプレートへ設定                              #
#   引数 ： $_[0] ＝ ユーザースクリプトinitialize定義情報                                         #
###################################################################################################
    my (%script_appointments)   = @_;
    %shared_working_information = ();
    $bulk_cnt                   = 0;
    #-----------------------------------------------------------------------------------------#
    # defalut
    $shared_working_information{search_information_file} = $search_information_file;
    $shared_working_information{extraction_data}         = $extraction_data;
    $shared_working_information{extraction_cond}         = $extraction_cond;
    $shared_working_information{measurement_order}       = $measurement_order;
    $shared_working_information{measurement_cnt}         = $measurement_cnt;
    $shared_working_information{measurement_list}        = $measurement_list;
    $shared_working_information{search_result}           = $search_result;
    %shared_working_information                          = (%shared_working_information, %script_appointments);
    %{$shared_working_information{result}}               = ();
    # 抽出条件/計測回数/出力件数
    if ($shared_working_information{extraction_cond}   =~ /\D+/) { die "syntax error : extraction_cond\n"; }
    if ($shared_working_information{measurement_cnt}   =~ /\D+/) { die "syntax error : measurement_cnt\n"; }
    if ($shared_working_information{measurement_list}  =~ /\D+/) { die "syntax error : measurement_list\n"; }
    # 評価対象
    if ($shared_working_information{extraction_data} ne "max" and
        $shared_working_information{extraction_data} ne "min" and
        $shared_working_information{extraction_data} ne "med" and
        $shared_working_information{extraction_data} ne "avg" and
        $shared_working_information{extraction_data} ne "sum" and
        $shared_working_information{extraction_data} !~ /^[\d]+$/ ) {
        die "error ". $shared_working_information{extraction_data}. ": not exists in extraction_data\n";
    }
    if ($shared_working_information{extraction_data} =~ /^[\d]+$/ and
        $shared_working_information{extraction_data} > $shared_working_information{measurement_cnt}) {
        die "error ". $shared_working_information{extraction_data}. ": designation is too big\n";
    }
    # 整列順序
    if ($shared_working_information{measurement_order} ne "asc" and
        $shared_working_information{measurement_order} ne "dec" ) {
        die "error ". $shared_working_information{measurement_order}. ": not exists in measurement_order\n";
    }
    # 探索情報ファイル名/出力ファイル名
    if ($shared_working_information{search_result} eq "")      { die "error : search_result is null\n"; }
    if ($shared_working_information{search_result} =~ /^\s+$/) { die "error : search_result is only blank\n"; }
}
sub searcher {
###################################################################################################
#   ＜＜ 探索処理 ＞＞                                                                            #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 探索を実行                                                                            #
#   引数 ： $_[0] ＝ %template                                                                    #
###################################################################################################
    my %template = @_;
    #-----------------------------------------------------------------------------------------#
    # 探索情報をtemplateへ反映
    if ($shared_working_information{search_information_file} ne '') {
        my %search_information = eval('&'.$base_package.'::get_search_information($shared_working_information{search_information_file});');
        %template = (%template, %search_information);
    }
    # initial_setting
    my @working_informations = eval('&'.$base_package.'::set_initial_searcher(\%template, \%shared_working_information);');
    # search
    &async_searcher(\%template, \@working_informations);
    # output_result
    eval ('&'.$base_package.'::output_result(%shared_working_information);');
}
sub get_search_information {
###################################################################################################
#   ＜＜ 探索情報取得 ＞＞                                                                        #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 指示されたファイルから探索空間情報を取得し、返却する                                  #
#   引数 ： $_[0] ＝ $search_information_file                                                     #
#   返却 ： %search_information                                                                   #
###################################################################################################
    my $search_information_file = shift;
    my %search_information      = ();
    #-----------------------------------------------------------------------------------------#
    # ユーザ処理
    #-----------------------------------------------------------------------------------------#
    # Return
    return %search_information;
}
sub set_initial_searcher {
###################################################################################################
#   ＜＜ 探索初期設定 ＞＞                                                                        #
#-------------------------------------------------------------------------------------------------#
#   処理 ： テンプレートから探索用テンプレートを初期設定する                                      #
#   引数 ： $_[0] ＝ %template                                                                    #
#        ： $_[1] ＝ 探索用テンプレート                                                           #
#   返却 ： 探索作業用情報１ [,探索作業用情報２ [,探索作業用情報３[,･･･]]                         #
###################################################################################################
    my %template             = %{shift(@_)};
    my %working_information  = %{shift(@_)};
    my @working_informations = ();
    #-----------------------------------------------------------------------------------------#
    # ユーザ処理
    push (@working_informations, \%working_information);
    #-----------------------------------------------------------------------------------------#
    # Return（探索作業用情報）
    return @working_informations;
}
sub async_searcher {
###################################################################################################
#   ＜＜ 探索作業用情報毎の回帰的非同期探索 ＞＞                                                  #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 探索作業用情報毎にスレッドを立ち上げて探索を実施する                                  #
#   引数 ： $_[0] ＝ テンプレート                                                                 #
#        ： $_[1] ＝ 探索作業用情報１ [,探索作業用情報２ [,探索作業用情報３[,･･･]]                #
###################################################################################################
    my $template             = shift;
    my $working_informations = shift;
    my $slp                  = 0;
    #-----------------------------------------------------------------------------------------#
    foreach my $working_information (@{$working_informations}) {
        if ($#{$working_informations} > 0) {
            my $job_coro = Coro::async {
                my $working_information = shift;
                # 探索
                &async_searcher($template, &main_searcher($template, $working_information));
            } $working_information;
            # thread
            $working_information->{thread} = $job_coro;
            Coro::AnyEvent::sleep $slp;
        } else {
            &async_searcher($template, &main_searcher($template, $working_information));
        }
    }
    # join
    if ($#{$working_informations} > 0) { 
        foreach (@{$working_informations}) { ${$_}{thread}->join; }
    }
}
sub main_searcher {
###################################################################################################
#   ＜＜ 探索 ＞＞                                                                                #
#-------------------------------------------------------------------------------------------------#
#   処理 ： テンプレートの指示に従い探索する                                                      #
#   引数 ： $_[0] ＝ テンプレート                                                                 #
#        ： $_[1] ＝ 探索作業用情報                                                               #
#   返却 ： 探索作業用情報１ [,探索作業用情報２ [,探索作業用情報３[,･･･]]                         #
###################################################################################################
    my %template            = %{shift(@_)};
    my %working_information = %{shift(@_)};
    #-----------------------------------------------------------------------------------------#
    # entry
    %template = eval('&'.$base_package.'::entry_search_pattern(\%template, \%working_information);');
    # check the search right or wrong
    my @key = sort grep {$_ =~ /^RANGE[\d]+$/} keys %template;
    if ($#key > -1) {
        $key[$#key] =~ /^RANGE([\d]+)$/;
        $working_information{idx_max_search} = $1;
    } else {
        $working_information{idx_max_search} = -1;
    }
    # 計測回数をRANGEへ反映
    if ($working_information{measurement_cnt} > 1) {
        my $cnt = ($working_information{idx_max_search} + 1);
        $template{"RANGE$cnt"} = [1..$working_information{measurement_cnt}];
    }
    # prepare
    my @jobs = &searcher_prepare(%template);
    foreach my $self (@jobs) {
        # VALUEからargを設定
        for (my $cnt = 0; $cnt <= $#{${$self}{VALUE}}; $cnt++) {
            if (exists $working_information{"link_RANGE$cnt"}) {
                my $arg = $working_information{"link_RANGE$cnt"};
                if ($arg =~ /^(arg.+)\@$/) {
                    ${$self}{$1}   = ${${$self}{$arg}}[${${$self}{VALUE}}[$cnt]];
                }
            }
        }
        # finishedになっているジョブの評価データを取得
        if (jobsched::job_proceeded_last_time ($self, 'finished')) { eval('&'.$base_package.'::finally($self);'); }
        if (!exists $shared_working_information{"search_level_$working_information{search_level}"}) { @{$shared_working_information{"search_level_$working_information{search_level}"}} = (); }
        push (@{$shared_working_information{"search_level_$working_information{search_level}"}}, ${$self}{id});
    }
    # bulk
    @jobs  = &set_bulk_job(@jobs);
    # submit
    &builtin::submit(@jobs);
    # sync
    &builtin::sync(@jobs);
    # un_bulk
    @jobs  = &unset_bulk_job(@jobs);
    # evaluation
    my @working_informations = eval('&'.$base_package.'::evaluation(\%template, \%working_information, \%shared_working_information);');
    #-----------------------------------------------------------------------------------------#
    # Return（探索作業用情報１ [,探索作業用情報２ [,探索作業用情報３[,･･･]]）
    return \@working_informations;
}
###################################################################################################
#   ＜＜ prepare ＞＞                                                                             #
###################################################################################################
sub searcher_prepare{
    $builtin::count = 0;
    my %template = &builtin::unalias(@_);
    %template = &builtin::add_exes_args_colon(%template); # for compatibility
    %template = &builtin::disble_keys_without_by_add_key(%template);
    my @value = &builtin::expand(%template);
    my @jobs;
    foreach my $v (@value) {
        my $job_id = join(&builtin::get_separator(), ($template{id}, @{$v}));
        if ((grep {$_ =~ /^$job_id$/} keys %shared_working_information) == ()) {
            %{$shared_working_information{$job_id}} = ();
            my $self = &builtin::do_initialized(\%template, @{$v});
            $builtin::count++;
            push(@jobs, $self);
        }
    }
    # job_info()
    if ($xcropt::options{jobinfo}) {
        foreach my $self (@jobs) { &builtin::job_info($self); }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（ジョブ定義体情報）
    return @jobs;
}
sub entry_search_pattern {
###################################################################################################
#   ＜＜ 探索パターン設定 ＞＞                                                                    #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 探索(prepare)するパターンを設定する                                                   #
#   引数 ： $_[0] ＝ テンプレート                                                                 #
#        ： $_[1] ＝ 探索作業用情報                                                               #
#   返却 ： テンプレート                                                                          #
###################################################################################################
    my %template            = %{shift(@_)};
    my %working_information = %{shift(@_)};
    #-----------------------------------------------------------------------------------------#
    # ユーザ処理
    #-----------------------------------------------------------------------------------------#
    # Return（テンプレート）
    return %template;
}
sub initially {
###################################################################################################
#   ＜＜ prepare後のarg補正 ＞＞                                                                  #
#-------------------------------------------------------------------------------------------------#
#   処理 ： prepare後にジョブオブジェクト内のargを補正して返却する                                #
#   引数 ： $_[0] ＝ ジョブオブジェクト                                                           #
#   返却 ： $self                                                                                 #
###################################################################################################
    my $self = shift;
    #-----------------------------------------------------------------------------------------#
    if (!exists $shared_working_information{bulk_id}) {
        &shared_initially($self);
    } else {
        foreach my $sub_self (@{${$self}{bulk_jobs}}) {
            &shared_initially($sub_self);
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return（ジョブオブジェクト）
    return $self;
}
###################################################################################################
sub shared_initially {
    my $self = shift;
    #-----------------------------------------------------------------------------------------#
    # argがCODEの場合は評価して再設定
    foreach my $key (sort grep {$_ =~ /^arg[\d]+_[\d]+$/} keys %{$self}) {
        if (!exists ${$self}{"${key}\@"} and ref(${$self}{$key}) eq 'CODE') {
            ${$self}{$key} = &{${$self}{$key}}($self);
        }
    }
    $self = eval('&'.$base_package.'::search_initially($self);');
    #-----------------------------------------------------------------------------------------#
    # Return（ジョブオブジェクト）
    return $self;
}
sub set_bulk_job {
###################################################################################################
#   ＜＜ バルク設定 ＞＞                                                                          #
#-------------------------------------------------------------------------------------------------#
#   処理 ： バルク指定がある場合はバルク化する                                                    #
#   引数 ： $_[0] ＝ 実行レベルジョブオブジェクト                                                 #
#   返却 ： バルク化した実行レベルジョブオブジェクト                                              #
###################################################################################################
    my @array = @_;
    #-----------------------------------------------------------------------------------------#
    if ($shared_working_information{bulk_id} ne '') {
        $bulk_cnt++;
        @array = &bulk::bulk("$shared_working_information{bulk_id}_${bulk_cnt}", @array);
    }
    #-----------------------------------------------------------------------------------------#
    # Return（バルク化した実行レベルジョブオブジェクト）
    return @array;
}
sub unset_bulk_job {
###################################################################################################
#   ＜＜ バルク解除 ＞＞                                                                          #
#-------------------------------------------------------------------------------------------------#
#   処理 ： バルクジョブの場合はバルクを解除する                                                  #
#   引数 ： $_[0] ＝ 実行レベルジョブオブジェクト                                                 #
#   返却 ： 実行レベルジョブオブジェクト                                                          #
###################################################################################################
    my @array = @_;
    #-----------------------------------------------------------------------------------------#
    if ($shared_working_information{bulk_id} ne '') {
        my @new_array = ();
        foreach my $self (@array) {
            foreach my $sub_self (@{${$self}{bulk_jobs}}) {
                push (@new_array, \$sub_self);
                eval('&'.$base_package.'::finally($sub_self);');
            }
        }
        @array = @new_array;
    }
    #-----------------------------------------------------------------------------------------#
    # Return（実行レベルジョブオブジェクト）
    return @array;
}
sub finally {
###################################################################################################
#   ＜＜ 評価データを蓄積 ＞＞                                                                    #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 評価データを取得し、%{$shared_working_information{result}}へ蓄積する                  #
#   引数 ： $_[0] ＝ ジョブオブジェクト                                                           #
###################################################################################################
    my $self = shift;
    #-----------------------------------------------------------------------------------------#
    # 結果を取得
    my $key = $self->{id};
    my $cnt = 1;
    if ($shared_working_information{measurement_cnt} > 1) {
        $self->{id} =~ /(.+)_([\d]+)$/;
        $key = $1;
        $cnt = $2;
    }
    # 蓄積
    if (!exists ${$shared_working_information{result}}{$key}) { %{${$shared_working_information{result}}{$key}} = (); }
    ${${$shared_working_information{result}}{$key}}{$cnt} = eval('&'.$base_package.'::get_evaluation_value($self, \%shared_working_information);');
}
sub get_evaluation_value {
###################################################################################################
#   ＜＜ 評価データの取得 ＞＞                                                                    #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 評価データ(timeコマンド結果など)を取得し、返却する                                    #
#   引数 ： $_[0] ＝ ジョブオブジェクト                                                           #
#        ： $_[1] ＝ %shared_working_information                                                  #
#   返却 ： $evaluation_value                                                                     #
###################################################################################################
    my $self                       = shift;
    my %shared_working_information = %{shift(@_)};
    my $evaluation_value           = '';
    #-----------------------------------------------------------------------------------------#
    # ユーザ処理
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
    my @working_informations       = ();
    #-----------------------------------------------------------------------------------------#
    # ユーザ処理
    #-----------------------------------------------------------------------------------------#
    # Return
    return @working_informations;
}
sub output_result {
###################################################################################################
#   ＜＜ 探索結果出力 ＞＞                                                                        #
#-------------------------------------------------------------------------------------------------#
#   処理 ： 評価データから探索結果を作成し、指定ファイルへ出力                                    #
#   引数 ： $_[0] ＝ %shared_working_information                                                  #
###################################################################################################
    my %shared_working_information = @_;
    #-----------------------------------------------------------------------------------------#
    # ユーザ処理
    #-----------------------------------------------------------------------------------------#
}
1;
