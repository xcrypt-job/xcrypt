#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;

#------------< �ѿ������ >------------#
my $inventory_dir = undef;
my $inventory_lock_dir = ".lock";
my $inventory_name = undef;
my $inventory_file = undef;
my $inventory_status = undef;
my @inventory_write_datas = ();
my $time_out = 10;                                                   # timeout��
#------------------------------------------------------------------------------#
#   ��� check_cmdline(���ޥ�ɥ饤����������å�)����� ���                  #
#------------------------------------------------------------------------------#
sub check_cmdline {
        ############################################
        # $ARGV[0] = Inventory�ե�����̾(�ե�ѥ�) #
        # $ARGV[1] = status                        #
        # $ARGV[2] = �ɲþ���                      #
        ############################################
        #----��������----#
    if ($#ARGV < 1) {
                # ɬ�ܰ����ʤ�
        print STDERR "pjo_inventory_write option error\n";
        exit 99;
    }
    $inventory_file = shift @ARGV;
    $inventory_dir = dirname($inventory_file);
    $inventory_name = basename($inventory_file);
    $inventory_status = $ARGV[0];
    while ($#ARGV > 0) {
        unless ($ARGV[1] eq '') {
            push(@inventory_write_datas , $ARGV[1]);
        }
        shift @ARGV;
    }
        #----������������������å�----#
        # Inventory�ե�����̾
    if (-e $inventory_file) {
        if (! -w $inventory_file) {
            print STDERR "$inventory_file is not write authority\n";
            exit 99;
        } elsif (! -r $inventory_file) {
            print STDERR "$inventory_file is not read authority\n";
            exit 99;
        }
    }
        # status
    if ($inventory_status eq '') {
        print STDERR "status option error\n";
        exit 99;
    }
        # �ɲþ���
    foreach my $inventory_write_data(@inventory_write_datas) {
        if ( $inventory_write_data !~ m/^.+\:\s+/) {
            print STDERR "Additional Information does not match a pattern \($inventory_write_data\)\n";
            exit 99;
        }
    }
}
#------------------------------------------------------------------------------#
#   ��� Put_inventory_update(Inventory�ե��������)����� ���                #
#------------------------------------------------------------------------------#
sub Put_inventory_update {
    if ($inventory_status ne 'queued' and
        $inventory_status ne 'aborted') {
                # ��å��ե�����¸�߳�ǧ(��������ޤ��Ԥ�)
        if (-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
            my $check_lock_fkg = 0;
                        # �����ޡ��ƻ�
            eval {
                local $SIG{ALRM} = sub {die "timeout"};
                alarm $time_out;
                while ($check_lock_fkg == 0) {
                                        # sleep�Ԥ�
                    sleep 1;
                                        # ��å��ե�����¸�߳�ǧ
                    if (!-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
                        $check_lock_fkg = 1;
                    }
                }
                alarm 0;
            };
            alarm 0;
            if($@) {
                if($@ =~ /timeout/) {
                    print STDERR "${inventory_dir}/${inventory_lock_dir}/${inventory_name} cannot open timeout\n";
                    exit 99;
                }
            }
        }
    }
        
        # Inventory�ե�����OPEN
    if (! open (INVENTORY_FILE, "+>>$inventory_file")) {
        print STDERR "$inventory_file cannot open file\n";
        exit 99;
    }
        # Inventory�ե��������¾��å�
    flock(INVENTORY_FILE, 2);
        
        # ���ܾ���ν���
    if ($inventory_status ne 'queued') {
                # status�ν���
        print INVENTORY_FILE "status: $inventory_status\n";
                # ǯ������ʬ�ä����
        my $time_now = time();
        my @times = localtime($time_now);
        my ($year, $mon, $mday, $hour, $min, $sec, $wday) = ($times[5] + 1900, $times[4] + 1, $times[3], $times[2], $times[1], $times[0], $times[6]);
        my $timestring = sprintf("%04d%02d%02d_%02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
                # ǯ������ʬ�äν���
        print INVENTORY_FILE "date_${inventory_status}: $timestring\n";
        print INVENTORY_FILE "time_${inventory_status}: $time_now\n";
    }
        # �ɲþ���ν���
    foreach my $inventory_write_data(@inventory_write_datas) {
        print INVENTORY_FILE $inventory_write_data."\n";
                #print "inventory_write_data = $inventory_write_data\n";
    }
        # ��å��ե��������
    if ($inventory_status eq 'submit') {
        if (!-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
            if (! open (INVENTORY_FILE_LOCK, ">${inventory_dir}/${inventory_lock_dir}/${inventory_name}")) {
                print STDERR "${inventory_dir}/${inventory_lock_dir}/${inventory_name} cannot make file\n";
                exit 99;
            }
            close(INVENTORY_FILE_LOCK);
        }
    }
        # ��å��ե�������
    if ($inventory_status eq 'queued' or
        $inventory_status eq 'aborted') {
        if (-e "${inventory_dir}/${inventory_lock_dir}/${inventory_name}") {
            unlink "${inventory_dir}/${inventory_lock_dir}/${inventory_name}";
        }
    }
        # Inventory�ե�����CLOSE
    close(INVENTORY_FILE);
}
#------------------------------------------------------------------------------#
#   ��� �ᥤ���������� ���                                                 #
#------------------------------------------------------------------------------#
# ���ޥ�ɥ饤����������å�
&check_cmdline();
# Inventory�ե��������
&Put_inventory_update();
exit 0;
