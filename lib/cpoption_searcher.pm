package cpoption_searcher;

use strict;
use builtin;
use File::Spec;
use Time::HiRes;
use Coro;
use Coro::Channel;

my  $matrix_file_name      = 'matrixfile';                                                    # �ޥȥ�å����ե�����̾����¾��ͶƳ������������ե������
my  $output_file_name      = 'seacher_result';                                                # ��̽��ϥե�����̾
my  $compile_comand        = 'gcc';                                                           # ����ѥ��륳�ޥ��
my  $slp                   = 1;                                                               # sleep��
my  $extraction_cond       = 1;                                                               # ��о���1��Ǿ�̡�2���̣���3���̣���
my  $measurement_list      = 10;                                                              # ���Ϸ��
my  $user_conditional      = '1';                                                             # �桼����������о�� (and if���ʸ)
my  $measurement_time      = 'med';                                                           # ��¬����max����硢min��Ǿ���med����֡�avg��ʿ�ѡ�
my  $measurement_cnt       = 1;                                                               # ��¬���
my  @compile_keys          = ();                                                              # �桼����������ץ��⥳��ѥ���ʸ���ꥭ��(compile1,compile2)
my  %templetes             = ();                                                              # �桼����������ץ��������

my  $default_pattern_file_name = 'defaultfile';                                               # ����ѥ�����ե�����̾
my  $default_matrix_file_name  = $matrix_file_name;                                           # ����ޥȥ�å����ե�����̾����¾��ͶƳ������������ե������
my  $defalut_output_file_name  = $output_file_name;                                           # �����̽��ϥե�����̾
my  $defalut_compile_comand    = $compile_comand;                                             # �������ѥ��륳�ޥ��
my  $defalut_extraction_cond   = $extraction_cond;                                            # �����о���1��Ǿ�̡�2���̣���3���̣���
my  $defalut_measurement_list  = $measurement_list;                                           # ������Ϸ��
my  $defalut_user_conditional  = $user_conditional;                                           # ����桼����������о�� (and if���ʸ)
my  $defalut_measurement_time  = $measurement_time;                                           # �����¬����max����硢min��Ǿ���med����֡�avg��ʿ�ѡ�
my  $defalut_measurement_cnt   = $measurement_cnt;                                            # �����¬���

our @compile_options       = ();                                                              # ���ץ��������[���ץ����̾,���ץ����ǡ���1,���ץ����ǡ���2,������]��
our %compile_patterns      = ();                                                              # �ѥ���������key=���ץ����ID��data=[���ץ����idx1,���ץ����idx2,������]��
my  %next_compile_patterns = ();                                                              # ����٥�ذ��Ϥ��ѥ�����(key=���ץ����ID��data=[���ץ����idx1,���ץ����idx2,������])

my  %stop_levels           = ();                                                              # ���롼����¹Ԥ��ʤ���٥�ꥹ��(key=�¹ԥ�٥� value=�Լ¹ԥ�٥�)
our $search_level          : shared = 0;                                                      # �¹ԥ�٥��ֹ�
my  @search_level_jobs     = ();                                                              # ��٥��̼¹ԥ���֡�[���ץ����ID,������]��
my  $base_option_level     = 0;                                                               # �١������ץ�����٥�

my  $jobseq                = 0;                                                               # ����֥��������ֹ�
my  $opid_seq              = 0;                                                               # ���ץ����ID�������󥹾���
my  %opid_jobseqs          = ();                                                              # �����SEQ�����key=���ץ����ID��data=�����SEQ(�������Ϣ��)��
my  @opids                 = ();                                                              # �¹ԥ�٥륪�ץ����ID����
my  %child_patterns        = ();                                                              # ͶƳ���ץ������˸��ߤΥѥ�����򵭲�����ǡ���
my  @matrix_files          = ();                                                              # �ޥȥ�å����ե��������
my  %setting_options       = ();                                                              # ����ѥ��ץ��������key=���ץ����ID��data=[���ץ����,������]��

my  @job_execute_times     : shared = ();                                                     # ������̼¹Ի��֡�data=���ץ����ID,�����̾,�¹ԥ�٥��ֹ�,�¹Ի��֡�
my  @opid_execute_times    : shared = ();                                                     # ���ץ����ID�̼¹Ի��֡�data=���ץ����ID,�¹Ի��֡�

###################################################################################################
#   ��� ������� ���                                                                            #
###################################################################################################
    $user::max_range += 2;
###################################################################################################
#   ��� ������� ���                                                                            #
###################################################################################################
sub initialize {
    my (%script_appointments) = @_;                                                           # �桼����������ץ�initialize�������
    @compile_options          = ();                                                           # ���ץ��������[���ץ����̾,���ץ����ǡ���1,���ץ����ǡ���2,������]��
    %compile_patterns         = ();                                                           # �ѥ���������key=���ץ����ID��data=[���ץ����idx1,���ץ����idx2,������]��
    @matrix_files             = ();                                                           # �ޥȥ�å����ե��������
    @search_level_jobs        = ();                                                           # ��٥��̼¹ԥ���֡�key=�¹ԥ�٥��ֹ桢data=[���ץ����ID,������]��
    %opid_jobseqs             = ();                                                           # �����SEQ�����key=���ץ����ID��data=�����SEQ(�������Ϣ��)��
    my @pattern_keys = sort (grep {$_ =~ /pattern[\d]+/} keys %script_appointments);
    my @group_keys   = sort (grep {$_ =~ /group[\d]+/} keys %script_appointments);
    my @parallel_keys = sort (grep {$_ =~ /parallel[\d]+/} keys %script_appointments);
    #-----------------------------------------------------------------------------------------#
    # ����ѥ��륳�ޥ��
    if (exists $script_appointments{"compile_cmd"}) {
        if ($script_appointments{"compile_cmd"} =~ /^\s+$/){
            die "error : compile_cmd is only blank\n";
        }
        $compile_comand = $script_appointments{"compile_cmd"};
    } else {
        $compile_comand = $defalut_compile_comand;
    }
    
    # �ޥȥ�å����ե�����̾
    if (exists $script_appointments{"matrix_file"}) {
        if ($script_appointments{"matrix_file"} =~ /^\s+$/){
            die "error : matrix_file_name is only blank\n";
        }
        $matrix_file_name = $script_appointments{"matrix_file"};
    } else {
        $matrix_file_name = $default_matrix_file_name;
    }
    
    # ���ϥե�����̾
    if (exists $script_appointments{"output_file"}) {
        if ($script_appointments{"output_file"} =~ /^\s+$/){
            die "error : output_file_name is only blank\n";
        }
        $output_file_name = $script_appointments{"output_file"};
    } else {
        $output_file_name = $defalut_output_file_name;
    }
    
    # ��о��
    if (exists $script_appointments{"extraction_cond"}) {
        if ($script_appointments{"extraction_cond"} =~/\D+/){
            die "syntax error : extraction_cond\n";
        }
        $extraction_cond = $script_appointments{"extraction_cond"};
    } else {
        $extraction_cond = $defalut_extraction_cond;
    }
    
    # �桼������о��
    if (exists $script_appointments{"user_conditional"}) {
        $user_conditional = $script_appointments{"user_conditional"};
    } else {
        $user_conditional = $defalut_user_conditional;
    }
    
    # ���Ϸ��
    if (exists $script_appointments{"out_list"}) { 
        if ($script_appointments{"out_list"} =~/\D+/){
            die "syntax error : out_list\n";
        }
        $measurement_list = $script_appointments{"out_list"};
    } else {
        $measurement_list = $defalut_measurement_list;
    }
    
    # ��¬����
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
    
    # ��¬���
    if (exists $script_appointments{"measurement_cnt"}) {
        if ($script_appointments{"measurement_cnt"} =~/\D+/) {
            die "syntax error : measurement_cnt\n";
        }
        $measurement_cnt = $script_appointments{"measurement_cnt"};
    } else {
        $measurement_cnt = $defalut_measurement_cnt;
    }
    
    # �١������ץ����
    if (exists $script_appointments{"base_option"}) {
        &add_base_option($script_appointments{"base_option"});
    } else {
        $compile_patterns{0} = [];
        $next_compile_patterns{0} = [];
    }
    
    # �ѥ�����ե�����򥪥ץ��������ȿ��
    if (exists $script_appointments{"pattern_file"}) {
        &get_pattern_file_data($script_appointments{"pattern_file"});
    } else {
        &get_pattern_file_data($default_pattern_file_name);
    }
    
    # ���롼�׻���
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
    
    # ����¹ԥ��ץ������� �ѥ�����˥ѥ���̾��ex. parallel1_1�ˤ�Ĥ���
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
    
    # �桼��������ѥ����󥪥ץ�����ѥ�����
    foreach my $pattern_key (@pattern_keys){
        if ($script_appointments{$pattern_key} eq '' or
            $script_appointments{$pattern_key} =~ /^\s+/) {
            warn "error : There is blank in the top of $pattern_key\n";
            next;
        }
        #�桼�������������
        my @user_compile_options = &arrangement_compile_option($script_appointments{$pattern_key});
        # ���ץ��������¸�ߤ��뤫�����å�
        my $overwrite_lv = &chk_user_compile_option(@user_compile_options);
        if ($overwrite_lv >= 0) {
            # �ʥ��ץ��������¸�ߤ����
            # ��¸�Υ��롼�ײ�����
            my $delete_group_name = ${$compile_options[$overwrite_lv]}[0];
            @compile_options = map {${$_}[0] =~ s/$delete_group_name//; $_;} @compile_options;
            # ���ץ�������򹹿�
            $compile_options[$overwrite_lv] = \@user_compile_options;
        } else {
            # �ʥ��ץ��������¸�ߤ��ʤ���
            # ���ץ���������ɲ�
            push (@compile_options, \@user_compile_options);
        }
    }
    
    # �ޥȥ�å����ե������ɤ߹���
    &get_matrix_file();
    
    # ����ѥ��ץ����ν������
    @{$setting_options{0}} = ();
    &upd_setting_option(0, 0, "", "");
    
    # ���󥪥ץ��������å�
    &chk_parallel_option();
    
    # Ʊ��٥��������ץ��������å�
    &chk_exists_option();
    
    # ���롼�ײ������������å�
    &chk_group_consistency();
    
    # ��¾���ץ����Υ��롼�ײ�
    &grouping_exclusion_option();
    
    # Ʊ���¹ԥ��ץ����Υ��롼�ײ�
    &grouping_simultaneous_option();
    
    # ������ꥪ�ץ����ˤ���¤��ؤ�
    &sort_compile_option();
    
    # �Фˤʤ륪�ץ������ɲ�
    &add_opposite_option();
    
    # ���󥪥ץ������¤��ؤ�
    &sort_parallel_option(@parallel_keys);
    
    # ���ץ���������¤Ӵ���
    &sort_group_option();
}
###################################################################################################
#   ��� �١������ץ�����ɲ� ���                                                                #
###################################################################################################
sub add_base_option {
    my ($base_option_str) = @_;
    my @base_options      = split (/\s/,$base_option_str);
    my @base_patterns     = ();
    %setting_options      = ();
    #-----------------------------------------------------------------------------------------#
    # �١������ץ������ɲ�
    foreach my $base_option (@base_options) {
        push (@compile_options, ['',$base_option]);
        push (@base_patterns, 1);
        &upd_setting_option(0, "", "$base_option");
    }
    unshift (@base_patterns, '');
    $compile_patterns{0} = \@base_patterns;
    $next_compile_patterns{0} = \@base_patterns;
    
    # �١������ץ�����������
    $base_option_level = @base_options;
    
    # search_level������
    $search_level = $base_option_level;
}
###################################################################################################
#   ��� �ѥ�����ե����������� ���                                                            #
###################################################################################################
sub get_pattern_file_data {
    my ($pattern_file_name) = @_;                                                             # �ѥ�����ե�����̾
    my %group_options       = ();                                                             # ���롼�׾����key=���롼��̾��data=���롼�ײ��������
    #-----------------------------------------------------------------------------------------#
    # OPEN
    open (PATTERN, "< $pattern_file_name") or die "get_pattern_file_data:Cannot open  $pattern_file_name";
    # �ѥ�����ե������������
    while (my $line = <PATTERN>) {
        if ($line =~ /^\#/) { next; }
        chomp $line;
        if ($line =~ /^[\s\t]*$/) { next; }
        if ($line =~ /^END$/) { last; }
        &chk_pattern_file($pattern_file_name, $line);
        # �ѥ������ѥ�����ե����������ɲ�
        my @line_compile_options = &arrangement_compile_option($line);
        if ($line_compile_options[0] ne '') {
            $group_options{$line_compile_options[0]}++;
        }
        push (@compile_options, \@line_compile_options);
    }
    # CLOSE
    close(PATTERN);
    
    # ���롼�ײ��������������å�
    my $group_idx = 0;
    foreach my $group_option_key (keys %group_options) {
        if ($group_options{$group_option_key} == 1) {
            warn "$group_option_key is not group\n";
            @compile_options = map {${$_}[0] =~ s/$group_option_key//; $_;} @compile_options;
        } else {
            # ���롼��̾��ѥ�����ե����륰�롼�פ�����
            $group_idx++;
            @compile_options = map {${$_}[0] =~ s/$group_option_key/pattern_file_group$group_idx/; $_;} @compile_options;
        }
    }
}
###################################################################################################
#   ��� �ѥ�����ե������⥳��ѥ��륪�ץ����ʸ�����å� ���                                  #
###################################################################################################
sub chk_pattern_file {
    my ($pattern_file_name, $compile_option_str) = @_;                                        # ����������ѥ��륪�ץ����
    #-----------------------------------------------------------------------------------------#
    unless ($compile_option_str =~ /^-[A-Za-z][^\s\r\{\}\[\]\(\)]*\{[^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
            $compile_option_str =~ /^-\{[A-Za-z][^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
            $compile_option_str =~ /^\{-[A-Za-z][^\{\}\[\]]*\}[^\s\r\{\}\[\]\(\)]*$/ or
            $compile_option_str =~ /^-[A-Za-z][^\s\r\{\}\[\]]*$/ ) {
        die "syntax error : $pattern_file_name\n";
    }
}
###################################################################################################
#   ��� �ѥ���������� ���                                                                    #
###################################################################################################
sub arrangement_compile_option {
    my ($line)    = @_;                                                                       # �����о�ʸ����
    my @arrangement_lines = ();                                                               # ���Ϸ�̡������
    #-----------------------------------------------------------------------------------------#
    # �ѥ����󤫤饰�롼��̾���ڤ�Ф�
    my ($line_str, $group_name) = &cut_group_name($line);
    
    # �ѥ����������
    @arrangement_lines = &cut_space(split (/[{|}]/, $line_str));
    if ($arrangement_lines[$#arrangement_lines] eq '') {pop (@arrangement_lines);}
    foreach my $i (1..$#arrangement_lines) {
        $arrangement_lines[$i] = $arrangement_lines[0].$arrangement_lines[$i];
    }
    if ($#arrangement_lines == 0) {
        $arrangement_lines[1] = $arrangement_lines[0];
    }
    
    # ���롼��̾������
    $arrangement_lines[0] = $group_name;
    
    # ���󲽥ѥ�������ֵ�
    return @arrangement_lines;
}
###################################################################################################
#   ��� �ѥ����󤫤饰�롼��̾���ڤ�Ф� ���                                                    #
###################################################################################################
sub cut_group_name {
    my ($line) = @_;                                                                          # �����о�ʸ����
    #-----------------------------------------------------------------------------------------#
    if ($line =~ /\}([\S]+)$/) {
        my @arrangement_lines = split (/$1/, $line);
        return ($arrangement_lines[0], $1);
    } else {
        return ($line, '');
    }
}
###################################################################################################
#   ��� ���׶��򥫥å� ���                                                                      #
###################################################################################################
sub cut_space {
    my @arrangement_lines = @_;                                                               # ����ǡ���
    #-----------------------------------------------------------------------------------------#
    foreach my $i (1..$#arrangement_lines) {
        # ����ζ���򥫥å�
        $arrangement_lines[$i] =~ s/^\s*(.*?)\s*$/$1/;
    }
    
    # ���׶��򥫥å�������ֵ�
    return @arrangement_lines;
}
###################################################################################################
#   ��� ��񤭥ѥ�����̵ͭ�����å� ���                                                          #
###################################################################################################
sub chk_user_compile_option {
    my @user_compile_options = @_;                                                            # �ѥ�����ե�����̾
    #-----------------------------------------------------------------------------------------#
    foreach my $lv (0..$#compile_options) {
        if ($lv < $base_option_level) { next; }
        foreach my $i1 (1..$#{$compile_options[$lv]}) {
            foreach my $i2 (1..$#user_compile_options) {
                if (${$compile_options[$lv]}[$i1] eq $user_compile_options[$i2]) {
                    # �ҥåȤ���index���ֵ�
                    return $lv;
                }
            }
        }
    }
    
    # ��񤭥ѥ�����̵�����ֵ�
    return -1;
}
###################################################################################################
#   ��� �ޥȥꥯ���ե����������� ���                                                          #
###################################################################################################
sub get_matrix_file {
    @matrix_files     = ();                                                                   # �ޥȥꥯ���ե��������
    my @upper_options = ();                                                                   # �Ѿ��ط����ץ��������data��[���ץ����,������]��
    my %count = ();                                                                           # �ޥȥ�å����ե�����Ԥν�ʣ�����å�
    #-----------------------------------------------------------------------------------------#
    # ͶƳ���ץ���� ��-O,+(-a,-b,-c)��
    # ��¾���ץ���� ��-O,-(-d,-e)��
    # OPEN
    open (MATRIX, "< $matrix_file_name") or die "get_matrix_file:Cannot open $matrix_file_name";
    # �ޥȥꥯ���ե������������
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
    
    # �Ѿ��ط����ɲåޥȥ�å����ե���������ȿ��
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
                    # �Фˤʤ륪�ץ����θ���
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
                    # �Фˤʤ륪�ץ����θ���
                    if (&chk_opposite_option(\@temp_matrix_data, \@upper_matrix_files)) {
                        last;
                    }
                    $temp_matrix_data[2] = ${$upper_option}[$upper_idx];
                    push (@add_matrix_files, \@temp_matrix_data);
                }
            }
        }
    }
    
    # �ɲåޥȥ�å����ե���������ޥȥ�å����ե����������ɲ�
    push (@matrix_files, @add_matrix_files);
}
###################################################################################################
#   ��� �Фˤʤ륪�ץ����θ��� ���                                                            #
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
#   ��� �Фˤʤ륪�ץ�����ʸ������� ���                                                      #
###################################################################################################
sub compare_opposite_option {
    my ($compile_option, $check_option) = @_;                                                 # �����å��оݥ��ץ���󡢥����å����ץ����
    my @compile_options = split (/=/, $compile_option);                                       # �����å��оݥ��ץ����ʡ�ʹߤ򥫥åȡ�
    my @check_options   = split (/=/, $check_option);                                         # �����å����ץ����ʡ�ʹߤ򥫥åȡ�
    #-----------------------------------------------------------------------------------------#    
    # �����å��оݤ������å�
    if ($compile_option eq $check_option) {
        # ��Ʊ�쥪�ץ����򸡽С�
        return 0;
    } elsif ($compile_option =~ /\=\.\+$/ or $check_option =~ /\=\.\+$/) {
        # �ʥ����å��оݳ���
        return 0;
    }
    
    # ʸ����ʬ�䤷������ɽ��������
    my $search_str = '';
    foreach my $compile_option_char (split (//, $compile_options[0])) {
        if ($search_str ne '^') { $search_str .= '(no|no_){0,1}'; }
        $search_str .= $compile_option_char;
    }
    $search_str .= '$';
    
    # �Фˤʤ륪�ץ���󤫥����å�
    if ($check_options[0] =~ /$search_str/) {
        # ���Фˤʤ륪�ץ����򸡽С�
        return 1;
    } else {
        # ���Фˤʤ륪�ץ����Ǥʤ���
        return 0;
    }
}
###################################################################################################
#   ��� ���󥪥ץ��������å� ���                                                            #
###################################################################################################
sub chk_parallel_option {
    #-----------------------------------------------------------------------------------------#
    # ���󲽤��������ץ��������Ʊ���¹ԥ��ץ���󤬤��뤫�����å�
    my @check_compile_options = grep {${$_}[0] =~ /parallel[\d]+_/} @compile_options;
    foreach my $matrix_file (grep {${$_}[1] =~ /[&-]/} @matrix_files) {
        my @matched_lvs = ();
        foreach my $matrix (@{$matrix_file}) {
            push (@matched_lvs, grep {grep {$_ =~ /(^|\s)$matrix($|\s)/} @{$check_compile_options[$_]}} 0..$#check_compile_options);
        }
        my %parallel_names = ();
        grep {$parallel_names{${$check_compile_options[$_]}[0]}++} @matched_lvs;
        
        # ���󥪥ץ����֤�Ʊ���¹ԥ��ץ����¸�ߤ������ٹ��̵��
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
#   ��� Ʊ��٥��������ץ��������å� ���                                                      #
###################################################################################################
sub chk_exists_option {
    #-----------------------------------------------------------------------------------------#
    # Ʊ��٥���������ץ���󤬤��뤫�����å�
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
#   ��� ���롼�ײ������������å� ���                                                            #
###################################################################################################
sub chk_group_consistency {
    my $group_name = 'add_group';                                                             # ���롼��̾Prefix
    my $group_idx  = 0;                                                                       # ���롼��index
    #-----------------------------------------------------------------------------------------#
    # �ޥȥ�å����̤�˥��롼�ײ��������������������å�
    foreach my $matrix_file (grep {${$_}[1] =~ /[&-]/} @matrix_files) {
        my $root_level = -1;
        
        # �����Ȥʤ륪�ץ����θ���
        foreach my $lv (0..$#compile_options) {
            if ((grep {$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/} @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]) > 0) {
                $root_level = $lv;
            }
        }
        
        # �оݤȤʤ륪�ץ����θ���
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
                #�롼�Ȥ�ޤ��оݥ��ץ���󤬸��Ĥ��ä���٥���Ф����롼��̾���դ���
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
#   ��� ��¾���ץ���󥰥롼�ײ�Ÿ�� ���                                                        #
###################################################################################################
sub grouping_exclusion_option {
    #-----------------------------------------------------------------------------------------#
    #õ���ѥ��������¾���ץ���󤬤��뤫�������ƥ��롼�ײ�
    foreach my $matrix_file (grep {${$_}[1] eq '-'} @matrix_files){
        # ��¾�δ����ˤʤ륪�ץ����¸�ߤ��뤫�����å�
        my @exclusion_idx_datas = [&search_compile_option(${$matrix_file}[0], 0)];
        if (${$exclusion_idx_datas[0]}[1] == 99) { next; }
        # ��¾��Υ��ץ����θ���
        foreach my $i (2..$#{$matrix_file}) {
            my @exclusion_idxs = &search_compile_option(${$matrix_file}[$i], 1);
            if ($exclusion_idxs[1] != 99) {
                push (@exclusion_idx_datas, @exclusion_idxs);
            }
        }
        if (@exclusion_idx_datas > 1) {
            # ����¾���ץ���󤢤��
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
#   ��� Ʊ���¹Ի��ꥪ�ץ����Υ��롼�ײ� ���                                                  #
###################################################################################################
sub grouping_simultaneous_option {
    #-----------------------------------------------------------------------------------------#
    # õ���ѥ������Ʊ���¹Ի��ꥪ�ץ���󤬤��뤫�������ƥ��롼�ײ�
    foreach my $matrix_file (grep {${$_}[1] =~ /&/} @matrix_files) {
        # �����Ȥʤ륪�ץ�����õ��
        foreach my $lv (0..$#compile_options) {
            foreach my $compile_option (@{$compile_options[$lv]}) {
                if ($compile_option =~ /(^|\s)${$matrix_file}[0]($|\s)/) {
                    # ��Ʊ���¹Ի��ꥪ�ץ���󤢤��
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
#   ��㥪�ץ����index���� ���                                                                  #
###################################################################################################
sub search_compile_option {
    my ($op_name, $target) = @_;                                                              # �������ץ����̾���������å�
    my @search_option = ();                                                                   # �������
    #-----------------------------------------------------------------------------------------#
    if ($op_name eq '') { return (0,0); }
    if ($op_name =~ /=\*$/) { $op_name =~ s/=\*$/.+/; }
    my $flg_search = 0;
    foreach my $lv (0..($#compile_options)) {
        foreach my $i (1..$#{$compile_options[$lv]}) {
            if ("${$compile_options[$lv]}[$i]" =~ /^${op_name}$/) {
                # �ʸ������ץ���󤢤��
                if ($target eq 0) { return ($lv,$i); }
                push (@search_option, [$lv,$i]);
                $flg_search = 1;
            }
        }
    }
    
    if ($flg_search eq 1) {
        # ������̤��ֵ�
        return @search_option;
    } else {
        # �������ץ����ʤ����ֵ�
        return (0,99);
    }
}
###################################################################################################
#   ��� ������ꥪ�ץ����ˤ���¤��ؤ� ���                                                    #
###################################################################################################
sub sort_compile_option {
    #-----------------------------------------------------------------------------------------#
    # õ���ѥ�����˽�����ꥪ�ץ���󤬤��뤫�������ƥ��롼�ײ�
    foreach my $matrix_file (grep {${$_}[1] =~ /=>/} @matrix_files) {
        my $option1_lv = -1;
        my $option2_lv = -1;
        
        # ���ץ����򸡺�����index��
        foreach my $lv (0..$#compile_options) {
            my $data_max = $#{$compile_options[$lv]};
            # �������ץ����̵ͭ������å�
            if ((grep{$_ =~ /(^|\s)${$matrix_file}[0]($|\s)/}@{$compile_options[$lv]}[1..$data_max]) > 0) {
                # �ʵ������ץ���󤢤��
                # �����Ȥʤ륪�ץ����Υ��ץ�������index�����
                $option1_lv = &get_compile_option_level($lv, $option2_lv);
            # �¤��ؤ��оݥ��ץ����̵ͭ������å�
            } elsif ((grep{$_ =~ /(^|\s)${$matrix_file}[2]($|\s)/}@{$compile_options[$lv]}[1..$data_max]) > 0) {
                # �¤��ؤ��оݥ��ץ����Υ��ץ�������index�����
                $option2_lv = &get_compile_option_level($lv, $option1_lv);
            }
        }
        
        # �¤��ؤ��оݤ������å�
        if ($option1_lv >= 0 and $option2_lv >= 0 and
            $option1_lv > $option2_lv) {
            # ���¤��ؤ��оݡ�
            my $sort_compile_option = splice (@compile_options, $option1_lv, 1);
            splice (@compile_options, $option2_lv, 0, $sort_compile_option);
        }
    }
}
###################################################################################################
#   ��� �оݥ��ץ����Υ�٥���� ���                                                          #
###################################################################################################
sub get_compile_option_level {
    my ($lv, $optionX_lv) = @_;                                                                          # �оݥ��ץ����Υ�٥�, ��Ӥ��륪�ץ����Υ�٥�
    #-----------------------------------------------------------------------------------------#
    if (${$compile_options[$lv]}[0] ne '') {
        my @matched_lvs;
        if (${$compile_options[$lv]}[0] =~ /(parallel[\d]+)/) {
            #  (������ꤢ��)
            @matched_lvs = grep {${${compile_options}[$_]}[0] eq $1} 0..$#compile_options;
        } else {
            # �ʥ��롼�׻��ꤢ���
            my $search_group_name = ${$compile_options[$lv]}[0];
            @matched_lvs = grep {${${compile_options}[$_]}[0] eq $search_group_name} 0..$#compile_options;
        }
        
        # ��Ӥ��륪�ץ����Ʊ�쥰�롼����ˤ��ʤ��������å�
        if ($optionX_lv != -1 and $matched_lvs[0] == $optionX_lv) {
            return $lv;
        }
        # ���롼�פ���Ƭ�Υ�٥���ֵ�
        return shift @matched_lvs;
    } else {
        # �ʥ��롼�׻���ʤ���
        # ��٥���ֵ�
        return $lv;
    }
}
###################################################################################################
#   ��� �Фˤʤ륪�ץ������ɲ� ���                                                            #
###################################################################################################
sub add_opposite_option {
    #-----------------------------------------------------------------------------------------#
    foreach my $lv (0..$#compile_options) {
        if ($lv < $base_option_level) { next; }
        my $compile_option = ${$compile_options[$lv]}[$#{$compile_options[$lv]}];
        foreach my $matrix_data (@matrix_files) {
            foreach my $i (2..$#{$matrix_data}){
                if (grep {$_ =~ /(^|\s)${$matrix_data}[$i]($|\s)/} @{$compile_options[$lv]}) { next; }
                #  �Фˤʤ륪�ץ����򸡺�
                if ((&compare_opposite_option(${$matrix_data}[$i], $compile_option)) or
                    (&compare_opposite_option($compile_option, ${$matrix_data}[$i]))) {
                    # ���Фˤʤ륪�ץ����򸡽С�
                    push (@{$compile_options[$lv]}, ${$matrix_data}[$i]);
                }
            }
        }
    }
}
###################################################################################################
#   ��� ���󥪥ץ����Υ����� ���                                                            #
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
#   ��� ���ץ���������¤Ӵ��� ���                                                            #
###################################################################################################
sub sort_group_option {
    %stop_levels             = ();                                                            # �¹��޻ߥ�٥����
    my @new_compile_options  = ();                                                            # ���������륪�ץ�������
    my @delete_levels        = ();                                                            # ���롼�ײ��ˤ���ɲä�����٥�ΰ���
    unshift (@compile_options, []);
    unshift (@new_compile_options, []);
    #-----------------------------------------------------------------------------------------#
    foreach my $lv (1..$#compile_options){
        if ((grep {$lv == $_} @delete_levels) != ()) { next; }
        # ���롼��̵̾ͭ������å�
        if (${$compile_options[$lv]}[0] ne '') {
            # �ʥ��롼�פ����
            my $group_name = ${$compile_options[$lv]}[0];
            my @grouping_levels = grep {${$compile_options[$_]}[0] eq $group_name} 1..$#compile_options;
            # ���롼�ԥ󥰸����о�
            push (@delete_levels, @grouping_levels);
            my $run_level = pop @grouping_levels;
            my @stop_level = ();
            foreach my $grouping_level (@grouping_levels) {
                # �ʼ¹��޻��оݡ�
                push (@new_compile_options, $compile_options[$grouping_level]);
                # �¹��޻ߥ�٥������
                push (@stop_level, $#new_compile_options);
            }
            # �ʼ¹��оݡ�
            push (@new_compile_options, $compile_options[$run_level]);
            # �¹��޻ߥ�٥������ɲ�
            @{$stop_levels{$#new_compile_options}} = @stop_level;
        } else {
            # �ʥ��롼�פʤ���
            push (@new_compile_options, $compile_options[$lv]);
        }
    }
    
    # ���ץ�������򹹿�
    @compile_options = @new_compile_options;
}
###################################################################################################
#   ��� õ���¹� ���                                                                            #
###################################################################################################
sub cpoption_searcher {
    my %templetes = @_;
    my @jobs = &prepare(%templetes);
    &submit(@jobs);
}
###################################################################################################
#   ��� ��������� ���                                                                          #
###################################################################################################
sub prepare {
    %templetes = @_;
    my %parent_opids = ();
    #-----------------------------------------------------------------------------------------#
    # �¹ԥ�٥륪�ץ����Ÿ��
    # �ƥ��ץ����ID�����
    my @last_parent_opids = sort {$a <=> $b} keys(%compile_patterns);
    
    # ���Υ�٥뤬�����оݥ�٥뤫�����å�
    if (${$compile_options[$search_level+1]}[0] =~ /(parallel[\d]+_)/) {
        my $parallel_name = $1;
        my %parallel_names;
        grep { $parallel_names{${$_}[0]}++} grep {${$_}[0] =~ /$parallel_name/} @compile_options;

        # ���ץ������ȹ礻Ÿ��
        foreach (keys %parallel_names) {
            %parent_opids = &dev_compile_pattern(%parent_opids);
        }
    } else {
        # ���ץ������ȹ礻Ÿ��
        %parent_opids = &dev_compile_pattern(\%parent_opids);
    }
    &optimization_compile_option(\%parent_opids);
    
    # �¹��оݤΥ��ץ����ID�����
    @opids = sort {$a <=> $b} grep {$last_parent_opids[$#last_parent_opids] < $_} keys %compile_patterns;
    if (@opids == ()) { return (); }
    
    # ����֥��֥�����������
    return &builtin::prepare(&prepare_search(%templetes));
}
###################################################################################################
#   ��� ���ץ����Υѥ����� ���                                                              #
###################################################################################################
sub dev_compile_pattern {
    my (%parent_opids) = @_;                                                                    # �ƥ��ץ����ID
    #-----------------------------------------------------------------------------------------#
    # �ѥ������оݥ�٥������
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
    
    # ���ץ������ȹ礻Ÿ��
    my %in_compile_patterns  = %next_compile_patterns;
    my @in_compile_pattern_keys = sort {$a <=> $b} keys %next_compile_patterns;
    foreach my $lv ($start_level..$search_level) {
        @{$search_level_jobs[$lv]} = ();
        if (@{$compile_options[$lv]} == 0) { next; }
        my %out_compile_patterns = ();
        foreach my $parent_opid (sort {$a <=> $b} keys %in_compile_patterns ) {
            my $parent_pattern;
            # ���ꥪ�ץ�����Ÿ��
            if ($parent_opid != 0) {
                if ($lv == $start_level) {
                    # �ʥ��롼�ײ��ʤ������ϥ��롼�ײ��κǽ�Υ�٥��
                    $parent_pattern = &get_compile_option($parent_opid)
                } else {
                    # �ʥ��롼�ײ������
                    foreach my $i (1..$#{$in_compile_patterns{$parent_opid}}) {
                        if (${$in_compile_patterns{$parent_opid}}[$i] > 0) {
                            $parent_pattern .= ' '. "${$compile_options[$i]}[${$in_compile_patterns{$parent_opid}}[$i]]";
                        }
                    }
                }
            }
            # Ʊ���¹ԥ��ץ�����оݤ������å�
            my $compile_options_str = join('|', @{$compile_options[$lv]}[1..$#{$compile_options[$lv]}]);
            if ($parent_pattern =~ /$compile_options_str/) {
                # �ʥ����å��оݡ�
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
                    # ���ץ����ID���٥��̼¹ԥ���֤���Ͽ
                    push (@{$search_level_jobs[$lv]}, "$parent_opid");
                }
            }
            foreach my $i (1..$#{$compile_options[$lv]}) {
                # �����(ͶƳ�ޤ�)���ץ���󤫥����å�
                my $search_level_option_index = '';
                if ((grep {${$compile_options[$lv]}[$i] =~ /(^|\s)$_(\s|$)/} @{$setting_options{$parent_opid}}) == 0 and
                    (grep {$_ =~ /(^|\s)${$compile_options[$lv]}[$i](\s|$)/} @{$setting_options{$parent_opid}}) == 0) {
                    # ��̤�����
                    $search_level_option_index = $i;
                }
                # ���ꤹ�٤����ץ���󤫥����å�
                my $flg_out = '';
                if ($lv == ($base_option_level + 1) or
                   ($search_level_option_index != "${$in_compile_patterns{$parent_opid}}[$lv]")) {
                    # �ѥ�����������Ͽ
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
                            # �ʥ��롼�ײ��ʤ������ϥ��롼�ײ��κǸ�Υ�٥��
                            # ���ץ����ID���٥��̼¹ԥ���֤���Ͽ
                            push (@{$search_level_jobs[$lv]}, "$opid_seq");
                            # �ƥ��ץ����ID�������Ͽ
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
                        # ���ץ����ID���٥��̼¹ԥ���֤���Ͽ
                        push (@{$search_level_jobs[$lv]}, "$parent_opid");
                    }
                }
            }
        }
        %in_compile_patterns = %out_compile_patterns;
        # �ѥ����������ɲ�
        if ($lv == $search_level) {
            %compile_patterns = (%compile_patterns, %out_compile_patterns);
            # �ƥ��ץ����ID���٥��̼¹ԥ���֤���Ͽ
            if ($start_level > 1 and $start_level ne $search_level) {
                push (@{$search_level_jobs[$lv]}, @in_compile_pattern_keys);
            }
        }
    }
    
    # �ƥ��ץ����ID������ֵ�
    return \%parent_opids;
}
###################################################################################################
#   ��� ����ѥ��륪�ץ������� ���                                                            #
###################################################################################################
sub get_compile_option {
    my ($opid)         = @_;                                                                  # ���ץ����ID
    my $compile_option = '';                                                                  # Ÿ�����ץ����
    my $opid_compile_option = '';                                                             # �ֵѥ��ץ����
    my @opid_compile_patterns = @{$compile_patterns{$opid}};                                  # ���ꥪ�ץ����ID�Υ���ѥ���ѥ��������
    my %option_count = ();                                                                    # ���ץ����̾��ʣ�����å���
    #-----------------------------------------------------------------------------------------#
    # ���ꥪ�ץ�����Ÿ��
    foreach my $i (1..$#opid_compile_patterns) {
        if ($opid_compile_patterns[$i] > 0) {
            # �ʥ��ץ����λ��ꤢ���ͶƳ���ץ�����null�ˡ�
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
    
    # Ÿ�����ץ������ֵ�
    return $opid_compile_option;
}
###################################################################################################
#   ��� ����ѥ��ץ����Υ����å� ���                                                          #
###################################################################################################
sub chk_setting_option {
    my ($opid, $option) = @_;
    my $chk_flg         = '';
    #-----------------------------------------------------------------------------------------#
    # õ���ѥ�����˥��ץ���󤬤��뤫����
    foreach my $matrix_file (grep {${$_}[1] =~ /^=>$/} @matrix_files) {
        # �������ץ���󸡺�
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
        #���ץ���󸡺�
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
#   ��� �ѥ�����ʸ��������оݥ��ץ��������¸�ߤ��뤫Ĵ�٤� ���                              #
###################################################################################################
sub chk_exists_all_search_option {
    my ($pattern, $matrix_file) = @_;
    #-----------------------------------------------------------------------------------------#
    # �������ץ��������¸�ߤ��뤫�����å�
    foreach my $option (@{$matrix_file}[2..$#{$matrix_file}]) {
        if ($pattern !~ /(^|\s)$option($|\s)/) {
            # ���������ץ����ʤ���
            return 0;
        }
    }
    
    # �������ץ���󤢤���ֵ�
    return 1;
}
###################################################################################################
#   ��� �ѥ�����ʸ��������оݥ��ץ����¸�ߤ��뤫Ĵ�٤� ���                                  #
###################################################################################################
sub chk_exists_search_option {
    my ($pattern, $matrix_file) = @_;
    #-----------------------------------------------------------------------------------------#
    # ��¾�Ȥʤ륪�ץ����¸�ߤ��뤫�����å�
    foreach my $option (@{$matrix_file}[2..$#{$matrix_file}]) {
        if ($pattern =~ /(^|\s)$option($|\s)/) {
            # ��¾���ץ���󤢤���ֵ�
            return 1;
        }
    }
    
    # ����¾���ץ����ʤ���
    return 0;
}
###################################################################################################
#   ��� ����ѥ��ץ�������ι��� ���                                                              #
###################################################################################################
sub upd_setting_option {
    my ($lv, $opid, $old_option, $new_option) = @_;                                           # �����å���٥롢���ץ����ID���쥪�ץ���󡢿����ץ����
    my @unset_options = ();                                                                   # ͶƳ������ץ����
    my @set_options   = ($new_option);                                                        # �ɲ�ͶƳ���ץ����
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
    # �ɲ�ͶƳ���ץ���������å�
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
    
    # ͶƳ������ץ���������å�
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
    
    # �쥪�ץ����¸�ߤ��뤫�����å�
    if ((grep {$_ =~ /^$old_option$/} @{$setting_options{$opid}}) == 0) {
        # ��¸�ߤ��ʤ���
        push (@{$setting_options{$opid}}, "$new_option");
    } else {
        # ��¸�ߤ����
        my @idx = map {$_ =~ /^$old_option$/; $_;} @{$setting_options{$opid}};
        ${$setting_options{$idx[0]}} = "$new_option";
    }
    
    # ����ѥ��ץ�������򹹿�
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
#   ��� ͶƳ���ץ��������å� ���                                                              #
###################################################################################################
sub optimization_compile_option {
    my ($parent_opids) = @_;                                                                  # �ƥ��ץ����ID
    #-----------------------------------------------------------------------------------------#
    # ��٥���Υ��ץ����ID�򥵥ޥ�
    my %count = ();
    @{$search_level_jobs[$search_level]} = grep {$_ ne ''} @{$search_level_jobs[$search_level]};
    @{$search_level_jobs[$search_level]} = grep {!$count{$_}++} @{$search_level_jobs[$search_level]};
    
    # ͶƳ�����ˤ�ä�Ʊ��ȤʤäƤ��ޤ��������
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
                # ����оݤ�Ƥ��ѹ�
                &upd_search_level_jobs($#{$compile_patterns{$sorted_check_opid[$i1]}}, $sorted_check_opid[$i1], $parent_opids);
                # �ѹ������ѥ��������
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
#   ��� ���롼�����ͶƳ���ץ��������å� ���                                                  #
###################################################################################################
sub chk_group_option {
    my $group_name        = shift;
    my (@compile_pattern) = @_;                                                  # ���롼��̾���ѥ�����
    #-----------------------------------------------------------------------------------------#
    my @group_lvs = grep {${${compile_options}[$_]}[0] eq $group_name} 0..$#compile_options;
    # ���롼�פκǽ���٥뤫�����å�
    if ($search_level < $group_lvs[$#group_lvs]) { return 1; }
    
    # ���롼���⤬ͶƳ���ץ����Τߤ������å�
    if ((grep{$_ > 0}@compile_pattern[$group_lvs[0]..$search_level]) > 0) {
        # ��ͶƳ���ץ����ʳ������
        return 1;
    }
    return 0;
}
###################################################################################################
#   ��� ����оݤ�Ƥ��ѹ� ���                                                                  #
###################################################################################################
sub upd_search_level_jobs {
    my ($lv, $opid, $parent_opids) = @_;                                                      # ��٥롢���ץ����ID���ƥ��ץ����ID����
    my $parent_opid = ${$parent_opids}{$opid};                                                # �ƥ��ץ����ID
    #-----------------------------------------------------------------------------------------#
    # ���ץ����ID��index�����
    my $change = &get_search_level_jobs_index($lv, $opid);
    
    #��٥��̼¹ԥ���֤˿ƥ��ץ����ID����Ͽ����Ƥ��ʤ����ƤοƤ�é��
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
#   ��� ���ץ����ID��index����� ���                                                           #
###################################################################################################
sub get_search_level_jobs_index {
    my ($lb, $opid) = @_;                                                                     # ��٥롢���ץ����ID
    #-----------------------------------------------------------------------------------------#
    foreach my $i (0..$#{$search_level_jobs[$lb]}) {
        # ��٥���˥��ץ����ID�����뤫�����å�
        if ($opid eq ${$search_level_jobs[$lb]}[$i]) {
            # index���ֵ�
            return $i;
        }
    }
    return -1;
}
###################################################################################################
#   ��� prepare������ ���                                                                       #
###################################################################################################
# �桼����������ץȤΥ����å���cpoption_seacher�Ѥξ����ɲ�
sub prepare_search {
    my (%job)     = @_;
    my @range     = ();                                                                       # range���ɲä��륪�ץ��������
    @compile_keys = grep {$_ =~ /^compile[\d]+$/} keys %job;
    #-----------------------------------------------------------------------------------------#
    # ����ѥ���ʸ���������������å�
    &chk_compile_str(%job);
    
    # �����seq���������
    foreach my $opid (@opids) {
        $jobseq++;
        $opid_jobseqs{$opid} = "$jobseq";
        push (@range, $jobseq);
    }
    
    # ���ץ����������󥸤��ɲ�
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
#   ��� ����ѥ���ʸ�����å� ���                                                                #
###################################################################################################
sub chk_compile_str {
    my (%job) = @_;                                                                           # ����ѥ���ʸ -o ** $OP **.o | -c $OP **.c
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
#   ��� ���֥���������� ���                                                                    #
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
#   ��� ����ּ¹� ���                                                                          #
###################################################################################################
sub submit {
    my @array = @_;                                                                           # �¹ԥ�٥른��֥��֥�������
    #-----------------------------------------------------------------------------------------#
    # ���֥������Ȥ򥹥�åɤ��Ȥ˼¹�
    &builtin::submit(@array);
    
    # �¹ԥ�٥른��֤����ƽ�λ����ޤ��Ե�
    &builtin::sync(@array);
    
    # �¹ԥ�٥른���ɾ��
    my @jobs = ();
    foreach my $check_opid (@{$search_level_jobs["${search_level}"]}) {
        # ���ץ����ID��μ¹Է�̤����
        my @opid_job_execute_times_data = grep {$_ =~ /^$check_opid/} @job_execute_times;
        if ($#opid_job_execute_times_data >= 0) {
            my $opid_execute_times_data = &get_opid_execute_time(@opid_job_execute_times_data);
            push (@jobs, [$check_opid, $opid_execute_times_data]);
            # ���ץ����ID�̼¹Ի��֤���Ͽ
            push (@opid_execute_times, "$check_opid,$opid_execute_times_data");
        }
    }
    
    # ���Υ�٥뤬¸�ߤ����� prepare submit sync �¹�
    if ($search_level < $#compile_options) {
        # �¹Է�̤��ᤤ����¤٤�
        my @sorted_jobs  = sort {${$a}[1] <=> ${$b}[1]} grep {${$_}[1] != 0} @jobs;
        my @next_pattern_jobs = ();
        my %temp_next_compile_patterns = %next_compile_patterns;
        %next_compile_patterns = ();
        my $cnt = 0;
        # ����٥�ذ��Ϥ��ѥ���������� 
        foreach my $i (0..$#sorted_jobs) {
            if ($extraction_cond > $cnt and
                eval ($user_conditional) ) {
                push (@next_pattern_jobs, $sorted_jobs[$i]);
                @{$next_compile_patterns{${$sorted_jobs[$i]}[0]}} = @{$compile_patterns{${$sorted_jobs[$i]}[0]}};
                $cnt++;
            }
        }
        # ����٥�Ǽ���٥�ذ����Ϥ��ѥ����󤬤ʤ���硢����٥�Υѥ����������
        if (%next_compile_patterns == ()) {
            %next_compile_patterns = %temp_next_compile_patterns;
        }
        # ����٥��¹�
        &cpoption_searcher(%templetes);
    } else {
        # ���Υ�٥뤬¸�ߤ��ʤ���� ��̽���
        # ��������ִ�λ��
        # ��̽���
        if ($#opid_execute_times >= 0) {
            &output_result();
        }
    }
}
###################################################################################################
#   ��� ����������� ���                                                                        #
###################################################################################################
sub before {}
###################################################################################################
#   ��� ����ּ¹� ���                                                                          #
###################################################################################################
sub start {
    my $self = shift;
    #-----------------------------------------------------------------------------------------#
    # NEXT::start
    $self->NEXT::start();
}
###################################################################################################
#   ��� ������ץ����� ���                                                                      #
###################################################################################################
# ����ѥ��롢�¹Ի��ּ���
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
    push (@body, "sleep 1"); # running ���᤹���� queued ���ʤ��ʤ����Ƥʤ�����
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
            # time���ޥ�ɷ��(ɸ�२�顼����)��ե�����˽���
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
#   ��� ����ָ���� ���                                                                        #
###################################################################################################
sub after {
    my $self = shift;                                                                         # ���֥�������
    #-----------------------------------------------------------------------------------------#
    # �������μ¹Է�̤���Ͽ
    if ((&jobsched::get_job_status) eq "aborted") { return; }
    my @execute_time = &get_execute_time($self);
    if ($#execute_time >= 0) {
        push (@job_execute_times, @execute_time);
    }
}
###################################################################################################
#   ��� �¹Ի��ּ��� ���                                                                        #
###################################################################################################
sub get_execute_time {
    my $self          = shift;                                                                # ���֥�������
    my @execute_times = ();                                                                   # �¹Ի��־���
    my $line_cnt      = 0;                                                                    # �ԥ�����
    my $opid          = $self->{opid};                                                        # ���ץ����ID
    #-----------------------------------------------------------------------------------------#
    # OPEN
    my $execute_time_file =  File::Spec->catfile( $self->{workdir}, $self->{id} . '.time' );
    open (EXECUTE_TIME, "< $execute_time_file") or warn "Cannot open  $execute_time_file";
    # �¹Ի��ּ���
    my @execute_time_datas = <EXECUTE_TIME>;
    foreach my $execute_time_data (@execute_time_datas) {
        $line_cnt++;
        if ($execute_time_data =~ /^Command terminated by signal 9/) { return (); }
        #��9.99user 9.99system �������פ���¹Ի���(user��system)�����
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
#   ��� �¹Ի��ּ��� ���                                                                        #
###################################################################################################
sub get_opid_execute_time {
    my @execute_times = ();
    foreach my $pg_time_data (@_) {
        my @pg_time_data = split(/,/,$pg_time_data);
        push (@execute_times, $pg_time_data[$#pg_time_data]);
    }
    my @sorted_execute_times  = sort {$a <=> $b} @execute_times;                              # ���粽�¹Ի���
    #-----------------------------------------------------------------------------------------#
    # ��¬���˽�����̻��Ф�������(�����̾���¹Ի���)���ֵ�
    if ($measurement_time eq 'max') {
        # �ʺ����
        return "$sorted_execute_times[$#sorted_execute_times]";
    } elsif ($measurement_time eq 'min') {
        # �ʺǾ���
        return "$sorted_execute_times[0]";
    } elsif ($measurement_time eq 'med') {
        # ����֡�
        my $execute_time_index = int(($#sorted_execute_times / 2) + 0.5);
        return "$sorted_execute_times[$execute_time_index]";
    } else {
        # ��ʿ�ѡ�
        my $total_time = 0;
        foreach my $execute_time_data (@sorted_execute_times) {
            $total_time += $execute_time_data;
        }
        my $return_time = sprintf("%.2f", ($total_time / ($#sorted_execute_times+ 1)));
        return $return_time;
    }
}
###################################################################################################
#   ��� ������̽��� ���                                                                        #
###################################################################################################
sub output_result {
    my @execute_times       = ();                                                             # �¹Է��
    my %check_opid          = ();
    my @output_time_datas   = ();                                                             # ���־���
    my @output_option_datas = ();                                                             # ���ץ�������
    #-----------------------------------------------------------------------------------------#
    foreach my $opid_time_data (@opid_execute_times) {
        my @opid_time_data = split(/,/,$opid_time_data);
        if ($opid_time_data[1] == 0) { next; }
        if (exists $check_opid{$opid_time_data[0]}) { next; }
        $check_opid{$opid_time_data[0]} = $opid_time_data[$#opid_time_data];
        push (@execute_times, [$opid_time_data[0], $opid_time_data[$#opid_time_data]]);
    }
    if (@execute_times == ()) { return; }
    my @sorted_jobs = sort {${$a}[1] <=> ${$b}[1]} @execute_times;                            # ���粽�¹Է��
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
    
    # ������̤��Խ�
    my $jobs = $#sorted_jobs;
    if ($measurement_list > $jobs) {
        $measurement_list = $jobs;
    }
    my $max_opid_digit = ${$sorted_jobs[$#sorted_jobs]}[0] =~ tr/0-9/0-9/;
    if ($max_opid_digit < 3) {$max_opid_digit = 3}
    my $max_time_digit = ${$sorted_jobs[$#sorted_jobs]}[1]  =~ tr/0-9\./0-9\./;
    foreach my $i (0..$measurement_list) {
        # �������뻻��
        my $scale_mark = '*';
        my $scale = $scale_mark;
        foreach my $j (1..int(${$sorted_jobs[$i]}[1]/$magnification)){
            $scale .= $scale_mark;
        }
        # ���־������¸
        push (@output_time_datas  , sprintf("%${max_opid_digit}d %${max_time_digit }.2f %s", $opid_jobseqs{${$sorted_jobs[$i]}[0]}, ${$sorted_jobs[$i]}[1], $scale));
        # ���ץ����������¸
        my $opid_compile_option = &get_compile_option(${$sorted_jobs[$i]}[0]);
        push (@output_option_datas, sprintf("%${max_opid_digit}d%s", $opid_jobseqs{${$sorted_jobs[$i]}[0]}, $opid_compile_option));
    }
    
    # OPEN
    open (RESULT, "> $output_file_name") or die "Cannot open  $output_file_name";
    # �Խ���̤����
    print RESULT "[õ�����]\n";
    print RESULT sprintf("%-${max_opid_digit}s %s \n", 'No.', 'TIME');
    print RESULT "--------------------------------------------------\n";
    foreach my $output_time_data (@output_time_datas) {
        print RESULT "$output_time_data\n";
    }
    print RESULT "\n";
    print RESULT "[���ץ�������]\n";
    print RESULT sprintf("%-${max_opid_digit}s %s \n", 'No.', 'OPTION');
    print RESULT "--------------------------------------------------\n";
    foreach my $output_option_data (@output_option_datas) {
        print RESULT "$output_option_data\n";
    }
    # CLOSE
    close(RESULT);
}
1;
