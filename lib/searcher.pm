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

our %shared_working_information : shared = ();                                                    # õ���������
our $bulk_cnt                   = 0;                                                              # bulk���Ѥ�bulk�����̾Ϣ��
my  %template                   = ();                                                             # �ƥ�ץ졼��
my  $search_information_file    = '';                                                             # õ������ե�����̾
my  $extraction_data            = 'med';                                                          # ɾ���оݡ�max����硢min��Ǿ���med����֡�avg��ʿ�ѡ�sum=��ס�
my  $extraction_cond            = 2;                                                              # ɾ������1��Ǿ�̡�2���̣���3���̣���
my  $measurement_order          = 'asc';                                                          # ��������asc�Ὰ�硢dec��߽��
my  $measurement_cnt            = 1;                                                              # ��¬���
my  $measurement_list           = 10;                                                             # ���Ϸ��
my  $search_result              = 'seacher_result';                                               # ��̽��ϥե�����̾

# �١����饤�֥��̾�����
our $base_package               = '';                                                             # �١����饤�֥��̾
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
#   ��� ������� ���                                                                            #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �桼�������������õ����������õ���ѥƥ�ץ졼�Ȥ�����                              #
#   ���� �� $_[0] �� �桼����������ץ�initialize�������                                         #
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
    # ��о��/��¬���/���Ϸ��
    if ($shared_working_information{extraction_cond}   =~ /\D+/) { die "syntax error : extraction_cond\n"; }
    if ($shared_working_information{measurement_cnt}   =~ /\D+/) { die "syntax error : measurement_cnt\n"; }
    if ($shared_working_information{measurement_list}  =~ /\D+/) { die "syntax error : measurement_list\n"; }
    # ɾ���о�
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
    # ������
    if ($shared_working_information{measurement_order} ne "asc" and
        $shared_working_information{measurement_order} ne "dec" ) {
        die "error ". $shared_working_information{measurement_order}. ": not exists in measurement_order\n";
    }
    # õ������ե�����̾/���ϥե�����̾
    if ($shared_working_information{search_result} eq "")      { die "error : search_result is null\n"; }
    if ($shared_working_information{search_result} =~ /^\s+$/) { die "error : search_result is only blank\n"; }
}
sub searcher {
###################################################################################################
#   ��� õ������ ���                                                                            #
#-------------------------------------------------------------------------------------------------#
#   ���� �� õ����¹�                                                                            #
#   ���� �� $_[0] �� %template                                                                    #
###################################################################################################
    my %template = @_;
    #-----------------------------------------------------------------------------------------#
    # õ�������template��ȿ��
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
#   ��� õ��������� ���                                                                        #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �ؼ����줿�ե����뤫��õ�����־������������ֵѤ���                                  #
#   ���� �� $_[0] �� $search_information_file                                                     #
#   �ֵ� �� %search_information                                                                   #
###################################################################################################
    my $search_information_file = shift;
    my %search_information      = ();
    #-----------------------------------------------------------------------------------------#
    # �桼������
    #-----------------------------------------------------------------------------------------#
    # Return
    return %search_information;
}
sub set_initial_searcher {
###################################################################################################
#   ��� õ��������� ���                                                                        #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �ƥ�ץ졼�Ȥ���õ���ѥƥ�ץ졼�Ȥ������ꤹ��                                      #
#   ���� �� $_[0] �� %template                                                                    #
#        �� $_[1] �� õ���ѥƥ�ץ졼��                                                           #
#   �ֵ� �� õ������Ѿ��� [,õ������Ѿ��� [,õ������Ѿ���[,������]]                         #
###################################################################################################
    my %template             = %{shift(@_)};
    my %working_information  = %{shift(@_)};
    my @working_informations = ();
    #-----------------------------------------------------------------------------------------#
    # �桼������
    push (@working_informations, \%working_information);
    #-----------------------------------------------------------------------------------------#
    # Return��õ������Ѿ����
    return @working_informations;
}
sub async_searcher {
###################################################################################################
#   ��� õ������Ѿ�����β�Ū��Ʊ��õ�� ���                                                  #
#-------------------------------------------------------------------------------------------------#
#   ���� �� õ������Ѿ�����˥���åɤ�Ω���夲��õ����»ܤ���                                  #
#   ���� �� $_[0] �� �ƥ�ץ졼��                                                                 #
#        �� $_[1] �� õ������Ѿ��� [,õ������Ѿ��� [,õ������Ѿ���[,������]]                #
###################################################################################################
    my $template             = shift;
    my $working_informations = shift;
    my $slp                  = 0;
    #-----------------------------------------------------------------------------------------#
    foreach my $working_information (@{$working_informations}) {
        if ($#{$working_informations} > 0) {
            my $job_coro = Coro::async {
                my $working_information = shift;
                # õ��
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
#   ��� õ�� ���                                                                                #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �ƥ�ץ졼�Ȥλؼ��˽���õ������                                                      #
#   ���� �� $_[0] �� �ƥ�ץ졼��                                                                 #
#        �� $_[1] �� õ������Ѿ���                                                               #
#   �ֵ� �� õ������Ѿ��� [,õ������Ѿ��� [,õ������Ѿ���[,������]]                         #
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
    # ��¬�����RANGE��ȿ��
    if ($working_information{measurement_cnt} > 1) {
        my $cnt = ($working_information{idx_max_search} + 1);
        $template{"RANGE$cnt"} = [1..$working_information{measurement_cnt}];
    }
    # prepare
    my @jobs = &searcher_prepare(%template);
    foreach my $self (@jobs) {
        # VALUE����arg������
        for (my $cnt = 0; $cnt <= $#{${$self}{VALUE}}; $cnt++) {
            if (exists $working_information{"link_RANGE$cnt"}) {
                my $arg = $working_information{"link_RANGE$cnt"};
                if ($arg =~ /^(arg.+)\@$/) {
                    ${$self}{$1}   = ${${$self}{$arg}}[${${$self}{VALUE}}[$cnt]];
                }
            }
        }
        # finished�ˤʤäƤ��른��֤�ɾ���ǡ��������
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
    # Return��õ������Ѿ��� [,õ������Ѿ��� [,õ������Ѿ���[,������]]��
    return \@working_informations;
}
###################################################################################################
#   ��� prepare ���                                                                             #
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
    # Return�ʥ��������ξ����
    return @jobs;
}
sub entry_search_pattern {
###################################################################################################
#   ��� õ���ѥ��������� ���                                                                    #
#-------------------------------------------------------------------------------------------------#
#   ���� �� õ��(prepare)����ѥ���������ꤹ��                                                   #
#   ���� �� $_[0] �� �ƥ�ץ졼��                                                                 #
#        �� $_[1] �� õ������Ѿ���                                                               #
#   �ֵ� �� �ƥ�ץ졼��                                                                          #
###################################################################################################
    my %template            = %{shift(@_)};
    my %working_information = %{shift(@_)};
    #-----------------------------------------------------------------------------------------#
    # �桼������
    #-----------------------------------------------------------------------------------------#
    # Return�ʥƥ�ץ졼�ȡ�
    return %template;
}
sub initially {
###################################################################################################
#   ��� prepare���arg���� ���                                                                  #
#-------------------------------------------------------------------------------------------------#
#   ���� �� prepare��˥���֥��֥����������arg�����������ֵѤ���                                #
#   ���� �� $_[0] �� ����֥��֥�������                                                           #
#   �ֵ� �� $self                                                                                 #
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
    # Return�ʥ���֥��֥������ȡ�
    return $self;
}
###################################################################################################
sub shared_initially {
    my $self = shift;
    #-----------------------------------------------------------------------------------------#
    # arg��CODE�ξ���ɾ�����ƺ�����
    foreach my $key (sort grep {$_ =~ /^arg[\d]+_[\d]+$/} keys %{$self}) {
        if (!exists ${$self}{"${key}\@"} and ref(${$self}{$key}) eq 'CODE') {
            ${$self}{$key} = &{${$self}{$key}}($self);
        }
    }
    $self = eval('&'.$base_package.'::search_initially($self);');
    #-----------------------------------------------------------------------------------------#
    # Return�ʥ���֥��֥������ȡ�
    return $self;
}
sub set_bulk_job {
###################################################################################################
#   ��� �Х륯���� ���                                                                          #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �Х륯���꤬������ϥХ륯������                                                    #
#   ���� �� $_[0] �� �¹ԥ�٥른��֥��֥�������                                                 #
#   �ֵ� �� �Х륯�������¹ԥ�٥른��֥��֥�������                                              #
###################################################################################################
    my @array = @_;
    #-----------------------------------------------------------------------------------------#
    if ($shared_working_information{bulk_id} ne '') {
        $bulk_cnt++;
        @array = &bulk::bulk("$shared_working_information{bulk_id}_${bulk_cnt}", @array);
    }
    #-----------------------------------------------------------------------------------------#
    # Return�ʥХ륯�������¹ԥ�٥른��֥��֥������ȡ�
    return @array;
}
sub unset_bulk_job {
###################################################################################################
#   ��� �Х륯��� ���                                                                          #
#-------------------------------------------------------------------------------------------------#
#   ���� �� �Х륯����֤ξ��ϥХ륯��������                                                  #
#   ���� �� $_[0] �� �¹ԥ�٥른��֥��֥�������                                                 #
#   �ֵ� �� �¹ԥ�٥른��֥��֥�������                                                          #
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
    # Return�ʼ¹ԥ�٥른��֥��֥������ȡ�
    return @array;
}
sub finally {
###################################################################################################
#   ��� ɾ���ǡ��������� ���                                                                    #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ɾ���ǡ������������%{$shared_working_information{result}}�����Ѥ���                  #
#   ���� �� $_[0] �� ����֥��֥�������                                                           #
###################################################################################################
    my $self = shift;
    #-----------------------------------------------------------------------------------------#
    # ��̤����
    my $key = $self->{id};
    my $cnt = 1;
    if ($shared_working_information{measurement_cnt} > 1) {
        $self->{id} =~ /(.+)_([\d]+)$/;
        $key = $1;
        $cnt = $2;
    }
    # ����
    if (!exists ${$shared_working_information{result}}{$key}) { %{${$shared_working_information{result}}{$key}} = (); }
    ${${$shared_working_information{result}}{$key}}{$cnt} = eval('&'.$base_package.'::get_evaluation_value($self, \%shared_working_information);');
}
sub get_evaluation_value {
###################################################################################################
#   ��� ɾ���ǡ����μ��� ���                                                                    #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ɾ���ǡ���(time���ޥ�ɷ�̤ʤ�)����������ֵѤ���                                    #
#   ���� �� $_[0] �� ����֥��֥�������                                                           #
#        �� $_[1] �� %shared_working_information                                                  #
#   �ֵ� �� $evaluation_value                                                                     #
###################################################################################################
    my $self                       = shift;
    my %shared_working_information = %{shift(@_)};
    my $evaluation_value           = '';
    #-----------------------------------------------------------------------------------------#
    # �桼������
    #-----------------------------------------------------------------------------------------#
    # Return
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
    # �桼������
    #-----------------------------------------------------------------------------------------#
    # Return
    return @working_informations;
}
sub output_result {
###################################################################################################
#   ��� õ����̽��� ���                                                                        #
#-------------------------------------------------------------------------------------------------#
#   ���� �� ɾ���ǡ�������õ����̤������������ե�����ؽ���                                    #
#   ���� �� $_[0] �� %shared_working_information                                                  #
###################################################################################################
    my %shared_working_information = @_;
    #-----------------------------------------------------------------------------------------#
    # �桼������
    #-----------------------------------------------------------------------------------------#
}
1;
