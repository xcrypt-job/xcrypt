package Data_Extraction;
use Exporter;
@ISA = (Exporter);
@EXPORT = qw(EF $After);
use strict;
use File::Basename;
use Cwd;

#------------< �ϐ��̒�` >------------
my $args = undef;                                                     # �A�[�M�������g���
my $After = undef;                                                    # �I�u�W�F�N�g��

#------------------------------------------------------------------------------#
#   ���� EF(���o�t�@�C����`�R�}���h)�̒�` ����                               #
#------------------------------------------------------------------------------#
sub EF{
    ############################################
    # $_[0] = ���̓t�@�C����                   #
    # $_[1] = ���o�t�H���_��                   #
    ############################################
    my $this = (caller 1)[3];
    $this =~ s/.*:://;
    my $infile            = shift;
    my $outfile           = shift;
    my $extraction        = 0;
    my @key_datas         = ();
    my @Point_nos         = ();
    my @Range_nos         = ();
    
    # �I�u�W�F�N�g��`
    my $Job = {"this"              =>$this,                                    # �ďo���T�u���[�`����
               "infile"            =>$infile,                                  # ���`�t�@�C����
               "outfile"           =>$outfile,                                 # �����t�@�C����
               "extraction"        =>$extraction,                              # ���o�z��v�f��
               "key_datas"         =>\@key_datas,                              # ���K�\�����o�p�̒��o�����i�z��j
               "Point_nos"         =>\@Point_nos,                              # �s�ԍ��w�蒊�o�p�̋N�_�i�z��j
               "Range_nos"         =>\@Range_nos};                             # �s�ԍ��w�蒊�o�p�̏I���i�z��j
    bless $Job;
    return $Job;
}
#------------------------------------------------------------------------------#
#   ���� LE(�s�ԍ��w��R�}���h)�̒�` ����                                     #
#------------------------------------------------------------------------------#
sub LE{
    ############################################
    # $_[0] = �I�u�W�F�N�g                     #
    # $_[1] = �N�_�s�ԍ�                       #
    # $_[2] = �͈�(�I���s�ԍ� or �͈͎w��)     #
    ############################################
    # �N�_�s�ԍ��`�F�b�N
    if ($_[1] !~ 'E' and ($_[1] !~ /\d/ or $_[1] == 0)) {
        print STDERR "Starting point Line number is not a number \($_[1]\)\n";
        exit 99;
    }
    # �͈�(�I���s�ԍ� or �͈͎w��)�`�F�b�N
    if ($_[2] != '' and $_[2] != 'E' and ($_[2] !~ /\d/ or $_[2] == 0)) {
        print STDERR "End Range number is not a number \($_[2]\)\n";
        exit 99;
    }
    
    # �z��Ɋi�[
    $_[0]->{extraction}++;
    my @Point_nos = @{$_[0]->{Point_nos}};
    $Point_nos[$_[0]->{extraction}] = $_[1];
    @{$_[0]->{Point_nos}} = @Point_nos;
    my @Range_nos = @{$_[0]->{Range_nos}};
    $Range_nos[$_[0]->{extraction}] = $_[2];
    @{$_[0]->{Range_nos}} = @Range_nos;
}
#------------------------------------------------------------------------------#
#   ���� RE(���K�\���w��R�}���h)�̒�` ����                                   #
#------------------------------------------------------------------------------#
sub RE{
    ############################################
    # $_[0] = �I�u�W�F�N�g                     #
    # $_[1] = ��r�l                           #
    ############################################
    # ��r�l�`�F�b�N
    if ($_[1] eq '') {
        print STDERR "Regular expression character string is an Error \($_[1]\)\n";
        exit 99;
    }
    
    # �z��Ɋi�[
    $_[0]->{extraction}++;
    my @key_datas = @{$_[0]->{key_datas}};
    $key_datas[$_[0]->{extraction}] = $_[1];
    @{$_[0]->{key_datas}} = @key_datas;
}
#------------------------------------------------------------------------------#
#   ���� do(�u�����w���R�}���h)�̒�` ����                                     #
#------------------------------------------------------------------------------#
sub do{
    ############################################
    # $_[0] = �I�u�W�F�N�g                     #
    ############################################
    # ���̓t�@�C��OPEN
    if (!-e "$_[0]->{infile}") {
        # ���̓t�@�C������
        print STDERR "Input file($_[0]->{infile}) not found\n";
        exit 99;
    } elsif (!-r "$_[0]->{infile}") {
        # ���̓t�@�C���ɓǍ��݌�������
        print STDERR "Input file($_[0]->{infile}) is not read authority\n";
        exit 99;
    } elsif (!open (BASE_FILE, "< $_[0]->{infile}")) {
        # ���̓t�@�C��OPEN�G���[
        print STDERR "Input file($_[0]->{infile}) cannot open file\n";
        exit 99;
    }
    # ���̓t�@�C���̋��p���b�N
    flock(BASE_FILE, 1);
    
    # ���o�t�@�C��OPEN
    my $outfile = $_[0]->{outfile};
#    $outfile .= '\\'.basename($_[0]->{infile});
    $outfile .= '/'.basename($_[0]->{infile});
    if (!-d "$_[0]->{outfile}") {
        # �o�̓f�B���N�g������
        print STDERR "Output file directory($_[0]->{outfile}) not found\n";
        exit 99;
    } elsif (!-w "$_[0]->{outfile}") {
        # �o�̓f�B���N�g���ɏ����݌�������
        print STDERR "Output file directory($_[0]->{outfile}) is not write authority\n";
        exit 99;
    } elsif (-e "$outfile" and !-w "$outfile") {
        # �o�̓t�@�C���ɏ����݌�������
        print STDERR "Output file($outfile) is not write authority\n";
        exit 99;
    } elsif (!open (EXTRACTION_FILE, "+> $outfile")) {
        # �o�̓t�@�C��OPEN�G���[
        print STDERR "Output file($outfile) cannot open file\n";
        exit 99;
    }
    # ���o�t�@�C���̔r�����b�N
    flock(EXTRACTION_FILE, 2);
    
    # ���̓f�[�^��z��ɑޔ�
    my $line_cnt    = 0;
    my @input_datas = ();
    while (<BASE_FILE>){
        $line_cnt++;
        $input_datas[$line_cnt] = "$_";
    }
    
    # ���o�͈͂��m��
    for (my $index1=1 ; $index1 <= $_[0]->{extraction}; $index1++) {
        if (${$_[0]->{Point_nos}}[$index1] eq 'E') {
            ${$_[0]->{Point_nos}}[$index1] = $line_cnt;
        }
        if (${$_[0]->{Range_nos}}[$index1] eq 'E') {
            ${$_[0]->{Range_nos}}[$index1] = $line_cnt;
        }
        if (${$_[0]->{Range_nos}}[$index1] ne '') {
            my $Range_kbn = substr ${$_[0]->{Range_nos}}[$index1], 0, 1;
            if ($Range_kbn eq "\-") {
                my $end_line = ${$_[0]->{Point_nos}}[$index1];
                ${$_[0]->{Point_nos}}[$index1] = ${$_[0]->{Point_nos}}[$index1] + ${$_[0]->{Range_nos}}[$index1];
                ${$_[0]->{Range_nos}}[$index1] = $end_line;
            } elsif ($Range_kbn eq "\+") {
                ${$_[0]->{Range_nos}}[$index1] = ${$_[0]->{Point_nos}}[$index1] + ${$_[0]->{Range_nos}}[$index1];
            }
        }
    }
    
    # ���o���s��
    for (my $index1=1 ; $index1 <= $line_cnt; $index1++) {
        # ���o����
        my $extraction_kbn = '';
        #my $key_data    = '';
        for (my $index2=1 ; $index2 <= $_[0]->{extraction} && $extraction_kbn eq ''; $index2++) {
            # �s�w��ɂ�钊�o
            if (${$_[0]->{Point_nos}}[$index2] ne '') {
                if (${$_[0]->{Range_nos}}[$index2] eq '' and ${$_[0]->{Point_nos}}[$index2] == $index1) {
                    $extraction_kbn = '1';
                    next;
                } elsif (${$_[0]->{Point_nos}}[$index2] <= $index1 and ${$_[0]->{Range_nos}}[$index2] >= $index1) {
                    $extraction_kbn = '1';
                    next;
                }
            }
            # ���K�\���ɂ�钊�o
            if (${$_[0]->{key_datas}}[$index2] ne '' and $input_datas[$index1] =~ /${$_[0]->{key_datas}}[$index2]/) {
                $extraction_kbn = '1';
                next;
            }
        }
        
        # ���o�Ώۂ̏o��
        if ($extraction_kbn eq '1') {
            print EXTRACTION_FILE "$input_datas[$index1]";
        }
    }
    
    close(EXTRACTION_FILE);
    close(BASE_FILE);
}
1;
