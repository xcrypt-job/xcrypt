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
    # ���͏��
    my @in_data       = ();
    my @in_index      = ();
    # ���o�������
    my @cond_data     = ();
    my $cond_index    = -1;
    my @cond_max      = ();
    my $next_index    = 0;
    # seek���
    my @seek_data     = ();
    my $seek_max      = 0;
    my $seek_kbn      = '';
    my $seek_index    = 0;
    my @seek_num      = ();
    my $get_kbn       = '';
    my $get_index     = 0;
    my @get_num       = ();
    # pipe���
    my @pipe_data     = ();
    # �o�͏��
    my @mid_data      = ();
    my $out_kbn       = '';
    my @out_index     = ();
    
    # ���̓f�[�^�`�F�b�N
    @in_data = &check_in_data($_[0]);
    # ���[�Useek�o�b�t�@���`�F�b�N
    $seek_max = &check_seek_max($_[1]);
    
    # �I�u�W�F�N�g��`
    my $Job = {
             # ���͏��
               "in_kbn"        =>$in_data[0],                 # ���͋敪�i�t�@�C��or�ϐ��j
               "in_name"       =>$in_data[1],                 # ���̓f�[�^���i�t�@�C����or�ϐ����j
               "in_index"      =>\@in_index,                  # ���̓f�[�^index
             # ���o�������
               "cond_data"     =>\@cond_data,                 # ���o����
               "cond_index"    =>$cond_index,                 # ���o����index
               "cond_max"      =>\@cond_max,                  # ���o�o�b�t�@��
               "next_index"    =>$next_index,                 # next���o����index
             # seek���
               "seek_data"     =>\@seek_data,                 # seek�o�b�t�@
               "seek_max"      =>$seek_max,                   # seek�o�b�t�@��
               "seek_kbn"      =>$seek_kbn,                   # seek�敪�iseek/cond/input/org�j
               "seek_index"    =>$seek_index,                 # seek�o�b�t�@index�i�o�b�t�@�̔z��index�j
               "seek_num"      =>\@seek_num,                  # seek�s���i�I���W�i���s�ԍ��A�o�C�g�ʒu�A���͍s�ԍ��j
               "get_kbn"       =>$get_kbn,                    # get�敪�iseek/cond/input/org�j
               "get_index"     =>$get_index,                  # get�o�b�t�@index�i�o�b�t�@�̔z��index�j
               "get_num"       =>\@get_num,                   # get�s���i�I���W�i���s�ԍ��A�o�C�g�ʒu�A���͍s�ԍ��j
             # pipe���
               "pipe_data"     =>\@pipe_data,                 # pipe�f�[�^
             # �o�͏��
               "mid_data"      =>\@mid_data,                  # ���[�U���o�f�[�^�i��ǂݕ����j
               "out_kbn"       =>$out_kbn,                    # �o�͋敪
               "out_index"     =>\@out_index};                # �o�̓f�[�^index
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
    if ($_[0] eq '') {
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
    #     ���K�\���w��F[!]LR/���o����[/[�͈�][/�񒊏o]]                                      #
    #     �������ȊO�̒��o�́A�擪��"!"��t�^                                                 #
    #   �񒊏o                                                                                #
    #     ��ԍ��w��  �F[!]C/��ԍ�[/�͈�]                                                    #
    #     ���K�\���w��F[!]CR/���o����[/�͈�]                                                 #
    #     �������ȊO�̒��o�́A�擪��"!"��t�^                                                 #
    #   ���[�U�[���o  �F�m"�p�b�P�[�W��::�T�u���[�`����"[, "���[�U�[���o����", ��� ]�n        #
    #                   ����O�́m�n�́A�z���`���Ӗ�����                                    #
    #-----------------------------------------------------------------------------------------#
    my $cond_max = -1;
    
    # ���o�����`�F�b�N
    my @cond_data = &check_extraction_cond(@_);
    foreach (grep{${$_}[0] =~ 'L' and ${$_}[3] =~ /^-\d+$/}@cond_data) {
         if ($cond_max > ${$_}[3]) {
             $cond_max = ${$_}[3];
         }
    }
    
    # ���o�����ݒ�
    push(@{$_[0]->{cond_data}}, [@cond_data]);
    push(@{$_[0]->{cond_max}} , ($cond_max * -1));
    push(@{$_[0]->{pipe_data}}, []);
    push(@{$_[0]->{seek_data}}, []);
    push(@{$_[0]->{mid_data}} , []);
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
            if ($in_kbn[1] eq 'LR' and $in_kbn[0] ne '') {
                $in_kbn[4] = '0';
            } else {
                $in_kbn[4] = '';
            }
            
            if ($in_cond[3] eq '') {
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
                push(@cond_data, ['USER', @in_cond_user]);
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
    my $obj         = shift;
    my $seek_byte   = 0;
    my $read_index  = 0;
    push(@{$obj->{pipe_data}}, []);
    my $return_data = \@{${$obj->{pipe_data}}[$#{$obj->{pipe_data}}]};
    
    # �t�@�C��OPEN
    if ($obj->{in_kbn} eq 'file') {
        &in_file_open($obj->{in_name});
    }
    while (1) {
        my $cond_index = $obj->{cond_index};
        my $next_index = $obj->{cond_index} + 1;
        my $in_data    = \@{${$obj->{pipe_data}}[$obj->{cond_index}]};
        my $out_data   = \@{${$obj->{pipe_data}}[$next_index]};
        if ($obj->{cond_index} < 0) {
            # �f�[�^�擾
            &existence_init($obj, \$seek_byte, \$read_index);
        } else {
            # ���o
            &existence_watch($obj);
        }
        # �SED���o�������`�F�b�N
        if ($#{$return_data} >= 0 and ${$return_data}[$#{$return_data}] eq 'Data_Extraction_END') {
            last;
        }
        # �㑱ED���o�\���`�F�b�N
        if ($obj->{cond_index} < $#{$obj->{cond_data}} and
           (($obj->{cond_index} < 0                               and $#{$out_data} > ${$obj->{cond_max}}[$next_index]) or
            ($obj->{seek_max} >= ${$obj->{cond_max}}[$next_index] and $#{$out_data} > ($obj->{seek_max} * 2)) or
            ($obj->{seek_max} < ${$obj->{cond_max}}[$next_index]  and $#{$out_data} > ($obj->{seek_max} + ${$obj->{cond_max}}[$next_index])) or
            ($#{$out_data} >= 0 and ${$out_data}[$#{$out_data}] eq 'Data_Extraction_END'))) {
            $obj->{cond_index}++;
            next;
        }
        # ��sED���o�ɖ߂�ׂ����`�F�b�N
        while ($obj->{cond_index} >= 0 and
           ($#{$in_data} == -1 or
           (${$in_data}[$#{$in_data}] ne 'Data_Extraction_END' and
           (($obj->{cond_index} == 0                                      and $#{$in_data} <= ${$obj->{cond_max}}[$obj->{cond_index}]) or
            ($obj->{seek_max} >= ${$obj->{cond_max}}[$obj->{cond_index}] and $#{$in_data} <= ($obj->{seek_max} * 2)) or
            ($obj->{seek_max} < ${$obj->{cond_max}}[$obj->{cond_index}]  and $#{$in_data} <= ($obj->{seek_max} + ${$obj->{cond_max}}[$obj->{cond_index}])))))) {
            $obj->{cond_index}--;
        }
    }
    # �t�@�C��CLOSE
    if ($obj->{in_kbn} eq 'file') {
        &in_file_close($obj->{in_name});
    }
    
    # ���o���ʕԋp
    return &extraction_result(@{$return_data});
}
###################################################################################################
sub existence_init {
    my ($obj, $seek_byte, $read_index) = @_;
    
    seek EXTRACTION_FILE, (${$seek_byte}), 0 or "$!($obj->{in_name})";
    my $line = &get_line_data($obj, ${$read_index});
    if ($line ne 'Data_Extraction_END') {
        ${$read_index}++;
        if ($obj->{in_kbn} ne '') {
            push(@{${$obj->{pipe_data}}[0]}, ["${$read_index}", "${$seek_byte}", "${$read_index}", '', "$line"]);
            ${$seek_byte} = (tell EXTRACTION_FILE);
        } else {
            push(@{${$obj->{pipe_data}}[0]}, ["${$read_index}", '', "${$read_index}", '', "$line"]);
        }
    } else {
        push(@{${$obj->{pipe_data}}[0]}, 'Data_Extraction_END');
    }
}
###################################################################################################
sub existence_watch {
    my ($obj) = @_;
    
    my $input_data = shift(@{${$obj->{pipe_data}}[$obj->{cond_index}]});
    if ($input_data ne 'Data_Extraction_END') {
        if (${$input_data}[3] ne 'DEL') {
            ${$obj->{in_index}}[$obj->{cond_index}]++;
            ${$input_data}[2] = ${$obj->{in_index}}[$obj->{cond_index}];
            &check_existence($obj, \@{$input_data});
        }
    } else {
        push(@{${$obj->{pipe_data}}[($obj->{cond_index} + 1)]}, 'Data_Extraction_END');
    }
}
###################################################################################################
sub extraction_result {
    my @return_data = ();
    
    foreach (@_) {
        if ($_ ne 'Data_Extraction_END' and ${$_}[3] ne 'DEL') {
            push(@return_data, "${$_}[4]");
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
    my ($obj, $input_data) = @_;
    my ($index_org, $seek_byte, $index_now, $out_kbn, $in_line) = @{$input_data};
    my $cond_index = $obj->{cond_index};
    my $cond_data  = \@{${$obj->{cond_data}}[$cond_index]};
    my $seek_data  = \@{${$obj->{seek_data}}[$cond_index]};
    my $out_index  = \${$obj->{out_index}}[$cond_index];
    my $out_data   = \@{${$obj->{pipe_data}}[($cond_index + 1)]};
    
    # �폜�Ώۃ`�F�b�N
    if ($out_kbn eq 'DEL') {return ()}
    
    # �ŏI�s�w������s�ԍ��w��ɕϊ�
    if (${${$obj->{pipe_data}}[$cond_index]}[${$obj->{cond_max}}[$cond_index]] eq 'Data_Extraction_END') {
        &get_cond_l_s($index_now, grep{${$_}[0] eq 'L' and ${$_}[2] eq 'E'}@{$cond_data});
        &get_cond_l_e($index_now, grep{${$_}[0] eq 'L' and ${$_}[3] eq 'E'}@{$cond_data});
    }
    # ���K�\���w������s�ԍ��w��ɕϊ�
    push(@{$cond_data}, &get_cond_lr_s($obj, $index_now, $in_line, grep{${$_}[0] eq 'LR'}@{$cond_data}));
    &get_cond_lr_e($index_now, grep{${$_}[0] eq 'r' and $in_line =~ /${$_}[3]/}@{$cond_data});
    
    # ���̓f�[�^��seek�p�Ƀo�b�t�@
    push(@{$seek_data}, $input_data);
    if ($#{$seek_data} > $obj->{seek_max}) {shift(@{$seek_data})}
    
    # ���[�U���o
    if (&check_mid_data($obj, $index_now)) {return ()}
    if (&put_mid_data($obj, $index_now)) {return ()}
    my $extraction_data = &init_extraction_data('', "$in_line") |
                          &get_cond_user($obj, "$in_line", grep{${$_}[0] eq 'USER'}@{$cond_data});
    if (&change_Bto2($extraction_data) == 0) {
        # ���[�U�o�͗L���`�F�b�N
        if ($obj->{out_kbn} ne '' and
            ${${$out_data}[$#{$out_data}]}[0] eq $index_org and
           (${${$out_data}[$#{$out_data}]}[3] eq 'USER' or ${${$out_data}[$#{$out_data}]}[3] eq 'DEL')) {
            if (${${$out_data}[$#{$out_data}]}[3] eq 'DEL') {
                pop(@{$out_data});
            }
            return ()
        }
        if ($out_kbn eq 'USER') {
            ${$out_index}++;
            push(@{$out_data}, ["$index_org", "$seek_byte", "${$out_index}", 'USER', "$in_line"]);
            return ();
        }
    }
    
    # ��^���o
    if (&change_Bto2($extraction_data) !~ /^1/) {
        # �s���o�A�u���b�N���o
        $extraction_data = $extraction_data |
                           &get_cond_lc($in_line,
                                        grep{(${$_}[0] eq 'L' and ((${$_}[1] eq '' and ${$_}[2] ne 'E' and ${$_}[2] <= $index_now and (${$_}[3] eq 'E' or $index_now <= ${$_}[3]))
                                                                or (${$_}[1] ne '' and (${$_}[2] eq 'E' or $index_now < ${$_}[2] or (${$_}[3] ne 'E' and ${$_}[3] < $index_now))))
                                          or (${$_}[0] eq 'r' and ((${$_}[1] eq '' and ${$_}[2] <= $index_now)
                                                                or (${$_}[1] ne '' and $index_now < ${$_}[2])))
                                          or (${$_}[0] eq 'LR' and ${$_}[1] ne '' and ${$_}[8] eq '1' and ${$_}[9] <= $index_now))}@{$cond_data});
    }
    # �񒊏o
    if (&change_Bto2($extraction_data) !~ /^1/) {
        $extraction_data = $extraction_data |
                           &get_cond_c($in_line, grep{${$_}[0] eq 'C'}@{$cond_data});
        $extraction_data = $extraction_data |
                           &get_cond_cr($in_line, grep{${$_}[0] eq 'CR'}@{$cond_data});
    }
    
    # ���o���ʓo�^
    if (&change_Bto2($extraction_data) > 0) {
        my $out_line = &get_out_line("$in_line", &change_Bto2($extraction_data));
        ${$out_index}++;
        push(@{$out_data}, ["$index_org", "$seek_byte", "${$out_index}", "$out_kbn", "$out_line"]);
    }
}
###################################################################################################
sub put_mid_data {
    my ($obj, $index_now) = @_;
    my $mid_data   = \@{${$obj->{mid_data}}[$obj->{cond_index}]};
    my $out_data   = \@{${$obj->{pipe_data}}[($obj->{cond_index} + 1)]};
    my $out_index  = \${$obj->{out_index}}[$obj->{cond_index}];
    my $mid_flg    = 0;
    
    for (my $index=0 ; $index <= $#{$mid_data}; $index++) {
        if (${${$mid_data}[$index]}[2] == $index_now) {
            ${$out_index}++;
            push(@{$out_data}, ["${${$mid_data}[$index]}[0]", "${${$mid_data}[$index]}[1]", "${$out_index}", "${${$mid_data}[$index]}[3]", "${${$mid_data}[$index]}[4]"]);
            $mid_flg = 1;
            $obj->{out_kbn} = 'output';
        }
    }
    return $mid_flg;
}
###################################################################################################
sub check_mid_data {
    my ($obj, $index_now) = @_;
    my $mid_data          = \@{${$obj->{mid_data}}[$obj->{cond_index}]};
    
    for (my $index=0 ; $index <= $#{$mid_data}; $index++) {
        if (${${$mid_data}[$index]}[2] == $index_now and ${${$mid_data}[$index]}[3] eq 'DEL') {return 1}
    }
    return 0;
}
###################################################################################################
#   ���� ���o�f�[�^���擾 ����                                                                    #
###################################################################################################
sub get_out_line {
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
        my @col_data = &get_col_data('', "$_[0]"); unshift @col_data, '';
        my $out_data = '';
        for (my $index=1; $index <= $#col_data; $index++) {
            if ((substr $_[1], $index, 1) eq '1') {
                $out_data .= "$col_data[$index] ";
            }
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
    my $seek_data = \@{${$_[0]->{seek_data}}[$_[0]->{cond_index}]};
    
    return ${${$seek_data}[$#{$seek_data}]}[2];
}
###################################################################################################
#   ���� seek�s�ԍ��`�F�b�N ����                                                                  #
###################################################################################################
sub check_seek_num {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�ԍ�                                                                  #
    # ���� �F �s�ԍ��̋L�q�`�F�b�N                                                            #
    #-----------------------------------------------------------------------------------------#
    my $seek_data = \@{${$_[0]->{seek_data}}[$_[0]->{cond_index}]};
    
    if ($_[1] !~ /^\d+$/ or $_[1] <= 0) {
        print STDERR "Line Number Error($_[1]), \n";
        exit 99;
    }
    if ((${${$seek_data}[$#{$seek_data}]}[2] < $_[1] and (${${$seek_data}[$#{$seek_data}]}[2] + $_[0]->{seek_max}) < $_[1]) or
        (${${$seek_data}[$#{$seek_data}]}[2] > $_[1] and (${${$seek_data}[$#{$seek_data}]}[2] - $_[0]->{seek_max}) > $_[1])) {
        print STDERR "Seek Buffer Range Error($_[1]), \n";
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
    if ($_[0] ne 'org' and $_[0] ne 'now') {
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
    foreach (@{${$_[0]->{seek_data}}[$_[0]->{cond_index}]}) {
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
    my $cond_index     = $obj->{cond_index};
    my $in_data        = \@{${$obj->{pipe_data}}[$cond_index]};
    my $seek_data      = \@{${$obj->{seek_data}}[$cond_index]};
    my $out_data       = \@{${$obj->{pipe_data}}[($cond_index + 1)]};
    
    &check_seek_num($obj, "$number");
    if ($obj->{out_kbn} ne '') {$obj->{out_kbn} = 'seek'}
    
    if ($number <= ${${$seek_data}[$#{$seek_data}]}[2]) {
        for (my $index=0; $index <= $#{$seek_data}; $index++) {
            if ($number == ${${$seek_data}[$index]}[2]) {
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${${$seek_data}[$index]}[1]), 0 or "$!($obj->{in_name})";
                }
                @{$obj->{seek_num}}[0..2] = @{${$seek_data}[$index]};
                $obj->{seek_kbn}          = 'seek';
                $obj->{seek_index}        = $index;
                @{$obj->{get_num}}        = @{$obj->{seek_num}};
                $obj->{get_kbn}           = $obj->{seek_kbn};
                $obj->{get_index}         = $obj->{seek_index};
                return 0;
            }
        }
        &error_buffers(${${$seek_data}[$#{$seek_data}]}[2],$number);
    } else {
        if ($cond_index > 0) {
            my $for_max = $#{$in_data};
            if (${$in_data}[$#{$in_data}] ne 'Data_Extraction_END') {
                $for_max = $obj->{seek_max};
            }
            for (my $index=0; $index <= $for_max; $index++) {
                if ($number == ${${$in_data}[$index]}[2]) {
                    if ($obj->{in_kbn} ne '') {
                        seek EXTRACTION_FILE, (${${$in_data}[$index]}[1]), 0 or "$!($obj->{in_name})";
                    }
                    @{$obj->{seek_num}}[0..2] = @{${$in_data}[$index]};
                    $obj->{seek_kbn}          = 'input';
                    $obj->{seek_index}        = $index;
                    @{$obj->{get_num}}        = @{$obj->{seek_num}};
                    $obj->{get_kbn}           = $obj->{seek_kbn};
                    $obj->{get_index}         = $obj->{seek_index};
                    return 0;
                }
            }
            &error_buffers(${${$seek_data}[$#{$seek_data}]}[2],$number);
        } else {
            if ($obj->{in_kbn} ne '') {
                seek EXTRACTION_FILE, (${${$seek_data}[$#{$seek_data}]}[1]), 0 or "$!($obj->{in_name})";
            }
            my $index = ${${$seek_data}[$#{$seek_data}]}[2];
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
                    return 0;
                }
                $line = &get_line_data($obj, $index);
            }
            &error_buffers(${${$seek_data}[$#{$seek_data}]}[2],$number);
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
    my $line        = '';
    my $cond_index  = $obj->{cond_index};
    my $in_data     = \@{${$obj->{pipe_data}}[$cond_index]};
    my $seek_data   = \@{${$obj->{seek_data}}[$cond_index]};
    &check_data_acquisition_flag("$flg");
    
    if ($flg eq 'org' or $obj->{seek_kbn} eq 'org') {
        # �I���W�i��
        if ($obj->{get_kbn} ne 'org' and $obj->{seek_kbn} ne 'org' and
           ($obj->{seek_kbn} eq 'seek' or $obj->{seek_kbn} eq 'input') and
           ${$obj->{get_num}}[2] ne ${$obj->{seek_num}}[2]) {
            if ($obj->{in_kbn} ne '') {
                seek EXTRACTION_FILE, (${$obj->{seek_num}}[1]), 0 or "$!($obj->{in_name})";
            }
            $line = &get_line_data($obj, ${$obj->{seek_num}}[0]);
        }
        @{$obj->{get_num}} = @{$obj->{seek_num}};
        if ($obj->{seek_kbn} ne 'org') {
            $obj->{get_kbn}       = 'org';
        } else {
            $obj->{get_kbn}       = $obj->{seek_kbn};
        }
        $obj->{get_index}     = $obj->{seek_index};
        if ($_[0]->{in_kbn} eq '') {
            $line = &get_line_data($obj, (${$obj->{seek_num}}[2] - 1));
        } else {
            $line = &get_line_data($obj);
        }
        if ($obj->{seek_kbn} eq 'seek' or $obj->{seek_kbn} eq 'input') {
            if (($obj->{seek_kbn} eq 'seek'  and ${${$seek_data}[$obj->{seek_index}]}[2] >= ${$obj->{get_num}}[2]) or
                ($obj->{seek_kbn} eq 'input' and ${${$in_data}[$obj->{seek_index}]}[2] >= ${$obj->{get_num}}[2])) {
                $obj->{seek_index}++;
            }
            if ($obj->{seek_kbn} eq 'seek' and $#{$seek_data} < $obj->{seek_index}) {
                if ($cond_index > 0) {
                    $obj->{seek_kbn}   = 'input';
                    $obj->{seek_index} = 0;
                } else {
                    $obj->{seek_kbn}   = 'org';
                    $obj->{seek_index} = 0;
                }
            }
        }

        ${$obj->{seek_num}}[0]++;
    } else {
        # ���o����
        if ($obj->{seek_kbn} eq 'seek') {
            ${$obj->{seek_num}}[0] = ${${$seek_data}[$obj->{seek_index}]}[0];
            ${$obj->{seek_num}}[1] = ${${$seek_data}[$obj->{seek_index}]}[1];
            $line                  = ${${$seek_data}[$obj->{seek_index}]}[4];
        } else {
            ${$obj->{seek_num}}[0] = ${${$in_data}[$obj->{seek_index}]}[0];
            ${$obj->{seek_num}}[1] = ${${$in_data}[$obj->{seek_index}]}[1];
            $line                  = ${${$in_data}[$obj->{seek_index}]}[4];
        }
        
        @{$obj->{get_num}} = @{$obj->{seek_num}};
        $obj->{get_kbn}    = $obj->{seek_kbn};
        $obj->{get_index}  = $obj->{seek_index};
        $obj->{seek_index}++;
        if ($obj->{seek_kbn} eq 'seek' and $#{$seek_data} < $obj->{seek_index}) {
            if ($cond_index > 0) {
                $obj->{seek_kbn}   = 'input';
                $obj->{seek_index} = 0;
            } else {
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${$obj->{seek_num}}[1]), 0 or "$!($obj->{in_name})";
                }
                $line = &get_line_data($obj, ${$obj->{seek_num}}[0]);
                $obj->{seek_kbn}   = 'org';
                $obj->{seek_index} = 0;
                ${$obj->{seek_num}}[0]++;
            }
        }
        ${$obj->{seek_num}}[2]++;
    }
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
    if ($_[0]->{in_kbn} eq '') {
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
    my $extraction_data = '0' x (&get_col_data('', "$_[1]") + 1);
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
    my ($obj, $out_line) = @_;
    my $cond_index = $obj->{cond_index};
    my $in_data    = \@{${$obj->{pipe_data}}[$cond_index]};
    my $seek_data  = \@{${$obj->{seek_data}}[$cond_index]};
    my $mid_data   = \@{${$obj->{mid_data}}[$cond_index]};
    my $out_index  = \${$obj->{out_index}}[$cond_index];
    my $out_data   = \@{${$obj->{pipe_data}}[($cond_index + 1)]};
    
    if ($obj->{get_kbn} eq 'seek') {
        if ($obj->{get_index} == $#{$seek_data}) {
            ${$out_index}++;
            push(@{$out_data}, ["${${$seek_data}[$#{$seek_data}]}[0]", "${${$seek_data}[$#{$seek_data}]}[1]", "${$out_index}", 'USER', "$out_line"]);
            $obj->{out_kbn} = 'output';
        } else {
            for (my $index=$#{$out_data} ; $index >= 0 ; $index--) {
                if (${${$out_data}[$index]}[0] == ${$obj->{get_num}}[0]) {
                    if ($obj->{out_kbn} eq '') {
                        ${${$out_data}[$index]}[3] = 'USER';
                        ${${$out_data}[$index]}[4] = "$out_line";
                    } elsif ($index < $#{$out_data}) {
                        ${$out_index}++;
                        splice(@{$out_data}, ($index + 1), 0, ["${${$out_data}[$index]}[0]", "${${$out_data}[$index]}[1]", "${$out_index}", 'USER', "$out_line"]);
                    } else {
                        ${$out_index}++;
                        push(@{$out_data}, ["${${$out_data}[$index]}[0]", "${${$out_data}[$index]}[1]", "${$out_index}", 'USER', "$out_line"]);
                    }
                    $obj->{out_kbn} = 'output';
                    last;
                } elsif (${${$out_data}[$index]}[0] < ${$obj->{get_num}}[0]) {
                    ${$out_index}++;
                    splice(@{$out_data}, $index, 0, ["${$obj->{get_num}}[0]", "${$obj->{get_num}}[1]", "${$out_index}", 'USER', "$out_line"]);
                }
            }
            if ($obj->{out_kbn} ne 'output') {
                &error_buffers(${${$seek_data}[$#{$seek_data}]}[2],${$obj->{get_num}}[2]);
            }
        }
    } elsif ($obj->{get_kbn} eq 'input') {
        my $get_data = \@{${$in_data}[$obj->{get_index}]};
        push(@{$mid_data}, ["${$get_data}[0]", "${$get_data}[1]", "${$get_data}[2]", 'USER', "$out_line"]);
    } else {
        push(@{$mid_data}, ["${$obj->{get_num}}[0]", "${$obj->{get_num}}[1]", "${$obj->{get_num}}[2]", 'USER', "$out_line"]);
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
    my ($obj) = @_;
    
    my $cond_index = $obj->{cond_index};
    my $in_data    = \@{${$obj->{pipe_data}}[$cond_index]};
    my $seek_data  = \@{${$obj->{seek_data}}[$cond_index]};
    my $mid_data   = \@{${$obj->{mid_data}}[$cond_index]};
    my $out_data   = \@{${$obj->{pipe_data}}[($cond_index + 1)]};
    my $out_index  = \${$obj->{out_index}}[$cond_index];
    
    if ($obj->{get_kbn} eq 'seek') {
        if ($obj->{get_index} < $#{$seek_data}) {
            my $del_flg = undef;
            for (my $index=$#{$out_data} ; $index >= 0 ; $index--) {
                if (${${$out_data}[$index]}[0] == ${$obj->{get_num}}[0]) {
                    if (${${$out_data}[$index]}[3] eq '' or $index == 0) {
                        splice(@{$out_data}, $index, 1);
                        last;
                    } else {
                        $del_flg = '1';
                    }
                } elsif ($del_flg = '1') {
                    splice(@{$out_data}, ($index + 1), 1);
                    last;
                }
            }
        } else {
            push(@{$out_data}, ["${${$seek_data}[$#{$seek_data}]}[0]", '', '', 'DEL', '']);
        }
        $obj->{out_kbn} = 'output';
    } elsif ($obj->{get_kbn} eq 'input') {
        my $get_data = \@{${$in_data}[$obj->{get_index}]};
        push(@{$mid_data}, ["${$get_data}[0]", '', "${$get_data}[2]", 'DEL', '']);
    } else {
        push(@{$mid_data}, ["${$obj->{get_num}}[0]", '', "${$obj->{get_num}}[2]", 'DEL', '']);
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
    my $obj       = shift;
    my $line_now  = shift;
    my $line_data = shift;
    my @add_cond  = ();
    my $in_data   = \@{${$obj->{pipe_data}}[$obj->{cond_index}]};
    
    # ���K�\���w����s�ԍ��w��ɕϊ��i�N�_�s�j
    foreach (@_) {
        if ($line_data =~ /${$_}[2]/) {
            if (${$_}[1] eq '') {
                if (${$_}[3] eq '') {
                    push(@add_cond, ['L', "", "$line_now", "$line_now", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                } elsif (${$_}[3] =~ /^\+\d+$/ ) {
                    push(@add_cond, ['L', "", "$line_now", ($line_now + ${$_}[3]), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                } elsif (${$_}[3] =~ /^-\d+$/ ) {
                } else {
                    push(@add_cond, ['r', "", "$line_now", "${$_}[3]", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                }
            } else {
                if (${$_}[3] eq '') {
                    if (${$_}[8] eq '1') {
                        push(@add_cond, ['L', "", "${$_}[9]", ($line_now - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                    }
                    ${$_}[9] = ($line_now + 1);
                } elsif (${$_}[3] =~ /^\+\d+$/ ) {
                    if (${$_}[8] eq '1') {
                        push(@add_cond, ['L', "", "${$_}[9]", ($line_now - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                    }
                    ${$_}[9] = ($line_now + ${$_}[3] + 1);
                } elsif (${$_}[3] =~ /^-\d+$/ ) {
                } else {
                    if (${$_}[8] eq '1') {
                        push(@add_cond, ['L', "", "${$_}[9]", ($line_now - 1), "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                    }
                }
                ${$_}[8] = '';
            }
        } elsif (${$_}[3] =~ /^-\d+$/ and ${$in_data}[(${$_}[3] * -1)] ne 'Data_Extraction_END' and ${${$in_data}[(${$_}[3] * -1)]}[4] =~ /${$_}[2]/) {
            if (${$_}[1] eq '') {
                    push(@add_cond, ['L', "", (${${$in_data}[(${$_}[3] * -1)]}[2] + ${$_}[3]), ${${$in_data}[(${$_}[3] * -1)]}[2], "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
            } else {
                if (${$_}[8] eq '1') {
                    push(@add_cond, ['L', "", "${$_}[9]", "$line_now", "${$_}[4]", "${$_}[5]", "${$_}[6]", "${$_}[7]"]);
                }
                ${$_}[9] = ($line_now + (${$_}[3] * -1) + 2);
                ${$_}[8] = '';
            }
        } else {
            if (${$_}[8] eq '') {
                if (${$_}[3] eq '' or ${$_}[3] =~ /^[\+-]\d+$/ ) {
                    if (${$_}[9] <= $line_now) {
                        ${$_}[8] = '1';
                    }
                } else {
                    if ($line_data =~ /${$_}[3]/) {
                        ${$_}[8] = '0';
                        ${$_}[9] = ($line_now + 1);
                    }
                }
            } elsif (${$_}[8] eq '0') {
                ${$_}[8] = '1';
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
            ${$_}[2]++;
            ${$_}[3] = ${$_}[2];
        } elsif (${$_}[3] =~ /^\d+$/) {
            if (${$_}[2] > ${$_}[3]) {
                my $temp_su = ${$_}[2];
                ${$_}[2] = ${$_}[3];
                ${$_}[3] = $temp_su;
            }
        } elsif (${$_}[3] =~ /^-\d+$/ and ${$_}[3] != 0) {
            ${$_}[3] = ${$_}[2] + (${$_}[3] * -1);
        } elsif (${$_}[3] =~ /^\+\d+$/ and ${$_}[3] != 0) {
            ${$_}[2]++;
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
        ${$_}[3] = $line_now + 1;
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
    my $extraction_data = undef;
    $obj->{out_kbn}     = undef;
    my $seek_data       = \@{${$obj->{seek_data}}[$obj->{cond_index}]};
    
    foreach (@_) {
        # ���[�U�[�֐��̌ďo��
        @{$obj->{seek_num}}[0..2] = @{${$seek_data}[$#{$seek_data}]};
        $obj->{seek_index}        = $#{$seek_data};
        $obj->{seek_kbn}          = 'seek';
        @{$obj->{get_num}}        = @{$obj->{seek_num}};
        $obj->{get_kbn}           = $obj->{seek_kbn};
        $obj->{get_index}         = $obj->{seek_index};
        seek EXTRACTION_FILE, (${$obj->{get_num}}[1]), 0 or "$!($obj->{in_name})";
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
        return &change_2toB('1');
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
    my $col_su          = &get_col_data('', shift);
    my $col_start       = undef;
    my $col_end         = undef;
    my $col_add         = undef;
    my $in_kbn          = undef;
    my $in_start        = undef;
    my $in_end          = undef;
    my $extraction_data = '0' x $col_su;
    
    foreach (@_) {
        # ���o����Ώۂ��`�F�b�N
        if (${$_}[0] eq 'C') {
            $col_add = 0;
        } else {
            $col_add = 4;
        }
        # �N�_��ݒ�
        if (${$_}[(2 + $col_add)] eq 'E' or ${$_}[(2 + $col_add)] eq 'e') {
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
                substr($extraction_data, $index2, 1) = '1';
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
    my $in_line         = shift;
    my $col_su          = &get_col_data('', "$in_line");
    my $col_start       = undef;
    my $col_end         = undef;
    my $col_add         = undef;
    my $in_kbn          = undef;
    my $in_start        = undef;
    my $in_end          = undef;
    my $extraction_data = '0' x $col_su;
    $in_line           .= ",";
    my $check_key1      = undef;
    my $check_key2      = undef;
    
    foreach(@_) {
        my $line_data = $in_line;
        if (${$_}[0] eq 'CR') {
            $col_add = 0;
        } else {
            $col_add = 4;
        }
        ${$_}[(2 + $col_add)] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
        ${$_}[(2 + $col_add)] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
        ${$_}[(2 + $col_add)] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
        ${$_}[(2 + $col_add)] =~  s/^(\[.*),(.*\]\*)/$1$2/;
        if (${$_}[(3 + $col_add)] ne '' and ${$_}[(3 + $col_add)] !~ /^[\+-]\d+$/) {
            ${$_}[(3 + $col_add)] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
            ${$_}[(3 + $col_add)] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
            ${$_}[(3 + $col_add)] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
            ${$_}[(3 + $col_add)] =~  s/^(\[.*),(.*\]\*)/$1$2/;
        }
        
        # ���o����Ώۂ��`�F�b�N
        my @cond_c_new = ();
        $col_start = 0;
        $col_end   = 0;
        while (1) {
            my $key = undef;
            if ($line_data =~ /(${$_}[(2 + $col_add)])/) {
                $key = $1;
            }
            # ���K�\��(�N�_)��␳
            $check_key1 = '';
            if ($key !~ /^\s|^\,/) {
                $check_key1 .= '[^\s\,]*';
            }
            $check_key1 .= ${$_}[(2 + $col_add)];
            if ($key !~ /\s$|\,$/) {
                $check_key1 .= '[^\s\,\n]*';
            }
            if ($line_data !~ /($check_key1)(.*)/) {
                last;
            }
            # ���K�\��(�͈�)��␳
            $check_key2 = '';
            if (${$_}[(3 + $col_add)] ne '' and ${$_}[(3 + $col_add)] !~ /^[\+-]\d+$/) {
                if ($line_data =~ /(${$_}[(3 + $col_add)])/) {
                    $key = $1;
                }
                if ($key !~ /^\s|^\,/) {
                    $check_key2 .= '[^\s\,]*';
                }
                $check_key2 .= ${$_}[(3 + $col_add)];
                if ($key !~ /\s$|\,$|\n$/) {
                    $check_key2 .= '[^\s\,]*';
                }
            }
            my $next_data = $2;
            # ���o�͈͂��Z�o
            my @split_out1 = split /($check_key1)/, $line_data, 3;
            my $split_out1_add = 0;
            if ($split_out1[0] =~ /^\s+\,*\s*$|^\,+\s*$/) {
            } else {
                if ($split_out1[0] =~ /^\s|^\,/ and $split_out1[0] =~ /\s+$|\,+$/) {
                    $split_out1_add--;
                }
            }
            $col_start = $col_start + (&get_col_data('', "$split_out1[0]")) + $split_out1_add + 1;
            my $col_split_out1 = &get_col_data('', "$split_out1[1]");
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
                    $col_end = $col_su - (&get_col_data('', "$back_data")) + 1;
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
                substr($extraction_data, $index2, 1) = '1';
            }
        }
    }
    return &change_2toB("$extraction_data");
}
1;
