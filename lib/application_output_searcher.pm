package application_output_searcher;

use strict;
use builtin;
use File::Spec;
use Time::HiRes;
use NEXT;
use Coro;
use Coro::Channel;
use common;
use application_time_searcher;
use base qw(Exporter);
our @EXPORT = qw(initialize searcher set_initial_searcher get_search_information get_evaluation_value
                 entry_search_pattern initially finally evaluation output_result);

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
    # OPEN
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
    my $evaluation_data_file =  File::Spec->catfile( $wkdir_str, $self->{JS_stdout} );
    if (!-e "$evaluation_data_file") { return (); }
    open (EVALUATION_DATA, "< $evaluation_data_file") or warn "Cannot open  $evaluation_data_file";
    # 実行時間取得
    my $pg_time = 0;
    my @line_datas = <EVALUATION_DATA>;
    foreach my $line_data (@line_datas) {
        if ($line_data =~ /^return\=([0-9\.]+)/) { $evaluation_value = ($1 + $3); }
    }
    # CLOSE
    close (EVALUATION_DATA);
    return $evaluation_value;
}
1;
