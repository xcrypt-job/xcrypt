############################################
# ������ϥǡ����������                   #
# Ver=0.3 2010/02/04                       #
############################################
package data_generator;
use strict;
use File::Spec;
use File::Basename;
use Cwd;

###################################################################################################
#   ��� �ִ����ե�������� ���                                                                  #
###################################################################################################
sub new{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���饹̾                                                                #
    #         $_[1] = �����ե�����̾                                                          #
    #         $_[2] = �����ե������Ǽ�ǥ��쥯�ȥ�̾                                          #
    # ���� �� ���֥�������������ִ����ե����������                                          #
    # �ֵ� �� ���֥�������                                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my $class             = shift;                                                            # ���饹̾
    my $infile            = shift;                                                            # �����ե�����̾
    my $outdir            = shift;                                                            # �����ե������Ǽ�ǥ��쥯�ȥ�̾
    my $outfile           = File::Spec->catfile("$outdir", (basename($infile)));              # �����ե�����̾
    my @replace_datas     = ();                                                               # �ִ�������(����)
    my @insert_datas      = ();                                                               # ��������(����)
    my $value_options_all = undef;                                                            # ɸ��ɽ����
    
    ####################
    # �ե���������å� #
    ####################
    # �����ե���������å�
    if (!-e "$infile") {
        # �ե�����̵��
        print STDERR "Input file($infile) not found\n";
        exit 99;
    } elsif (!-r "$infile") {
        # �ե�������ɹ��߸���̵��
        print STDERR "Input file($infile) is not read authority\n";
        exit 99;
    }
    # �����ե���������å�
    if (!-d "$outdir") {
        # �ǥ��쥯�ȥ�̵��
        print STDERR "Output file directory($outdir) not found\n";
        exit 99;
    } elsif (!-w "$outdir") {
        # �ǥ��쥯�ȥ�˽���߸���̵��
        print STDERR "Output file directory($outdir) is not write authority\n";
        exit 99;
    } elsif (-e "$outfile" and !-w "$outfile") {
        # �ե�����˽���߸���̵��
        print STDERR "Output file($outfile) is not write authority\n";
        exit 99;
    }
    
    ####################
    # ���֥���������� #
    ####################
    my $job = {"infile"            =>$infile,                                                 # �����ե�����̾
               "outfile"           =>$outfile,                                                # �����ե�����̾
               "replace_datas"     =>\@replace_datas,                                         # �ִ�������
               "insert_datas"      =>\@insert_datas,                                          # ��������
               "value_options_all" =>$value_options_all};                                     # ɸ��ɽ����
    return bless $job, $class;
}
###################################################################################################
#   ��� �ѿ�̾����ˤ��ǡ����ִ��� ���                                                        #
###################################################################################################
sub replace_key_value{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���֥�������                                                            #
    #         $_[1] = �ѿ�̾                                                                  #
    #         $_[2] = �ִ���ʸ����                                                            #
    #         $_[3] = ʸ����ɽ����                                                          #
    # ���� �� �ѿ�̾�����å���������Ͽ                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my $self   = shift;                                                                       # ���֥�������
    my $key    = shift;                                                                       # �ѿ�̾
    my $value  = shift;                                                                       # �ִ���ʸ����
    my $format = shift;                                                                       # ʸ����ɽ����
    
    # �ѿ�̾�����å�
    &check_key_name("$key");
    
    ############
    # ������Ͽ #
    ############
    my %replace_data       = ();
    $replace_data{'key'}   = "$key";
    $replace_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{replace_datas}}, \%replace_data);
}
###################################################################################################
#   ��� �ԡ����ֹ����ˤ��ʸ�����ִ��� ���                                                    #
###################################################################################################
sub replace_line_column{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���֥�������                                                            #
    #         $_[1] = ���ֹ�                                                                  #
    #         $_[2] = ���ֹ�                                                                  #
    #         $_[3] = �ִ���ʸ����                                                            #
    #         $_[4] = ʸ����ɽ����                                                          #
    # ���� �� ���ֹ�����å���ʸ�����ֹ�����å���������Ͽ                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my $self   = shift;                                                                       # ���֥�������
    my $num    = shift;                                                                       # ���ֹ�
    my $col    = shift;                                                                       # ���ֹ�
    my $value  = shift;                                                                       # �ִ���ʸ����
    my $format = shift;                                                                       # ʸ����ɽ����
    
    # ���ֹ�����å�
    &check_number("$num", "Line");
    # ���ֹ�����å�
    &check_number("$col", "Character string");
    
    ############
    # ������Ͽ #
    ############
    my %replace_data       = ();
    $replace_data{'num'}   = "$num";
    $replace_data{'col'}   = "$col";
    $replace_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{replace_datas}}, \%replace_data);
}
###################################################################################################
#   ��� ���ֹ����ˤ����ִ��� ���                                                            #
###################################################################################################
sub replace_line{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���֥�������                                                            #
    #         $_[1] = ���ֹ�                                                                  #
    #         $_[2] = �ִ���ʸ����                                                            #
    #         $_[3] = ʸ����ɽ����                                                          #
    # ���� �� ���ֹ�����å���������Ͽ                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my $self   = shift;                                                                       # ���֥�������
    my $num    = shift;                                                                       # ���ֹ�
    my $value  = shift;                                                                       # �ִ���ʸ����
    my $format = shift;                                                                       # ʸ����ɽ����
    
    # ���ֹ�����å�
    &check_number("$num", "Line");
    
    ############
    # ������Ͽ #
    ############
    my %replace_data       = ();
    $replace_data{'num'}   = "$num";
    $replace_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{replace_datas}}, \%replace_data);
}
###################################################################################################
#   ��� ���ֹ����ˤ������� ���                                                              #
###################################################################################################
sub insert_line{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���֥�������                                                            #
    #         $_[1] = ���ֹ�                                                                  #
    #         $_[2] = �ִ���ʸ����                                                            #
    #         $_[3] = ʸ����ɽ����                                                          #
    # ���� �� ���ֹ�����å���������Ͽ                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my $self   = shift;                                                                       # ���֥�������
    my $num    = shift;                                                                       # ���ֹ�
    my $value  = shift;                                                                       # �ִ���ʸ����
    my $format = shift;                                                                       # ʸ����ɽ����
    
    # ���ֹ�����å�
    &check_number("$num", "Line");
    
    ############
    # ������Ͽ #
    ############
    my %insert_data       = ();
    $insert_data{'num'}   = "$num";
    $insert_data{'value'} = &value_evaluation("$value", "$format");
    push (@{$self->{insert_datas}}, \%insert_data);
}
###################################################################################################
#   ��� ɸ��ɽ���񼰻��� ���                                                                    #
###################################################################################################
sub set_default_format{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���֥�������                                                            #
    #         $_[1] = ɸ��ɽ����                                                            #
    # ���� �� ɸ��ɽ���񼰤���Ͽ                                                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my $self   = shift;                                                                       # ���֥�������
    my $format = shift;                                                                       # ʸ����ɽ����
    
    ############
    # ������Ͽ #
    ############
    $self->{value_option_all} = "$format";
}
###################################################################################################
#   ��� �ִ��� ���                                                                              #
###################################################################################################
sub execute{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���֥�������                                                            #
    # ���� �� �����ե������ؼ��˽����Ѵ����������ե�����ؽ���                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my $self      = shift;                                                                    # ���֥�������
    my $in_cnt    = 0;                                                                        # ���Ϲ��ֹ�
    my $rep_data  = undef;                                                                    # �ִ����оݥǡ���
    my $out_data  = '';                                                                       # �ִ�����ǡ���
    
    ################
    # �ե�����OPEN #
    ################
    # �����ե�����OPEN
    if (!open (BASE_FILE, "< $self->{infile}")) {
        # �ե�����OPEN���顼
        print STDERR "Input file($self->{infile}) cannot open file\n";
        exit 99;
    }
    # �����ե�����ζ��ѥ�å�
    flock(BASE_FILE, 1);
    # �����ե�����OPEN
    if (!open (CREATE_FILE, "+> $self->{outfile}")) {
        # �ե�����OPEN���顼
        print STDERR "Output file($self->{outfile}) cannot open file\n";
        exit 99;
    }
    # �����ե��������¾��å�
    flock(CREATE_FILE, 2);
    
    ##################
    # Insert/Replace #
    ##################
    while (my $in_data = <BASE_FILE>){
        $in_cnt++;
        $rep_data = "$in_data";
        # ���ԥ����ɤ���
        if ((substr $in_data, -1) eq "\n") {
            chomp $rep_data;
        }
        ### Insert ###
        foreach my $insert_data(@{$self->{insert_datas}}) {
            if ((exists $insert_data->{num}) and $in_cnt == $insert_data->{num}) {
                #============#
                # �������о� #
                #============#
                $out_data = &value_evaluation("$insert_data->{value}", "$self->{value_option_all}");
                print CREATE_FILE "$out_data\n";
            }
        }
        ### Replace ###
        foreach my $replace_data(@{$self->{replace_datas}}) {
            my @out_datas1 = ();
            my @out_datas2 = ();
            
            # �ִ��������ο�ʬ��
            if ((exists $replace_data->{num}) and $in_cnt == $replace_data->{num}) {
                #====================#
                # �Ի���ˤ���ִ��� #
                #====================#
                if (!exists $replace_data->{col}) {
                    #----------#
                    # ���ִ��� #
                    #----------#
                    $rep_data = $replace_data->{value};
                } else {
                    #--------------#
                    # ʸ�����ִ��� #
                    #--------------#
                    # ���ڡ��������֡����Զ��ڤ�ǥǡ���ʬ��
                    @out_datas1 = split /\s+\,*\s*|\,+\s*/, $rep_data;
                    if ($out_datas1[($replace_data->{col} - 1)] eq '') {
                        next;
                       #print STDERR "Replace Data Not Found(Line=$replace_data->{num} Colum=$replace_data->{col})\n";
                       #exit 99;
                    }
                    my $out_datas1_su = @out_datas1;
                    # �������å�ʸ����ǥǡ���ʬ��
                    my $out_datas2_first = undef;
                    my $out_datas2_last  = undef;
                    my $split_col = $replace_data->{col} - 1;
                    if ($replace_data->{col} eq 1) {
                        @out_datas2 = split /($out_datas1[$split_col]\s|$out_datas1[$split_col]\,)/, $rep_data, 2;
                        $out_datas2_first = '';
                        $out_datas2_last  = substr $out_datas2[1], -1;
                    } elsif ($replace_data->{col} < $out_datas1_su) {
                        @out_datas2       = split /(\s$out_datas1[$split_col]\s|\,$out_datas1[$split_col]\,|\s$out_datas1[$split_col]\s|\,$out_datas1[$split_col]\s)/, $rep_data, 2;
                        $out_datas2_first = substr $out_datas2[1], 0, 1;
                        $out_datas2_last  = substr $out_datas2[1], -1;
                    } else {
                        @out_datas2       = split /\s$out_datas1[$split_col]\n|\,$out_datas1[$split_col]\n/, $rep_data, 2;
                        $out_datas2_first = substr $out_datas2[1], 0, 1;
                        $out_datas2_last  = '';
                        $out_datas2[2]    = '';
                    }
                    # ʸ�����ִ���
                    $rep_data = $out_datas2[0].$out_datas2_first.$replace_data->{value}.$out_datas2_last.$out_datas2[2];
                }
            } elsif (exists $replace_data->{key}) {
                #======================#
                # �ѿ�����ˤ���ִ��� #
                #======================#
                # �ѿ�̾�ǥǡ���ʬ��
                my $set_name = '';
                my @key_datas = split /([\(\)\:])/, $replace_data->{key};
                if ("$key_datas[0]" ne "$replace_data->{key}") {
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
                    $set_name = $replace_data->{key};
                }
                @out_datas1 = split /(${set_name}\s+=\s*|${set_name}=\s*)/, "$rep_data", 2;
                
                # ʸ�����ִ���
                if ($out_datas1[0] ne $rep_data and ($out_datas1[0] eq '' or (substr $out_datas1[0], -1) eq ' ' or (substr $out_datas1[0], -1) eq ',')) {
                    #----------------#
                    # �����ѿ�̾���� #
                    #----------------#
                    # ʸ������������å�
                    if ($out_datas1[2] =~ /^[\"\']/) {
                        #����������������������������#
                        # �������Ȥ��� #
                        #����������������������������#
                        my $out_quote = substr $out_datas1[2], 0, 1;
                        $out_data     = substr $out_datas1[2], 1;
                        chomp $out_data;
                        @out_datas2 = split /($out_quote\s|$out_quote\,)/, "$out_data", 2;
                        $out_data   = $out_datas1[0].$out_datas1[1].$out_quote.$replace_data->{value}.$out_quote;
                    } else {
                        #����������������������������#
                        # �������Ȥʤ� #
                        #����������������������������#
                        @out_datas2 = split /(,|\s)/, "$out_datas1[2]", 2;
                        if ($replace_data->{value} =~ /^\((.*)\)$/) {
                            # �ʥ��å�����(ʣ�ǿ�)��
                            my @out_datas3 = split /(\s+\,*\s*|\,+\s*)/, $1;
                            $out_data      = $out_datas1[0].$out_datas1[1].'(';
                            for (my $index2=0; $index2 <= $#out_datas3; $index2++) {
                                if (($index2%2 ? "1" : "2") == 2) {
                                    if ($out_datas3[$index2] =~ /^[\+-]*\d+\.*\d*[DdEeQq\+-_]*\d*$|^[\+-]*\.\d*[DdEeQq\+-_]*\d*$/) {
                                        $out_data .= $out_datas3[$index2];
                                    } else {
                                        $out_data .= '"'.$out_datas3[$index2].'"';
                                    }
                                } else {
                                    $out_data .= $out_datas3[$index2];
                                }
                            }
                            $out_data .= ')';
                        } else {
                            # �ʥ��å��ʤ�(�¿���ñ���ټ¿��������ټ¿���8�Х�������)��
                            if ($replace_data->{value} =~ /^[\+-]*\d+\.*\d*[DdEeQq\+-_]*\d*$|^[\+-]*\.\d*[DdEeQq\+-_]*\d*$/) {
                                $out_data = $out_datas1[0].$out_datas1[1].$replace_data->{value};
                            } else {
                                $out_data = $out_datas1[0].$out_datas1[1].'"'.$replace_data->{value}.'"';
                            }
                        }
                    }
                    $out_data .= (substr $out_datas2[1], -1);
                    if ($out_datas2[2] ne '') {
                        $out_data .= $out_datas2[2];
                    }
                    $rep_data = $out_data;
                }
            }
        }
        if ((substr $in_data, -1) eq "\n") {
            $rep_data .= "\n";
        }
        
        # �����ǡ����˽񤫤줿�ѿ���ɾ��
        $out_data = &value_evaluation("$rep_data", "$self->{value_option_all}");
        print CREATE_FILE "$out_data";
    }
    
    ################
    # �ե�����OPEN #
    ################
    close(CREATE_FILE);
    close(BASE_FILE);
}
###################################################################################################
#   ��� �ѿ�̾�����å� ���                                                                      #
###################################################################################################
sub check_key_name{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = �ѿ�̾                                                                  #
    # ���� �� �ѿ�̾�����å�                                                                  #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] !~ /^[a-zA-Z]/) {
        print STDERR "There is not the top of the variable name in the alphabet ($_[0])\n";
        exit 99;
    }
}
###################################################################################################
#   ��� ���������å� ���                                                                        #
###################################################################################################
sub check_number{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ���ֹ�or���ֹ�                                                          #
    #      �� $_[1] = �����å��о�                                                            #
    # ���� �� ���������å�                                                                    #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] !~ /\d/ or $_[0] == 0) {
        print STDERR "$_[1] number is not a number ($_[0])\n";
        exit 99;
    }
}
###################################################################################################
#   ��� ʸ�����ɾ�� ���                                                                        #
###################################################################################################
sub value_evaluation{
    #-----------------------------------------------------------------------------------------#
    # ���� �� $_[0] = ʸ����                                                                  #
    #         $_[1] = ʸ����ɽ����                                                          #
    # ���� �� ʸ�����ɾ��                                                                    #
    # �ֵ� �� ɾ�������                                                                      #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ѿ���� #
    ############
    my @in_values = ();                                                                       # ���ϥǡ���(����)
    $in_values[1] = $_[0];                                                                    # ɾ���оݥǡ���
    my $in_value  = undef;                                                                    # �ѿ�̾�Ѵ������ϥǡ���
    my $in_option = $_[1];                                                                    # ʸ����ɽ����
    my $out_value = '';                                                                       # ɾ����ǡ���
    
    ############################
    # �����Х��ѿ�ɽ�����ѹ� #
    ############################
    do {
        @in_values = split /\$/, "$in_values[1]", 2;
        $in_value .= $in_values[0];
        if ($in_values[1] ne '') {
            #==============#
            # �ѿ�ɽ������ #
            #==============#
            my $in_value0_last = substr $in_values[0], -1;
            if ($in_value0_last ne '\\') {
                my @in_evaluations    = ();
                my $check_evaluation  = '';
                my $check_evaluation2 = '';
                my $check_data        = '';
                my $out_evaluation    = undef;
                my $in_value1_first   = substr $in_values[1], 0, 1;
                if ($in_value1_first eq '{') {
                    $in_values[1] = substr $in_values[1], 1;
                }
                my @in_evaluations = split /[\$\s\}\,\.\#\%\&\'\"\!\+\-\*\/\;\:\@\\\=\>\<\@\?\(\)]/, "$in_values[1]", 2;
                $check_data        = $in_evaluations[0];
                @in_evaluations    = split /$check_data/, "$in_values[1]", 2;
                my $in_evaluations1_first = substr $in_evaluations[1], 0, 1;
                if ($in_evaluations1_first eq '}') {
                    $in_evaluations[1] = substr $in_evaluations[1], 1;
                }
                $check_evaluation = '${'.$check_data.'};';
                if (eval ($check_evaluation)) {
                    #===============#
                    # local�ѿ����� #
                    #===============#
                    $check_evaluation2 = '$out_evaluation = ${'.$check_data.'};';
                    eval ($check_evaluation2);
                    $in_value    .= $out_evaluation;
                    $in_values[1] = $in_evaluations[1];
                } else {
                    #===============#
                    # local�ѿ��ʤ� #
                    #===============#
                    $check_evaluation2 = '$out_evaluation = ${main::'.$check_data.'};';
                    eval ($check_evaluation2);
                    $in_value    .= $out_evaluation;
                    $in_values[1] = $in_evaluations[1];
                }
            }
        }
    } while ($in_values[1] ne '');
    
    ################
    # ʸ�����ɾ�� # ���׻�����ɾ�����ϡ�"%"�������ϤäƤ���
    ################
    @in_values    = ();
    $in_values[1] = $in_value;
    $in_value     = undef;
    $out_value    = '';
    do {
        @in_values  = split /[\%]/, "$in_values[1]", 2;
        $out_value .= $in_values[0];
        if ($in_values[1] =~ /\%/) {
            #==============#
            # ɾ���оݤ��� #
            #==============#
            my @in_values2     = split /[\%]/, "$in_values[1]", 2;
            if ($in_values2[0] =~ /[0-9]/ and $in_values2[0] !~ /[a-zA-Z]/ and $in_values2[0] =~ /[\+\-\*\/]/) {
                #------------#
                # �׻������� #
                #------------#
                my $rep_value      = undef;
                my $out_value_data = undef;
                if ($in_option eq '') {
                    #����������������������������#
                    # �񼰻���ʤ� #
                    #����������������������������#
                    $out_value_data = '$rep_value = sprintf '.$in_values2[0].';';
                } else {
                    #����������������������������#
                    # �񼰻��ꤢ�� #
                    #����������������������������#
                    $out_value_data = '$rep_value = sprintf "\%'.$in_option.'",'.$in_values2[0].';';
                }
                eval($out_value_data);
                $out_value   .= $rep_value;
                $in_values[1] = $in_values2[1];
            } else {
                #------------#
                # �׻����ʤ� #
                #------------#
                $out_value   .= $in_values2[0];
                $in_values[1] = $in_values2[1];
            }
        } else {
            #==============#
            # ɾ���оݤʤ� #
            #==============#
            $out_value   .= $in_values[1];
            $in_values[1] = '';
        }
    } while ($in_values[1] ne '');
    
    ################
    # ɾ������ֵ� #
    ################
    return "$out_value";
}
1;
