package application_time_searcher;

use strict;
use builtin;
use File::Spec;
use Time::HiRes;
use NEXT;
use Coro;
use Coro::Channel;
use common;
use searcher;
use base qw(Exporter);
our @EXPORT = qw(initialize searcher set_initial_searcher get_search_information get_evaluation_value
                 entry_search_pattern initially finally evaluation output_result);

my  $range_block                = 4;                                                              # �֥�å�����
my  $comparison_target          = 0;                                                              # ����о�

sub get_search_information {
###################################################################################################
#   ��� õ��������� ���                                                                        #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �ؼ����줿�ե����뤫��õ���������������ֵѤ���                                      #
#   ���� �� $_[0] �� $search_information_file                                                     #
#   �ֵ� �� %search_information                                                                   #
###################################################################################################
    my ($search_information_file) = @_;
    my %search_information        = ();
    #-----------------------------------------------------------------------------------------#
    # Open
    open (SEARCH_INFORMATION, "< $search_information_file") or die "get_search_information:Cannot open $search_information_file";
    # Get Search_Information
    while (my $line = <SEARCH_INFORMATION>) {
        if ($line =~ /^\#/) { next; }
        chomp $line;
        if ($line =~ /^[\s\t]*$/) { next; }
        my @pattern = ();
        if ($line =~ /^(.+)\[(.+\.\..+)\]/) {
            @pattern = ($1);
            foreach my $i (eval "$2") {
                push (@pattern, $i);
            }
        } elsif ($line =~ /^(.+)\[.+,.+/) {
            @pattern = split (/[\[|,|\]]/, $line);
            pop @pattern;
        } else {
            @pattern = (split (/[\[|\]]/, $line));
            pop @pattern;
        }
        my $k = shift @pattern;
        @{$search_information{$k}} = @pattern;
    }
    # Close
    close(SEARCH_INFORMATION);
    #-----------------------------------------------------------------------------------------#
    # Return
    return %search_information;
}
sub set_initial_searcher {
###################################################################################################
#   ��� õ��������� ���                                                                        #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �ƥ�ץ졼�Ȥ���õ���ѥƥ�ץ졼�Ȥ�������                                          #
#   ���� �� $_[0] �� %template                                                                    #
#        �� $_[1] �� %working_information                                                         #
#   �ֵ� �� %working_information [ , %working_information [ , %working_information [ , ������ ] ] ]  #
###################################################################################################
    my %template             = %{shift(@_)};
    my %working_information  = %{shift(@_)};
    my $idx                  = -1;
    my @working_informations = ();
    #-----------------------------------------------------------------------------------------#
    # �֥�å�����������å�
    if (!exists $working_information{range_block}) { $working_information{range_block} = $range_block; }
    if ($working_information{range_block} =~ /\D+/) { die "syntax error : range_block\n"; }
    # ����оݤ�����å�
    if (!exists $working_information{comparison_target}) { $working_information{comparison_target} = $comparison_target; }
    if ($working_information{comparison_target} =~ /\D+/) { die "syntax error : comparison_target\n"; }
    $searcher::shared_working_information{comparison_target} = $working_information{comparison_target};
    # õ�����ϥ�٥��������
    $working_information{search_level} = 0;
    # RANGE��working_information������RANGE����õ���ϰϤ�������
    foreach my $key (sort grep {$_ =~ /^RANGE[\d]+$/} keys %template) {
        @{$working_information{$key}}    = @{$template{$key}};
        $working_information{"max_$key"} = $#{$template{$key}};
        $working_information{"min_$key"} = 0;
        $key =~ /^RANGE([\d]+)$/;
        $idx = $1;
    }
    # arg��working_information������arg����õ���ϰϤ�������
    foreach my $key (sort grep {$_ =~ /^arg[\d_]+\@*$/} keys %template) {
        if (ref ($template{$key}) eq 'ARRAY') {
            # Array
            @{$working_information{$key}}          = @{$template{$key}};
            $idx++;
            $working_information{"max_RANGE$idx"}  = $#{$template{$key}};
            $working_information{"min_RANGE$idx"}  = 0;
            $working_information{"link_RANGE$idx"} = $key;
            @{$working_information{"RANGE$idx"}}   = (0..$#{$template{$key}});
        }
    }
    push (@working_informations, \%working_information);
    #-----------------------------------------------------------------------------------------#
    # Return
    return @working_informations;
}
sub entry_search_pattern {
###################################################################################################
#   ��� õ���ѥ��������� ���                                                                    #
#-------------------------------------------------------------------------------------------------#
#   ���� �� õ��(prepare)����ѥ������RANGE������                                                #
#   ���� �� $_[0] �� %template                                                                    #
#        �� $_[1] �� %working_information                                                         #
#   �ֵ� �� %template                                                                             #
###################################################################################################
    my %template            = %{shift(@_)};
    my %working_information = %{shift(@_)};
    #-----------------------------------------------------------------------------------------#
    # RANGE������
    my @range_key = sort grep {$_ =~ /^RANGE[\d]+$/} keys %working_information;
    for (my $lv = 0; $lv <= $#range_key; $lv++) {
        my $key = $range_key[$lv];
        if (exists $working_information{"link_$key"}) {
            my $arg = $working_information{"link_$key"};
            if ($working_information{search_level} >= $lv) {
                @{$template{$key}} = &get_distribute_range($working_information{"max_$key"}, $working_information{"min_$key"}, $working_information{range_block});
            } else {
                @{$template{$key}} = (0);
            }
        } else {
            my @set_range = ();
            if ($working_information{search_level} >= $lv) {
                foreach my $i (&get_distribute_range($working_information{"max_$key"}, $working_information{"min_$key"}, $working_information{range_block})) {
                    push (@set_range, ${$working_information{$key}}[$i]);
                }
            } else {
                @set_range = (${$working_information{$key}}[0]);
            }
            $template{$key} = \@set_range;
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return�ʥƥ�ץ졼�ȡ�
    return %template;
}
sub get_distribute_range {
###################################################################################################
#   ��� ���ʬ�� ���                                                                          #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ��󥸤����֥�å���ʬ�䤹��                                                        #
#   ���� �� $_[0] �� ����RANGE��index                                                             #
#        �� $_[1] �� �Ǿ�RANGE��index                                                             #
#        �� $_[2] �� �֥�å�����                                                                 #
#   �ֵ� �� �֥�å����������                                                                  #
###################################################################################################
    my $range_max        = shift;
    my $range_min        = shift;
    my $range_block      = shift;
    my @distribute_range = ();
    #-----------------------------------------------------------------------------------------#
    my $range_add  = int((($range_max - $range_min) / $range_block) + 0.9);
    if ($range_add == 0) { $range_add++; }
    my $i = $range_min;
    while ($i < $range_max) {
        push (@distribute_range, $i);
        $i += $range_add;
    }
    push (@distribute_range, $range_max);
    #-----------------------------------------------------------------------------------------#
    # Return�ʥ֥�å���������󥸡�
    return @distribute_range;
}
sub get_evaluation_value {
###################################################################################################
#   ��� ɾ���ǡ����μ��� ���                                                                    #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ɾ���ǡ���(time���ޥ�ɷ�̤ʤ�)����������ֵѤ���                                    #
#   ���� �� $_[0] �� $self                                                                        #
#        �� $_[1] �� %shared_working_information                                                  #
#   �ֵ� �� $evaluation_value                                                                     #
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
    # �¹Ի��ּ���
    my $tim = 0;
    my $cnt = 0;
    my @line_datas = <EVALUATION_DATA>;
    foreach my $line_data (@line_datas) {
        if ($line_data =~ /^Command terminated by signal 9/) { return ''; }
        #��9.99user 9.99system �������פ���¹Ի���(user��system)�����
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
    # Return��ɾ���ǡ�����
    return $evaluation_value;
}
sub evaluation {
###################################################################################################
#   ��� ���ɾ�� ���                                                                            #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ɾ���ǡ�����ɾ����Ƚ�ꤷ�������õ���ϰϤ�õ���ѥƥ�ץ졼�Ȥ�����                    #
#   ���� �� $_[0] �� %template                                                                    #
#        �� $_[1] �� %working_information                                                         #
#        �� $_[2] �� %shared_working_information                                                  #
#   �ֵ� �� $working_information [ , %working_information [ , %working_information [ , ������ ] ] ]  #
###################################################################################################
    my %template                   = %{shift(@_)};
    my %working_information        = %{shift(@_)};
    my %shared_working_information = %{shift(@_)};
    my @working_informations       = ();
    #-----------------------------------------------------------------------------------------#
    # Get Result_Data
    my %result_data = ();
    for (my $lv = 0; $lv <= $working_information{search_level}; $lv++) {
        foreach my $key (@{$shared_working_information{"search_level_$lv"}}) {
            if (${$shared_working_information{result}}{$key} == ()) { next; }
            $result_data{$key} = ${$shared_working_information{result}}{$key};
        }
    }
    # Sort Judgment_Data
    my %judgment_data       = &get_judgment_data($shared_working_information{extraction_data}, \%result_data);
    my @sorted_judgment_key = ();
    if ($working_information{measurement_order} eq 'asc') {
        @sorted_judgment_key = sort {$judgment_data{$a} <=> $judgment_data{$b}} grep {$judgment_data{$_} != 0} keys %judgment_data;
    } else {
        @sorted_judgment_key = sort {$judgment_data{$b} <=> $judgment_data{$a}} grep {$judgment_data{$_} != 0} keys %judgment_data;
    }
    # õ�����ɾ��(fst/max/min)
    my $value = '';
    my $cnt   = 0;
    my %fst   = ();
    my %max   = ();
    my %min   = ();
    for (my $x = 0; $x <= $#sorted_judgment_key and $cnt < $working_information{extraction_cond}; $x++) {
        my $judgment_value = $judgment_data{$sorted_judgment_key[$x]};
        if ($value ne $judgment_value) {
            $value = $judgment_value;
            $cnt++;
        }
        my @index = split /\_/, $sorted_judgment_key[$x];
        shift @index;
        my $lv = -1;
        for (my $y = 0; $y <= $#index; $y++) {
            if (!exists $working_information{"RANGE$y"}) { next; }
            $lv++;
            if (exists $working_information{"link_RANGE$y"}) {
                if ($fst{"RANGE$y"} eq ''       ) { $fst{"RANGE$y"} = $index[$y]; $max{"RANGE$y"} = $index[$y]; $min{"RANGE$y"} = $index[$y]; }
                if ($max{"RANGE$y"} < $index[$y]) { $max{"RANGE$y"} = $index[$y]; }
                if ($min{"RANGE$y"} > $index[$y]) { $min{"RANGE$y"} = $index[$y]; }
            } else {
                for (my $i = 0; $i <= $#{$working_information{"RANGE$y"}}; $i++) {
                    if ($index[$y] eq ${$working_information{"RANGE$y"}}[$i]) {
                        if ($fst{"RANGE$y"} eq '') { $fst{"RANGE$y"} = $i; $max{"RANGE$y"} = $i; $min{"RANGE$y"} = $i; }
                        if ($max{"RANGE$y"} < $i ) { $max{"RANGE$y"} = $i; }
                        if ($min{"RANGE$y"} > $i ) { $min{"RANGE$y"} = $i; }
                    }
                }
            }
        }
    }
    # ����õ���ϰ�����(max/min)
    my $change    = 0;
    my @range_key = sort grep {$_ =~ /^RANGE[\d]+$/} keys %working_information;
    for (my $lv = 0; $lv <= $#range_key; $lv++) {
        my $key = $range_key[$lv];
        if ($working_information{search_level} < $lv) { last; }
        if ($working_information{search_level} == $lv) {
            my $fst = &get_RANGE_index($template{$key}, ${$working_information{$key}}[$fst{$key}]);
            for (my $i = $fst{$key}; $i >= 0 and $fst < 0; $i--) {
                $fst = &get_RANGE_index($template{$key}, ${$working_information{$key}}[$i]);
                if ($fst >= 0) {
                    $fst++;
                    splice(@{$template{$key}}, $fst, 0, ${$working_information{$key}}[$fst{$key}]);
                }
            }
            my $max = $max{$key};
            my $min = $min{$key};
            if (exists $working_information{"link_$key"}) {
                if ($fst < $#{$template{$key}}) { $max = ${$template{$key}}[($fst + 1)]; }
                if ($fst > 0                  ) { $min = ${$template{$key}}[($fst - 1)]; }
            } else {
                if ($fst < $#{$template{$key}}) { $max = &get_RANGE_index($working_information{$key}, ${$template{$key}}[($fst + 1)]); }
                if ($fst > 0                  ) { $min = &get_RANGE_index($working_information{$key}, ${$template{$key}}[($fst - 1)]); }
            }
            if ((($lv eq 0 or !exists $shared_working_information{precedence_shared}) and $fst{$key} >= ($max - 1) and $fst{$key} <= ($min + 1)) or
                ($change = 0 and $fst{$key} >= $max and $fst{$key} <= $min)) {
                $working_information{next_search} = 1;
            } else {
                if ($fst{$key} < ($max - 1)) { $max--; }
                if ($fst{$key} > ($min + 1)) { $min++; }
                if ($fst{$key} >= $max and $fst{$max} > $fst{$key}) { $max = $fst{$key} + 1; }
                if ($fst{$key} <= $min and $fst{$min} < $fst{$key}) { $min = $fst{$key} - 1; }
                $max{$key} = $max;
                $min{$key} = $min;
            }
        }
        if ($working_information{"max_$key"} ne $max{$key} or $working_information{"min_$key"} ne $min{$key}) {
            if (($max{$key} - $min{$key}) > 1) { $change = 1; }
        }
        $working_information{"fst_$key"} = $fst{$key};
        $working_information{"max_$key"} = $max{$key};
        $working_information{"min_$key"} = $min{$key};
    }
    # ����٥�����Ƚ��
    if ($change == 0) { $working_information{next_search} = 1; }
    if ($working_information{next_search} == 1) { $working_information{search_level}++; }
    delete $working_information{next_search};
    # õ����λȽ��
    if ($working_information{idx_max_search} < $working_information{search_level}) { return (); }
    push (@working_informations, \%working_information);
    # 
    # �ɲ�õ��
    if (exists $shared_working_information{precedence_shared}) {
        my %working_information2 = %working_information;
        if ($working_information2{next_search} <= 1 and $working_information2{idx_max_search} > $working_information2{search_level}) {
            my @range_key = sort grep {$_ =~ /^RANGE[\d]+$/} keys %working_information2;
            for (my $lv = 0; $lv <= $#range_key; $lv++) {
                my $key = $range_key[$lv];
                if ($working_information2{search_level} == $lv) {
                    $working_information2{"max_$key"} = $working_information2{"fst_$key"};
                    $working_information2{"min_$key"} = $working_information2{"fst_$key"};
                } 
            }
            $working_information2{search_level}++;
            push (@working_informations, \%working_information2);
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return�ʼ���٥��õ��
    return @working_informations;
}
sub get_judgment_data {
###################################################################################################
#   ��� Ƚ���оݥǡ����μ��� ���                                                                #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ɾ���ǡ�������Ƚ���оݥǡ��������                                                    #
#   ���� �� $_[1] �� ɾ���оݡ�max����硢min��Ǿ���med����֡�avg��ʿ�ѡ�sum=��ס�             #
#        �� $_[2] �� ɾ���ǡ���                                                                   #
#   �ֵ� �� %judgment_data                                                                        #
###################################################################################################
    my $extraction_data = shift;
    my %result          = %{shift(@_)};
    my %judgment_data   = ();
    #-----------------------------------------------------------------------------------------#
    foreach my $k (keys %result) {
        my @sorted_result  = sort {$a <=> $b} values %{$result{$k}};
        # ��¬���˽�����̻���
        if ($extraction_data eq 'max') {
            # �ʺ����
            $judgment_data{$k} = "$sorted_result[$#sorted_result]";
        } elsif ($extraction_data eq 'min') {
            # �ʺǾ���
            $judgment_data{$k} = "$sorted_result[0]";
        } elsif ($extraction_data eq 'med') {
            # ����֡�
            $judgment_data{$k} = "$sorted_result[int(($#sorted_result / 2) + 0.5)]";
        } elsif ($extraction_data eq 'avg') {
            # ��ʿ�ѡ�
            my $total_time = 0;
            foreach my $d (@sorted_result) {$total_time += $d}
            $judgment_data{$k} = sprintf("%.5f", ($total_time / ($#sorted_result + 1)));
        } elsif ($extraction_data eq 'sum') {
            # �ʹ�ס�
            $judgment_data{$k} = 0;
            foreach my $value (@sorted_result) { $judgment_data{$k} += $value; }
        } else {
            # �ʻ�����
            $judgment_data{$k} = ${$result{$k}{$extraction_data}};
        }
    }
    #-----------------------------------------------------------------------------------------#
    # Return��Ƚ���оݥǡ�����
    return %judgment_data;
}
sub get_RANGE_index {
###################################################################################################
#   ��� RANGE�ͤ�index���� ���                                                                  #
#-------------------------------------------------------------------------------------------------#
#   ���� �� RANGE(����)��������ͤ�index�����                                                    #
#   ���� �� $_[0] �� RANGE����                                                                    #
#        �� $_[1] �� �����å���                                                                   #
#   �ֵ� �� RANGE������index                                                                      #
###################################################################################################
    my @RANGE = @{shift(@_)};
    my $chk   = shift;
    #-----------------------------------------------------------------------------------------#
    for (my $i = 0; $i <= $#RANGE; $i++) {
        if ($chk == $RANGE[$i]) { return $i; }
    }
    return -1;
}
sub output_result {
###################################################################################################
#   ��� õ����̽��� ���                                                                        #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ɾ���ǡ�������õ����̤������������ե�����ؽ���                                    #
#   ���� �� $_[0] �� %shared_working_information                                                  #
###################################################################################################
    my %shared_working_information = @_;
    my %judgment_data              = &get_judgment_data($shared_working_information{extraction_data}, \%{$shared_working_information{result}});
    #-----------------------------------------------------------------------------------------#
    # sort(Ascending or Descending)
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
    foreach my $i (0..$out) {
        # Scale Calculation
        my $scale_mark = '*';
        my $scale = $scale_mark;
        foreach my $j (1..int(($judgment_data{$sorted_judgment_key[$i]} - $scale_min)/$scale_unit)) { $scale .= $scale_mark; }
        # Save Result
        @splited_times = split(/\./, $judgment_data{$sorted_judgment_key[$i]});
        if ($splited_times[1] eq '') { $splited_times[1] = '0'; }
        push (@output_time_datas, sprintf("%-${max_opid_digit}s %${max_time_digit }s.%-${max_time_digit_float}s %s", $sorted_judgment_key[$i], $splited_times[0], $splited_times[1], $scale));
    }
    # Open
    open (RESULT, "> $shared_working_information{search_result}") or die "Cannot open $shared_working_information{search_result}";
    # Output Result
    print RESULT "[õ�����]\n";
    print RESULT "----------------------------------------------------------------------------------------------------\n";
    foreach my $output_time_data (@output_time_datas) { print RESULT "$output_time_data\n"; }
    # Close
    close(RESULT);
}
sub get_scale_unit {
###################################################################################################
#   ��� ��������ñ�̤򻻽� ���                                                                  #
#-------------------------------------------------------------------------------------------------#
#   ���� �� $_[0] �� ������                                                                       #
#        �� $_[1] �� �Ǿ���                                                                       #
#   �ֵ� �� ��������ñ�̡������͡��Ǿ���                                                          #
###################################################################################################
    my ($max, $min) = @_;
    my $scale_unit  = 0;
    #-----------------------------------------------------------------------------------------#
    my $gap = ($min + $max) / 2;
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
