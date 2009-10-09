package Data_Extraction;
use Exporter;
@ISA    = (Exporter);
@EXPORT = qw(EF);
use strict;
use threads;
use threads::shared;
#use warnings;
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
my $pipe_buf_plus = 100;     # �e���o���Ȃ��ő�pipe�o�b�t�@��
                             # ���[�Useek�o�b�t�@�����w�肳��Ă���ꍇ�A���ۂ̍ő�pipe�o�b�t�@���́i���[�Useek�o�b�t�@���{pipe�o�b�t�@���j

###################################################################################################
#   ���� ���o�Ώۃt�@�C����` ����                                                                #
###################################################################################################
sub EF {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���̓f�[�^���                                                          #
    #                 �E�ϐ��w��    �j�ϐ���                                                  #
    #                 �E�t�@�C���w��jfile:�t�@�C����                                         #
    #         $_[1] = ���[�Useek�o�b�t�@��                                                    #
    # ���� �F ���̓f�[�^�`�F�b�N�A�I�u�W�F�N�g��`�i���o�Ώۃt�@�C����`�j                    #
    # �ԋp �F �I�u�W�F�N�g                                                                    #
    #-----------------------------------------------------------------------------------------#
    my $cond_index    = 0;
    my @cond_data     = ();
    my @cond_buf      = ();
    my @cond_buf_max  = ();
    my @seek_buf      = ();
    my $seek_buf_max  = 0;
    my $seek_kbn      = '';
    my $seek_index    = 0;
    my @seek_num      = ();
    my $get_kbn       = '';
    my $get_index     = 0;
    my @get_num       = ();
    my $input         = '';
    my @mid           = ();
    my $output        = '';
    my $output_kbn    = '';
    my $output_index  = 0;
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
    
    # ���̓f�[�^�`�F�b�N
    my @in_data = &check_in_data($_[0]);
    # ���[�Useek�o�b�t�@���`�F�b�N
    $seek_buf_max = &check_seek_max($_[1]);
    
    # �I�u�W�F�N�g��`
    my $Job = {
             # ���͏��
               "in_kbn"        =>$in_data[0],                 # ���͋敪�i�t�@�C��or�ϐ��j
               "in_name"       =>$in_data[1],                 # ���̓f�[�^���i�t�@�C����or�ϐ����j
             # ���o����
               "cond_index"    =>$cond_index,                 # ���o����index
               "cond_data"     =>\@cond_data,                 # ���o����
             # �o�b�t�@
               "cond_buf"      =>\@cond_buf,                  # ���o�o�b�t�@
               "cond_buf_max"  =>\@cond_buf_max,              # ���o�o�b�t�@��
               "seek_buf"      =>\@seek_buf,                  # seek�o�b�t�@
               "seek_buf_max"  =>$seek_buf_max,               # seek�o�b�t�@��
               "seek_kbn"      =>$seek_kbn,                   # seek�敪�iseek/cond/input/org�j
               "seek_index"    =>$seek_index,                 # seek�o�b�t�@index�i�o�b�t�@�̔z��index�j
               "seek_num"      =>\@seek_num,                  # seek�s���i�I���W�i���s�ԍ��A�o�C�g�ʒu�A���͍s�ԍ��j
               "get_kbn"       =>$get_kbn,                    # get�敪�iseek/cond/input/org�j
               "get_index"     =>$get_index,                  # get�o�b�t�@index�i�o�b�t�@�̔z��index�j
               "get_num"       =>\@get_num,                   # get�s���i�I���W�i���s�ԍ��A�o�C�g�ʒu�A���͍s�ԍ��j
             # pipe���
               "input"         =>$input,                      # ���̓f�[�^�i��sED���o���ʁj
               "output"        =>$output,                     # �o�̓f�[�^�i���o���ʁj
             # �o�͏��
               "mid"           =>\@mid,                       # ���[�U���o�f�[�^�i��ǂݕ����j
               "output_kbn"    =>$output_kbn,                 # �o�͋敪
               "output_index"  =>$output_index};              # �o�̓f�[�^index
    bless $Job;
    return $Job;
}
###################################################################################################
#   ���� ���̓f�[�^�`�F�b�N ����                                                                  #
###################################################################################################
sub check_in_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���̓f�[�^���                                                          #
    # ���� �F �ϐ��w��    �j�ϐ����݃`�F�b�N�A�f�[�^���݃`�F�b�N                              #
    #         �t�@�C���w��j�t�@�C�����݃`�F�b�N�A�Ǎ��݌����`�F�b�N�A�f�[�^���݃`�F�b�N      #
    # �ԋp �F ���͋敪�A���̓f�[�^��                                                          #
    #-----------------------------------------------------------------------------------------#
    my @in_data = ();
    
    if ($_[0] !~ /file:/) {
        # �ϐ��w��
        $in_data[0] = '';
        $in_data[1] = '${main::'.$_[0].'}';
        if (! defined eval($in_data[1])) {
            # �ϐ��Ȃ�
            print STDERR "Input variable($_[0]) not found\n";
            exit 99;
        }
        if (eval($in_data[1]) eq '') {
            # �ϐ��ɒl�Ȃ�
            print STDERR "There are not the input data($_[0])\n";
            exit 99;
        }
    } else {
        # �t�@�C���w��
        $in_data[0] = 'file';
        $in_data[1] = substr $_[0], 5;
        if (!-e "$in_data[1]") {
            # �t�@�C���Ȃ�
            print STDERR "Input file($_[0]) not found\n";
            exit 99;
        } elsif (!-r "$in_data[1]") {
            # �t�@�C���ɓǍ��݌����Ȃ�
            print STDERR "Input file($_[0]) is not read authority\n";
            exit 99;
        }
        my @in_file_information = stat $in_data[1];
        if ($in_file_information[7] == 0) {
            # �t�@�C������
            print STDERR "There are not the input data($_[0])\n";
            exit 99;
        }
    }
    return @in_data;
}
###################################################################################################
#   ���� ���[�Useek�o�b�t�@���`�F�b�N ����                                                        #
###################################################################################################
sub check_seek_max {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���[�Useek�o�b�t�@��                                                    #
    # ���� �F ���l�`�F�b�N                                                                    #
    # �ԋp �F ���[�Useek�o�b�t�@��                                                            #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] eq "") {
        return 0;
    } elsif ($_[0] =~ /^\d+$/) {
        return $_[0];
    } else {
        # ���[�Useek�o�b�t�@���Ɍ��
        print STDERR "Greatest Seek Buffers Number is an Error($_[0])\n";
        exit 99;
    }
}
###################################################################################################
#   ���� ���o������` ����                                                                        #
###################################################################################################
sub ED {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    #         $_[1�`]= ���o�f�[�^�w��                                                         #
    # ���� �F ���o�����`�F�b�N�A���o�����ݒ�                                                  #
    #-----------------------------------------------------------------------------------------#
    # ���o�f�[�^�w��                                                                          #
    #   �s���o                                                                                #
    #     �s�ԍ��w��  �F[!]L/�s�ԍ�[/[�͈�][/�񒊏o]]                                         #
    #     ���K�\���w��F[!]LR/���o����[/�͈�][/�񒊏o]]                                       #
    #     �������ȊO�̒��o�́A�擪��"!"��t�^                                                 #
    #   �񒊏o                                                                                #
    #     ��ԍ��w��  �F[!]C/��ԍ�[/�͈�]                                                    #
    #     ���K�\���w��F[!]CR/���o����[/�͈�]                                                 #
    #     �������ȊO�̒��o�́A�擪��"!"��t�^                                                 #
    #   ���[�U�[���o  �F�m"�p�b�P�[�W��::�T�u���[�`����"[, "���[�U�[���o����", ��� ]�n        #
    #                   ����O�́m�n�́A�z���`���Ӗ�����                                    #
    #-----------------------------------------------------------------------------------------#
    my $cond_buf_max = 0;
    
    # ���o�����`�F�b�N
    my @cond_data = &check_extraction_cond(@_);
    if ($#cond_data >  9) {
        # ���o����������
        print STDERR "Extraction Conditions Exceed a Maximum Number \($cond_data[10]\)\n";
        exit 99;
    }
    foreach (grep{${$_}[0] =~ 'L' and ${$_}[3] =~ /^-\d+$/}@cond_data) {
         if ($cond_buf_max > ${$_}[3]) {
             $cond_buf_max = ${$_}[3];
         }
    }
    
    # ���o�����ݒ�
    push(@{$_[0]->{cond_data}}, [@cond_data]);
    push(@{$_[0]->{cond_buf_max}}, ($cond_buf_max * -1));
}
###################################################################################################
#   ���� ���o�����`�F�b�N ����                                                                    #
###################################################################################################
sub check_extraction_cond {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    #         $_[1�`]= ���o�f�[�^�w��                                                         #
    # ���� �F ���o�����`�F�b�N�A��^���o�����̋L�q�`�F�b�N                                    #
    #-----------------------------------------------------------------------------------------#
    my $obj         = shift;
    my @cond_data   = ();
    
    foreach (@_) {
        if (/^\!{0,1}[CLcl][Rr]*\//) {
            # ��^���o
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
                # ���o�敪���
                print STDERR "Extraction Division is an Error \($_\)\n";
                exit 99;
            }
        } elsif ($_ =~ /^ARRAY\(.*\)/) {
            my @in_cond_user = @{$_};
            # ���[�U�[���o
            if ($in_cond_user[0] =~ /\:\:/) {
                push(@cond_data, ["USER", @in_cond_user]);
            } else {
                # ���o�敪���
                print STDERR "Extraction Division is an Error \(@{$_}\)\n";
                exit 99;
            }
        } else {
            # ���o�敪���
            print STDERR "Extraction Division is an Error \($_\)\n";
            exit 99;
        }
    }
    return @cond_data;
}
###################################################################################################
#   ���� ��^���o�����̋L�q�`�F�b�N ����                                                          #
###################################################################################################
sub check_fixed_form_cond {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �m��ے�敪                                                            #
    #         $_[2] = ���o�敪                                                                #
    #         $_[3] = �N�_                                                                    #
    #         $_[4] = �͈�                                                                    #
    # ���� �F ��^���o�����̋L�q�`�F�b�N                                                      #
    #-----------------------------------------------------------------------------------------#
    if ($_[1] ne '' and $_[1] ne '!') {
        # �m��ے�敪���
        print STDERR "Affirmation Negation Division is an Error \($_[1]\)\n";
        exit 99;
    }
    if (($_[2] eq 'L' or $_[2] eq 'C') and ($_[3] eq 'E' or $_[3] eq 'e')) {
        $_[3] = 'E';
    } elsif (($_[2] eq 'L' and ($_[3] !~ /^\d+$/ or $_[3] == 0)) or
             ($_[2] eq 'C' and ($_[3] !~ /^\d+$/ or $_[3] <= 0))) {
        # �N�_�ԍ����
        print STDERR "Starting Point Number is an Error \($_[3]\)\n";
        exit 99;
    }
    if ($_[2] =~ /R/ and $_[3] eq '') {
        # �N�_���K�\�w�茻����
        print STDERR "Regular Expression Character string is not Found\n";
        exit 99;
    }
    if ($_[2] =~ /R/ and $_[4] =~ /^[\+-]\d+/ and ($_[4] !~ /^[\+-]\d+$/ or $_[4] == 0))  {
        # ���o�͈͌��
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
            # ���o�͈͌��
            print STDERR "End Range Number is an Error \($_[4]\)\n";
            exit 99;
        }
    }
}
###################################################################################################
#   ���� ���o���s ����                                                                            #
###################################################################################################
sub ER {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    # ���� �F �s�f�[�^�擾�AED�R�}���h���o���s                                                #
    # �ԋp �F ���o����                                                                        #
    #-----------------------------------------------------------------------------------------#
    my $obj      = shift;
    my @thread   = ();
    
    if ($obj->{in_kbn} eq 'file') {
        &in_file_open($obj->{in_name});
    }
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
    
    if ($obj->{in_kbn} eq 'file') {
        &in_file_close($obj->{in_name});
    }
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
    my @line     = ();
    my $line_in  = 0;
    my @seek     = ();
    
    threads->new(sub {
        $obj->{input}      = \@input;
        $obj->{output}     = $output;
        push(@line, (&get_line_data($obj, $line_in)));
        push(@seek, 0);
        push(@seek, (tell EXTRACTION_FILE));
        while ($line[0] ne 'Data_Extraction_END') {
            $line_in++;
            push(@line, (&get_line_data($obj, $line_in)));
            push(@seek, (tell EXTRACTION_FILE));
            my @result;
            if ($obj->{in_kbn} eq '') {
                @result = &check_existence($obj, [$line_in, "", $line_in, "", $line[0]], $line[1]);
            } else {
                @result = &check_existence($obj, [$line_in, $seek[0], $line_in, "", $line[0]], $line[1]);
            }
            &put_output($obj, \@result);
            shift(@line);
            shift(@seek);
            seek EXTRACTION_FILE, ($seek[1]), 0 or "$!($obj->{in_name})";
        }
        for (my $index=$#{$obj->{cond_buf}}; $index >= 0; $index--) {
            my @result = &get_existence_data($obj);
            &put_output($obj, \@result);
        }
        push(@{$output}, 'Data_Extraction_END');
    });
}
###################################################################################################
sub existence_watch {
    my ($obj, $cond_index, $input, $output) = @_;
    my $line_in  = 0;
    
    threads->new(sub {
        $obj->{cond_index} = $cond_index;
        $obj->{input}      = $input;
        $obj->{output}     = $output;
        while (1) {
            if ($#{$input} >= 1 and ($#{$input} > $obj->{seek_buf_max} or ${$input}[$#{$input}] eq 'Data_Extraction_END')) {
                my $input_data = shift(@{$input});
                $line_in++;
                if ($input_data =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                    my @result = &check_existence($obj, ["$1", "$2", "$line_in", "$4", "$5"], "${$input}[0]");
                    &put_output($obj, \@result);
                }
            }
            if (${$input}[0] eq 'Data_Extraction_END') {
                for (my $index=$#{$obj->{cond_buf}}; $index >= 0; $index--) {
                    my @result = &get_existence_data($obj);
                    &put_output($obj, \@result);
                }
                push(@{$output}, 'Data_Extraction_END');
                last;
            }
        }
    });
}
###################################################################################################
sub put_output {
    foreach (@{$_[1]}) {
        my $sleep_cnt = 0;
        $_[0]->{output_index}++;
        while ($#{$_[0]->{input}} >= ($_[0]->{seek_buf_max} + $pipe_buf_plus)) {
            $sleep_cnt++;
            if ($sleep_cnt > 10) {
                # ���o�͈͌��
                print STDERR "Following extraction takes time. Therefore the output to the pipe buffer is not done.\n";
                exit 99;
            }
            sleep 1;
        }
        push(@{$_[0]->{output}}, "${$_}[0],${$_}[1],$_[0]->{output_index},${$_}[3],${$_}[4]");
    }
}
###################################################################################################
sub extraction_result {
    my @return_data = ();
    
    foreach (@_) {
        if ($_ =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($4 ne 'DEL') {
                push(@return_data, $5);
            }
        }
    }
    return @return_data;
}
###################################################################################################
sub check_existence {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�f�[�^                                                                #
    # ���� �F ��^���o�i�s�E��E�u���b�N���o�j�A���[�U�[���o�i���[�U�[�֐��ďo���j            #
    # �ԋp �F ���o����                                                                        #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $input_data, $next_line_data) = @_;
    my ($index_org, $seek, $index_now, $out_kbn, $line_data) = @{$input_data};
    
    if ($line_data ne 'Data_Extraction_END') {
        # �폜�Ώۃ`�F�b�N
        if ($out_kbn eq 'DEL' or (&check_mid_data($obj, $index_org))) {return ()}
        # ���̓f�[�^��cond����p�Ƀo�b�t�@
        push(@{$obj->{cond_buf}}, $input_data);
        
        # �ŏI�s�w������s�ԍ��w��ɕϊ�
        if ($next_line_data eq 'Data_Extraction_END') {
            &get_cond_l_s($index_now, grep{${$_}[0] eq 'L' and ${$_}[2] eq 'E'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
            &get_cond_l_e($index_now, grep{${$_}[0] eq 'L' and ${$_}[3] eq 'E'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
        }
        # ���K�\���w������s�ԍ��w��ɕϊ�
        push(@{${$obj->{cond_data}}[$obj->{cond_index}]}, &get_cond_lr_s($index_now, $line_data, grep{${$_}[0] eq 'LR'}@{${$obj->{cond_data}}[$obj->{cond_index}]}));
        &get_cond_lr_e($index_now, grep{${$_}[0] eq 'r' and $line_data =~ /${$_}[3]/}@{${$obj->{cond_data}}[$obj->{cond_index}]});
        
        # ���o
        if ($#{$obj->{cond_buf}} > ${$obj->{cond_buf_max}}[$obj->{cond_index}]) {
            return (&get_existence_data($obj));
        } else {
            return ();
        }
    } else {
        # ���o
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
    
    # �폜�Ώۃ`�F�b�N
    if (&check_mid_data($obj, $buf_org)) {shift(@{$obj->{cond_buf}}); return ()}
    # ���̓f�[�^��seek�p�Ƀo�b�t�@
    push(@{$obj->{seek_buf}}, $input_data);
    if ($#{$obj->{seek_buf}} > $obj->{seek_buf_max}) {shift(@{$obj->{seek_buf}})}
    
    # ���[�U�[���o
    if (&put_mid_data($obj, $buf_org)) {shift(@{$obj->{cond_buf}}); return ()}
    my $extraction_data = &init_extraction_data("", "$buf_data") |
                          &get_cond_user($obj, "$buf_data", grep{${$_}[0] eq 'USER'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
    if (&change_Bto2($extraction_data) == 0) {
        if ($obj->{output_kbn} ne '' and ${$obj->{output}}[$#{$obj->{output}}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($1 eq $buf_org and $4 eq "USER") {shift(@{$obj->{cond_buf}}); return ()}
            if ($1 eq $buf_org and $4 eq "DEL") {return ()}
        }
        if ($buf_kbn eq "USER") {
            $obj->{output_index}++;
            push(@{$obj->{output}}, "$buf_org,$seek,$obj->{output_index},USER,$buf_data");
            shift(@{$obj->{cond_buf}});
            return ();
        }
    }
    
    # ��^���o
    if (&change_Bto2($extraction_data) !~ /^1/) {
        # �s���o�A�u���b�N���o
        $extraction_data = $extraction_data |
                           &get_cond_lc($buf_data,
                                        grep{(${$_}[0] eq "L" and ((${$_}[1] eq "" and ${$_}[2] ne "E" and ${$_}[2] <= $buf_now and (${$_}[3] eq "E" or $buf_now <= ${$_}[3]))
                                                                or (${$_}[1] ne "" and (${$_}[2] eq "E" or $buf_now < ${$_}[2] or (${$_}[3] ne "E" and ${$_}[3] < $buf_now))))
                                          or (${$_}[0] eq "r" and ((${$_}[1] eq "" and ${$_}[2] <= $buf_now)
                                                                or (${$_}[1] ne "" and $buf_now < ${$_}[2])))
                                          or (${$_}[0] eq "LR" and ${$_}[1] ne "" and ${$_}[8] eq "1" and ${$_}[9] <= $buf_now))}@{${$obj->{cond_data}}[$obj->{cond_index}]});
    }
    # �񒊏o
    if (&change_Bto2($extraction_data) !~ /^1/) {
        $extraction_data = $extraction_data | &get_cond_c($buf_data, grep{${$_}[0] eq 'C'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
        $extraction_data = $extraction_data | &get_cond_cr($buf_data, grep{${$_}[0] eq 'CR'}@{${$obj->{cond_data}}[$obj->{cond_index}]});
    }
    
    # cond�o�b�t�@����
    shift(@{$obj->{cond_buf}});
    
    if (&change_Bto2($extraction_data) > 0) {
        my $return_data = &get_out_data("$buf_data", &change_Bto2($extraction_data));
        return [$buf_org, $seek, "", "$buf_kbn", "$return_data"];
    } else {
        return ();
    }
}
###################################################################################################
sub put_mid_data {
    my ($obj, $buf_org) = @_;
    
    my $mid_flg = 0;
    for (my $index=0 ; $index <= $#{$obj->{mid}}; $index++) {
        if (${$obj->{mid}}[$index] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($1 eq $buf_org) {
                $obj->{output_index}++;
                push(@{$obj->{output}}, "$1,$2,$obj->{output_index},USER,$5");
                $mid_flg = 1;
            }
        }
    }
    return $mid_flg;
}
###################################################################################################
sub check_mid_data {
    my ($obj, $index_org) = @_;
    
    for (my $index=0 ; $index <= $#{$obj->{mid}}; $index++) {
        if (${$obj->{mid}}[$index] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            if ($1 eq $index_org and $4 eq 'DEL') {return 1}
        }
    }
    return 0;
}
###################################################################################################
#   ���� ���o�f�[�^���擾 ����                                                                    #
###################################################################################################
sub get_out_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �s�f�[�^                                                                #
    #      �F $_[1] = ���o�Ώۋ敪                                                            #
    # ���� �F ���o�Ώۋ敪���璊�o�f�[�^���擾                                                #
    # �ԋp �F ���o�f�[�^                                                                      #
    #-----------------------------------------------------------------------------------------#
    if ($_[1] =~ /^1/) {
        # �s���o
        return $_[0];
    } else {
        # �񒊏o
        my @col_data = &get_col_data("", "$_[0]"); unshift @col_data, '';
        my $out_data = "";
        for (my $index=1; $index <= $#col_data; $index++) {
            if ((substr $_[1], $index, 1) eq "1") {$out_data .= "$col_data[$index] "}
        }
        chop $out_data;
        return $out_data;
    }
}
###################################################################################################
#   ���� ���̓t�@�C���n�o�d�m ����                                                                #
###################################################################################################
sub in_file_open {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���̓t�@�C����                                                          #
    # ���� �F ���̓t�@�C���̃t�@�C���n�o�d�m                                                  #
    #-----------------------------------------------------------------------------------------#
    if (! open (EXTRACTION_FILE, "< $_[0]")) {
        # ���̓t�@�C��OPEN�G���[
        print STDERR "Input File($_[0]) cannot Open\n";
        exit 99;
    }
    #flock(EXTRACTION_FILE, 1);
}
###################################################################################################
#   ���� ���̓t�@�C���b�k�n�r�d ����                                                              #
###################################################################################################
sub in_file_close {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���̓t�@�C����                                                          #
    # ���� �F ���̓t�@�C���̃t�@�C���b�k�n�r�d                                                #
    #-----------------------------------------------------------------------------------------#
    if (! close (EXTRACTION_FILE)) {
        # ���̓t�@�C��CLOSE�G���[
        print STDERR "Input File($_[0]) cannot Close\n";
        exit 99;
    }
}
###################################################################################################
#   ���� �������s�ԍ��擾 ����                                                                    #
###################################################################################################
sub get_line_num {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    # ���� �F �������̍s�ԍ����擾                                                            #
    #-----------------------------------------------------------------------------------------#
    return ${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2];
}
###################################################################################################
#   ���� �s�ԍ��`�F�b�N ����                                                                      #
###################################################################################################
sub check_line_num {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �s�ԍ�                                                                  #
    # ���� �F �s�ԍ��̋L�q�`�F�b�N                                                            #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] !~ /^\d+$/ or $_[0] <= 0) {
        print STDERR "Line Number Error($_[0]), \n";
        exit 99;
    }
}
###################################################################################################
#   ���� �f�[�^�擾�敪�`�F�b�N ����                                                              #
###################################################################################################
sub check_data_acquisition_flag {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �f�[�^�擾�敪                                                          #
    # ���� �F �f�[�^�擾�敪�̋L�q�`�F�b�N                                                    #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] ne "org" and $_[0] ne "now") {
        print STDERR "Data Acquisition division Error($_[0]), \n";
        exit 99;
    }
}
###################################################################################################
#   ���� ���o�f�[�^���݃`�F�b�N ����                                                              #
###################################################################################################
sub check_existence_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�ԍ�                                                                  #
    # ���� �F �I�u�W�F�N�g�ɕۑ����Ă��钊�o�Ώۃf�[�^�Ɏw��s�����݂��邩�`�F�b�N            #
    #-----------------------------------------------------------------------------------------#
    foreach (@{$_[0]->{seek_buf}}) {
        if ($_[1] == ${$_}[2]) {return 1}
    }
    return 0;
}
###################################################################################################
#   ���� �P�O�i�����P�U�i���ϊ� ����                                                              #
###################################################################################################
sub change_10to16{
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �P�O�i���̕�����                                                        #
    # ���� �F �P�O�i���̕�������P�U�i���̕�����ɕϊ�                                        #
    #-----------------------------------------------------------------------------------------#
    if (((length $_[0]) % 2) == 0) {
        return pack("H*", "$_[0]");
    } else {
        return pack("H*", "0$_[0]");
    }
}
###################################################################################################
#   ���� �P�U�i�����P�O�i���ϊ� ����                                                              #
###################################################################################################
sub change_16to10{
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �P�U�i���̕�����                                                        #
    # ���� �F �P�U�i���̕�������P�O�i���̕�����ɕϊ�                                        #
    #-----------------------------------------------------------------------------------------#
    return unpack("H*", "$_[0]");
}
###################################################################################################
#   ���� �Q�i�����o�C�i���ϊ� ����                                                                #
###################################################################################################
sub change_2toB{
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �Q�i���̕�����                                                          #
    # ���� �F �Q�i���̕�������o�C�i��������ɕϊ�                                            #
    #-----------------------------------------------------------------------------------------#
    return pack("B*", "$_[0]");
}
###################################################################################################
#   ���� �o�C�i�����Q�i���ϊ� ����                                                                #
###################################################################################################
sub change_Bto2{
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �o�C�i��������                                                          #
    # ���� �F �o�C�i����������Q�i���̕�����ɕϊ�                                            #
    #-----------------------------------------------------------------------------------------#
    return unpack("B*", "$_[0]");
}
###################################################################################################
#   ���� �o�b�t�@�G���[ ����                                                                      #
###################################################################################################
sub error_buffers {
    # �o�b�t�@�ɊY���f�[�^����
    print STDERR "Buffers does not have Line Number Pertinence Data(line($_[0])-\>seek($_[1]))\n";
    exit 99;
}
###################################################################################################
#   ���� ���o�Ώۃf�[�^�擾�ʒu�w�� ����                                                          #
###################################################################################################
sub seek_line {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�ԍ�                                                                  #
    # ���� �F �s�ԍ��`�F�b�N�A���o�Ώۃf�[�^�̓Ǎ��ވʒu���w��s�ֈړ�                        #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $number) = @_;
    &check_line_num("$number");
    if ($obj->{output_kbn} ne '') {$obj->{output_kbn} = 'seek'}
    
    if ($number <= ${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[2]) {
        for (my $index=0; $index <= $#{$obj->{seek_buf}}; $index++) {
            if ($number == ${${$obj->{seek_buf}}[$index]}[2]) {
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$index]}[1]), 0 or "$!($obj->{in_name})";
                }
                @{$obj->{seek_num}}[0..2] = (${${$obj->{seek_buf}}[$index]}[0], ${${$obj->{seek_buf}}[$index]}[1], $number);
                $obj->{seek_kbn}          = 'seek';
                $obj->{seek_index}        = $index;
                @{$obj->{get_num}}        = @{$obj->{seek_num}};
                $obj->{get_kbn}           = $obj->{seek_kbn};
                $obj->{get_index}         = $obj->{seek_index};
                return ${${$obj->{seek_buf}}[$index]}[1];
            }
        }
        &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
    } else {
        if ($obj->{cond_index} > 0) {
            for (my $index=0; $index <= $#{$obj->{cond_buf}}; $index++) {
                if (${${$obj->{cond_buf}}[$index]}[4] eq 'Data_Extraction_END') {
                    &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
                }
                if ($number == ${${$obj->{cond_buf}}[$index]}[2]) {
                    if ($obj->{in_kbn} ne '') {
                        seek EXTRACTION_FILE, (${${$obj->{cond_buf}}[$index]}[1]), 0 or "$!($obj->{in_name})";
                    }
                    @{$obj->{seek_num}}[0..2] = (${${$obj->{cond_buf}}[$index]}[0], ${${$obj->{cond_buf}}[$index]}[1], $number);
                    $obj->{seek_kbn}          = 'cond';
                    $obj->{seek_index}        = $index;
                    @{$obj->{get_num}}        = @{$obj->{seek_num}};
                    $obj->{get_kbn}           = $obj->{seek_kbn};
                    $obj->{get_index}         = $obj->{seek_index};
                    return ${${$obj->{cond_buf}}[$index]}[1];
                }
            }
            while (1) {
                my $for_max = $#{$obj->{input}} - $obj->{seek_buf_max};
                if ($obj->{seek_buf_max} > 0 and ${$obj->{input}}[$#{$obj->{input}}] eq 'Data_Extraction_END') {
                    $for_max = $#{$obj->{input}};
                }
                for (my $index=0; $index <= $for_max; $index++) {
                    if (${$obj->{input}}[$index] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                        if ($number == $3) {
                            if ($obj->{in_kbn} ne '') {
                                seek EXTRACTION_FILE, ($2), 0 or "$!($obj->{in_name})";
                            }
                            @{$obj->{seek_num}}[0..2] = ($1, $2, $number);
                            $obj->{seek_kbn}          = 'input';
                            $obj->{seek_index}        = $index;
                            @{$obj->{get_num}}        = @{$obj->{seek_num}};
                            $obj->{get_kbn}           = $obj->{seek_kbn};
                            $obj->{get_index}         = $obj->{seek_index};
                            return $2;
                        }
                    }
                    if ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus) or ${$obj->{input}}[$index] eq 'Data_Extraction_END') {
                        &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
                    }
                }
                sleep 1;
            }
        } else {
            if ($obj->{in_kbn} ne '') {
                seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1]), 0 or "$!($obj->{in_name})";
            }
            my $index = ${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[2];
            my $line = &get_line_data($obj, $index);
            while ($line ne 'Data_Extraction_END') {
                $index++;
                if ($number == $index) {
                    @{$obj->{seek_num}}[0..2] = ($index, (tell EXTRACTION_FILE), $number);
                    $obj->{seek_kbn}          = 'org';
                    $obj->{seek_index}        = 0;
                    @{$obj->{get_num}}        = @{$obj->{seek_num}};
                    $obj->{get_kbn}           = $obj->{seek_kbn};
                    $obj->{get_index}         = $obj->{seek_index};
                    return (tell EXTRACTION_FILE);
                }
                $line = &get_line_data($obj, $index);
            }
            &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],$number);
        }
    }
}
###################################################################################################
#   ���� ���o�Ώۃf�[�^�擾 ����                                                                  #
###################################################################################################
sub get_line {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �f�[�^�擾�敪�iorg�F�I���W�i���^now�F���o���ʁj                        #
    # ���� �F �f�[�^�擾�敪�`�F�b�N�A���o�Ώۃf�[�^�̎擾                                    #
    # �ԋp �F ���o�Ώۃf�[�^                                                                  #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $flg) = @_;
    my $line = "";
    &check_data_acquisition_flag("$flg");
    
    if ($flg eq "org" or $obj->{seek_kbn} eq "org") {
        # �I���W�i��
        @{$obj->{get_num}} = @{$obj->{seek_num}};
        if ($_[0]->{in_kbn} eq "") {
            $line = &get_line_data($obj, (${$obj->{seek_num}}[2] - 1));
        } else {
            $line = &get_line_data($obj);
        }
        $obj->{get_kbn}    = $obj->{seek_kbn};
        ${$obj->{seek_num}}[0]++;
    } else {
        # ���o����
        if ($obj->{seek_kbn} eq 'seek') {
            ${$obj->{seek_num}}[0] = ${${$obj->{seek_buf}}[$obj->{seek_index}]}[0];
            ${$obj->{seek_num}}[1] = ${${$obj->{seek_buf}}[$obj->{seek_index}]}[1];
            $line = ${${$obj->{seek_buf}}[$obj->{seek_index}]}[4];
        } elsif ($obj->{seek_kbn} eq 'cond') {
            ${$obj->{seek_num}}[0]  = ${${$obj->{cond_buf}}[$obj->{seek_index}]}[0];
            ${$obj->{seek_num}}[1]  = ${${$obj->{cond_buf}}[$obj->{seek_index}]}[1];
            $line = ${${$obj->{cond_buf}}[$obj->{seek_index}]}[4];
        } else {
            while (($#{$obj->{input}} - $obj->{seek_buf_max}) < $obj->{seek_index}) {
                if ($#{$obj->{input}} >= $obj->{seek_index} and ${$obj->{input}}[$#{$obj->{input}}] eq 'Data_Extraction_END') {
                    last;
                }
                if ($#{$obj->{input}} >= ($obj->{seek_buf_max} + $pipe_buf_plus)) {
                    &error_buffers(${${$_[0]->{seek_buf}}[$#{$_[0]->{seek_buf}}]}[2],${$obj->{seek_num}}[2]);
                }
                sleep 1;
            }
            if (${$obj->{input}}[$obj->{seek_index}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                ${$obj->{seek_num}}[0] = $1;
                ${$obj->{seek_num}}[1] = $2;
                $line = $5;
            }
        }
        
        @{$obj->{get_num}} = @{$obj->{seek_num}};
        $obj->{get_kbn}    = $obj->{seek_kbn};
        $obj->{get_index}  = $obj->{seek_index};
        $obj->{seek_index}++;
        if ($obj->{seek_kbn} eq 'seek' and $#{$obj->{seek_buf}} < $obj->{seek_index}) {
            $obj->{seek_kbn}   = 'cond';
            $obj->{seek_index} = 1;
        }
        if ($obj->{seek_kbn} eq 'cond' and $#{$obj->{cond_buf}} < $obj->{seek_index}) {
            if ($obj->{cond_index} > 0) {
                $obj->{seek_kbn}   = 'input';
                $obj->{seek_index} = 0;
            } else {
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${$obj->{seek_num}}[1]), 0 or "$!($obj->{in_name})";
                }
                my $line = &get_line_data($obj, ${$obj->{seek_num}}[0]);
                $obj->{seek_kbn}   = 'org';
                $obj->{seek_index} = 0;
                ${$obj->{seek_num}}[0]++;
            }
        }
    }
    if ($obj->{seek_kbn} ne 'org') {${$obj->{seek_num}}[2]++}
    return $line;
}
###################################################################################################
sub get_line_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�J�E���^                                                              #
    #-----------------------------------------------------------------------------------------#
    my $line = '';
    
    # �I���W�i��
    if ($_[0]->{in_kbn} eq "") {
        # �ϐ��w��
        my $check = '^';
        for (my $index=1; $index <= $_[1]; $index++) {
            $check .= '.*\n';
        }
        $check .= '(.*\n{0,1})';
        if ((eval($_[0]->{in_name})) =~ /$check/) {
            $line = $1;
        }
    } else {
        # �t�@�C���w��
        $line = <EXTRACTION_FILE>;
    }
    if ($line eq '') {
        $line = 'Data_Extraction_END';
    } else {
        $_[0]->cut_last_0a($line);
    }
    ${$_[0]->{seek_num}}[2]++;
    return $line;
}
###################################################################################################
#   ���� ���o�敪������ ����                                                                      #
###################################################################################################
sub init_extraction_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�f�[�^                                                                #
    # ���� �F �s�f�[�^����؂蕶���ŕ���                                                      #
    # �ԋp �F �z�񉻂����s�f�[�^                                                              #
    #-----------------------------------------------------------------------------------------#
    my $extraction_data = "0" x (&get_col_data("", "$_[1]") + 1);
    return &change_2toB($extraction_data);
}
###################################################################################################
#   ���� �s�f�[�^�z��ϊ� ����                                                                    #
###################################################################################################
sub get_col_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�f�[�^                                                                #
    # ���� �F �s�f�[�^����؂蕶���ŕ���                                                      #
    # �ԋp �F �z�񉻂����s�f�[�^                                                              #
    #-----------------------------------------------------------------------------------------#
    return (split /\s+\,*\s*|\,+\s*/, $_[1]);
}
###################################################################################################
#   ���� ���o�f�[�^�ǉ��E�X�V ����                                                                #
###################################################################################################
sub add_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�f�[�^                                                                #
    # ���� �F �s�f�[�^�𒊏o�f�[�^�̃J�����g�s�iseek���Ă���ꍇ�́A���̍s�j�ɒǉ��E�X�V      #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $line_data) = @_;
    
    if ($obj->{get_kbn} eq 'seek') {
        if ($obj->{get_index} == $#{$obj->{seek_buf}}) {
            $obj->{output_index}++;
            push(@{$obj->{output}}, "${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[0],${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1],$obj->{output_index},USER,$line_data");
            $obj->{output_kbn} = 'output';
        } else {
            for (my $index=0 ; $index <= $#{$obj->{output}} ; $index++) {
                if (${$obj->{output}}[($#{$obj->{output}} - $index)] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                    if ($1 eq ${$obj->{get_num}}[0]) {
                        if ($obj->{output_kbn} eq '') {
                            my @temp = @{$obj->{output}};
                            splice(@temp, ($#{$obj->{output}} - $index), 1, ("$1,$2,$3,USER,$line_data"));
                            @{$obj->{output}} = @temp;
                        } elsif ($index > 0) {
                            $obj->{output_index}++;
                            my @temp = @{$obj->{output}};
                            splice(@temp, ($#{$obj->{output}} - $index + 1), 0, ("$1,$2,$obj->{output_index},USER,$line_data"));
                            @{$obj->{output}} = @temp;
                        } else {
                            $obj->{output_index}++;
                            push(@{$obj->{output}}, "$1,$2,$obj->{output_index},USER,$line_data");
                        }
                        $obj->{output_kbn} = 'output';
                        last;
                    }
                }
            }
        }
    } elsif ($obj->{get_kbn} eq 'cond') {
        push(@{$obj->{mid}}, "${${$obj->{cond_buf}}[$obj->{get_index}]}[0],${${$obj->{cond_buf}}[$obj->{get_index}]}[1],${${$obj->{cond_buf}}[$obj->{get_index}]}[2],USER,$line_data");
    } elsif ($obj->{get_kbn} eq 'input') {
        if (${$obj->{input}}[$obj->{get_index}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            push(@{$obj->{mid}}, "$1,$2,$3,USER,$line_data");
        }
    } else {
        if ($obj->{in_kbn} eq '') {
            push(@{$obj->{mid}}, "${$obj->{get_num}}[0],,${$obj->{get_num}}[2],USER,$line_data");
        } else {
            push(@{$obj->{mid}}, "${$obj->{get_num}}[0],${$obj->{get_num}}[1],${$obj->{get_num}}[2],USER,$line_data");
        }
    }
}
###################################################################################################
#   ���� ���o�f�[�^�폜 ����                                                                      #
###################################################################################################
sub del_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    # ���� �F ���o�f�[�^����J�����g�s�iseek���Ă���ꍇ�́A���̍s�j���폜                    #
    #-----------------------------------------------------------------------------------------#
    my ($obj, $line_data) = @_;
    
    if ($obj->{get_kbn} eq 'seek') {
        if ($obj->{get_index} < $#{$obj->{seek_buf}}) {
            my $del_flg = '';
            for (my $index=0 ; $index <= $#{$obj->{output}} ; $index++) {
                if (${$obj->{output}}[($#{$obj->{output}} - $index)] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
                    if ($1 eq ${$obj->{get_num}}[0]) {
                        if ($4 eq '' or $index == $#{$obj->{output}}) {
                            my @temp = @{$obj->{output}};
                            splice(@temp, ($#{$obj->{output}} - $index), 1);
                            @{$obj->{output}} = @temp;
                            last;
                        } else {
                            $del_flg = '1';
                        }
                    } elsif ($del_flg = '1') {
                        my @temp = @{$obj->{output}};
                        splice(@temp, ($#{$obj->{output}} - $index + 1), 1);
                        @{$obj->{output}} = @temp;
                        last;
                    }
                }
            }
        } else {
            push(@{$obj->{output}}, "${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[0],,,DEL,");
            shift(@{$obj->{cond_buf}});
        }
        $obj->{output_kbn} = 'output';
        splice(@{$obj->{seek_buf}}, $obj->{get_index}, 1);
    } elsif ($obj->{get_kbn} eq 'cond') {
        push(@{$obj->{mid}}, "${${$obj->{cond_buf}}[$obj->{get_index}]}[0],,,DEL,");
        splice(@{$obj->{cond_buf}}, $obj->{get_index}, 1);
    } elsif ($obj->{get_kbn} eq 'input') {
        if (${$obj->{input}}[$obj->{get_index}] =~ /^(\d*),{1}(\d*),{1}(\d*),{1}(\w*),{1}(.*)/) {
            push(@{$obj->{mid}}, "$1,,,DEL,");
        }
        splice(@{$obj->{input}}, $obj->{get_index}, 1);
    } else {
        push(@{$obj->{mid}}, "${$obj->{get_num}}[0],,,DEL,");
    }
}
###################################################################################################
#   ���� �s�����s�R�[�h�폜 ����                                                                  #
###################################################################################################
sub cut_last_0a{
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #         $_[1] = �s�f�[�^                                                                #
    # ���� �F �s���̉��s�R�[�h���폜                                                          #
    # �ԋp �F �s�f�[�^                                                                        #
    #-----------------------------------------------------------------------------------------#
    if ((substr $_[1], -1) eq "\n") {
        chop $_[1];
    }
}
###################################################################################################
#   ���� ���K�\���w��ɂ��s���o�̋N�_�s���o ����                                                #
###################################################################################################
sub get_cond_lr_s {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�ԍ�                                                                 #
    #      �F $_[1]  = �s�f�[�^                                                               #
    #      �F $_[2�`]= ���o�����i���K�\���ɂ��s���o�j                                       #
    # ���� �F �͈͎w��Ȃ��j�s�ԍ��w��i���o�敪��"L"�j�ɕϊ�                                 #
    #         �͈͎w�肠��j�N�_���s�ԍ��w��i���o�敪��"r"�j�ɕϊ�                           #
    # �ԋp �F �N�_���s�ԍ��w��ɕϊ��������o����                                              #
    #-----------------------------------------------------------------------------------------#
    my $line_now  = shift;
    my $line_data = shift;
    my @add_cond  = ();
    
    # ���K�\���w����s�ԍ��w��ɕϊ��i�N�_�s�j
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
    # ���o����ԋp
    return @add_cond;
}
###################################################################################################
#   ���� ���K�\���w��ɂ��s���o�͈͍̔s���o ����                                                #
###################################################################################################
sub get_cond_lr_e {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�ԍ�                                                                 #
    #      �F $_[1�`]= ���o����                                                               #
    # ���� �F ���K�\���i�͈́j���s�ԍ��w��ɕϊ�                                              #
    #-----------------------------------------------------------------------------------------#
    my $line_now  = shift;
    
    # ���K�\���w����s�ԍ��w��ɕϊ��i�͈͍s�j
    foreach (@_) {
        ${$_}[0] = 'L';
        ${$_}[3] = $line_now;
    }
}
###################################################################################################
#   ���� �ŏI�s�w��ɂ��s���o�̋N�_�s���o ����                                                  #
###################################################################################################
sub get_cond_l_s {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�ԍ�                                                                 #
    #      �F $_[1�`]= ���o�����i�ŏI�s�w��"E"�ɂ��s���o�j                                  #
    # ���� �F �ŏI�s�w����s�ԍ��w��ɕϊ�                                                    #
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
#   ���� �ŏI�s�w��ɂ��s���o�͈͍̔s���o ����                                                  #
###################################################################################################
sub get_cond_l_e {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�ԍ�                                                                 #
    #      �F $_[1�`]= ���o�����i�ŏI�s�w��"E"�ɂ��s���o�j                                  #
    # ���� �F �ŏI�s�w����s�ԍ��w��ɕϊ�                                                    #
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
#   ���� ���[�U�[���o ����                                                                        #
###################################################################################################
sub get_cond_user {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    #      �F $_[1]  = ���̓f�[�^                                                             #
    #      �F $_[1�`]= ���[�U�[����                                                           #
    # ���� �F ���[�U�[�֐��̌ďo��                                                            #
    # �ԋp �F ���[�U�[�֐����ԋp�������o�Ώۋ敪                                              #
    #-----------------------------------------------------------------------------------------#
    my $obj             = shift;
    my $line_data       = shift;
    my $extraction_data = '';
    $obj->{output_kbn}  = '';
    
    foreach (@_) {
        # ���[�U�[�֐��̌ďo��
        @{$obj->{seek_num}}[0..2] = @{${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]};
        $obj->{seek_index}        = $#{$obj->{seek_buf}};
        $obj->{seek_kbn}          = 'seek';
        @{$obj->{get_num}}        = @{$obj->{seek_num}};
        $obj->{get_kbn}           = $obj->{seek_kbn};
        $obj->{get_index}         = $obj->{seek_index};
        seek EXTRACTION_FILE, (${${$obj->{seek_buf}}[$#{$obj->{seek_buf}}]}[1]), 0 or "$!($obj->{in_name})";
        my $user_sub = '&'.${$_}[1].'('."\"$line_data\"";
        for (my $index1=2 ; $index1 <= $#{$_}; $index1++) {
            $user_sub .= ', "'.${$_}[$index1].'"';
        }
        $user_sub .= ');';
        $extraction_data = $extraction_data | eval($user_sub);
    }
    return &change_2toB("$extraction_data");
}
###################################################################################################
#   ���� �s�E�u���b�N���o ����                                                                    #
###################################################################################################
sub get_cond_lc {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�f�[�^                                                               #
    #      �F $_[1�`]= ���o�����i�����s�̍s�E�u���b�N���o�j                                   #
    # ���� �F �s���o�A�񒊏o�i��ԍ��w��ɂ��񒊏o�A���K�\���w��ɂ��񒊏o�j              #
    # �ԋp �F ���o�Ώۋ敪                                                                    #
    #-----------------------------------------------------------------------------------------#
    my $line_data = shift;
    
    if ((grep{${$_}[4] eq ''}@_) > 0) {
        # �s���o
        return &change_2toB("1");
    } else {
        # �񒊏o
        my $extraction_data = &get_cond_c($line_data, grep{${$_}[4] eq 'C'}@_);
        $extraction_data = $extraction_data | &get_cond_cr($line_data, grep{${$_}[4] eq 'CR'}@_);
        return $extraction_data;
    }
}
###################################################################################################
#   ���� ��ԍ��w��ɂ��񒊏o ����                                                              #
###################################################################################################
sub get_cond_c {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�f�[�^                                                               #
    #      �F $_[1�`]= ���o�����i��ԍ��ɂ��񒊏o�j                                         #
    # ���� �F ��ԍ��w��ɂ��񒊏o                                                          #
    # �ԋp �F ���o�Ώۋ敪                                                                    #
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
        # ���o����Ώۂ��`�F�b�N
        if (${$_}[0] eq 'C') {
            $col_add = 0;
        } else {
            $col_add = 4;
        }
        # �N�_��ݒ�
        if (${$_}[2] eq 'E' or ${$_}[2] eq 'e') {
            $col_start = $col_su;
        } else {
            $col_start = ${$_}[(2 + $col_add)];
        }
        # �͈͂��Z�o
        if (${$_}[(3 + $col_add)] eq '') {
            # �͈͂Ȃ�
            $col_end = $col_start;
        } elsif (${$_}[(3 + $col_add)] eq 'E' or ${$_}[(3 + $col_add)] eq 'e') {
            # �ŏI��܂�
            if ($col_start <= $col_su) {
                $col_end = $col_su;
            } else {
                $col_end = $col_start;
            }
        } elsif (${$_}[(3 + $col_add)] =~ /^\-(\d+)$/) {
            # �|����܂�
            $col_end   = $col_start;
            $col_start = $col_start + ${$_}[(3 + $col_add)];
        } elsif (${$_}[(3 + $col_add)] =~ /^\+(\d+)$/) {
            # �{����܂�
            $col_end   = $col_start + ${$_}[(3 + $col_add)];
        } elsif (${$_}[(2 + $col_add)] <= ${$_}[(3 + $col_add)]) {
            # �㑱�w���܂�
            $col_end   = ${$_}[(3 + $col_add)];
        } else {
            # ��s�w���܂�
            $col_end   = $col_start;
            $col_start = ${$_}[(3 + $col_add)];
        }
        if ($col_start < 0) {$col_start = 0}
        if ($col_end   < 0) {$col_end   = 0}
        # ���o�Ώۗ��ݒ�
        for (my $index2=1; $index2 <= $col_su; $index2++) {
            if ((${$_}[(1 + $col_add)] eq '' and $index2 >= $col_start and $index2 <= $col_end) or (${$_}[(1 + $col_add)] ne '' and ($index2 < $col_start or $index2 > $col_end))) {
                substr($extraction_data, $index2, 1) = "1";
            }
        }
    }
    return &change_2toB("$extraction_data");
}
###################################################################################################
#   ���� ���K�\���w��ɂ��񒊏o ����                                                            #
###################################################################################################
sub get_cond_cr {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�f�[�^                                                               #
    #      �F $_[1�`]= ���o�����i���K�\���ɂ��񒊏o�j                                       #
    # ���� �F ���K�\���w��ɂ��񒊏o                                                        #
    # �ԋp �F ���o�Ώۋ敪                                                                    #
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
        # ���o����Ώۂ��`�F�b�N
        if (${$_}[0] eq 'CR') {
            $col_add = 0;
        } else {
            $col_add = 4;
        }
        # ���K�\����␳
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
            # ���o�͈͂��Z�o
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
                # �͈͂Ȃ�
                $col_end = $col_end2;
            } elsif (${$_}[(3 + $col_add)] =~ /^\+(\d+)$/) {
                # �{����܂�
                $col_end = $col_end2 + ${$_}[(3 + $col_add)];
          } elsif (${$_}[(3 + $col_add)] =~ /^-(\d+)$/) {
                # �|����܂�
                $col_start = $col_start + ${$_}[(3 + $col_add)];
                $col_end   = $col_end2;
            } else {
                # ���K�\���̗�܂�
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
        # ���o�Ώۗ��ݒ�
        for (my $index2=1; $index2 <= $col_su; $index2++) {
            if ((${$_}[(1 + $col_add)] eq '' and $cond_c_new[$index2] eq '1') or (${$_}[(1 + $col_add)] ne '' and $cond_c_new[$index2] eq '')) {
                substr($extraction_data, $index2, 1) = "1";
            }
        }
    }
    return &change_2toB("$extraction_data");
}
1;
