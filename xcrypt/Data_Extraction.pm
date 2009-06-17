package Data_Extraction;
use Exporter;
@ISA = (Exporter);
@EXPORT = qw(EF $After);
use strict;
use File::Basename;
use Cwd;

#------------< 変数の定義 >------------
my $args = undef;                                                     # アーギュメント情報
my $After = undef;                                                    # オブジェクト名

#------------------------------------------------------------------------------#
#   ＜＜ EF(抽出ファイル定義コマンド)の定義 ＞＞                               #
#------------------------------------------------------------------------------#
sub EF{
    ############################################
    # $_[0] = 入力ファイル名                   #
    # $_[1] = 抽出フォルダ名                   #
    ############################################
    my $this = (caller 1)[3];
    $this =~ s/.*:://;
    my $infile            = shift;
    my $outfile           = shift;
    my $extraction        = 0;
    my @key_datas         = ();
    my @Point_nos         = ();
    my @Range_nos         = ();
    
    # オブジェクト定義
    my $Job = {"this"              =>$this,                                    # 呼出しサブルーチン名
               "infile"            =>$infile,                                  # 雛形ファイル名
               "outfile"           =>$outfile,                                 # 生成ファイル名
               "extraction"        =>$extraction,                              # 抽出配列要素数
               "key_datas"         =>\@key_datas,                              # 正規表現抽出用の抽出条件（配列）
               "Point_nos"         =>\@Point_nos,                              # 行番号指定抽出用の起点（配列）
               "Range_nos"         =>\@Range_nos};                             # 行番号指定抽出用の終了（配列）
    bless $Job;
    return $Job;
}
#------------------------------------------------------------------------------#
#   ＜＜ LE(行番号指定コマンド)の定義 ＞＞                                     #
#------------------------------------------------------------------------------#
sub LE{
    ############################################
    # $_[0] = オブジェクト                     #
    # $_[1] = 起点行番号                       #
    # $_[2] = 範囲(終了行番号 or 範囲指定)     #
    ############################################
    # 起点行番号チェック
    if ($_[1] !~ 'E' and ($_[1] !~ /\d/ or $_[1] == 0)) {
        print STDERR "Starting point Line number is not a number \($_[1]\)\n";
        exit 99;
    }
    # 範囲(終了行番号 or 範囲指定)チェック
    if ($_[2] != '' and $_[2] != 'E' and ($_[2] !~ /\d/ or $_[2] == 0)) {
        print STDERR "End Range number is not a number \($_[2]\)\n";
        exit 99;
    }
    
    # 配列に格納
    $_[0]->{extraction}++;
    my @Point_nos = @{$_[0]->{Point_nos}};
    $Point_nos[$_[0]->{extraction}] = $_[1];
    @{$_[0]->{Point_nos}} = @Point_nos;
    my @Range_nos = @{$_[0]->{Range_nos}};
    $Range_nos[$_[0]->{extraction}] = $_[2];
    @{$_[0]->{Range_nos}} = @Range_nos;
}
#------------------------------------------------------------------------------#
#   ＜＜ RE(正規表現指定コマンド)の定義 ＞＞                                   #
#------------------------------------------------------------------------------#
sub RE{
    ############################################
    # $_[0] = オブジェクト                     #
    # $_[1] = 比較値                           #
    ############################################
    # 比較値チェック
    if ($_[1] eq '') {
        print STDERR "Regular expression character string is an Error \($_[1]\)\n";
        exit 99;
    }
    
    # 配列に格納
    $_[0]->{extraction}++;
    my @key_datas = @{$_[0]->{key_datas}};
    $key_datas[$_[0]->{extraction}] = $_[1];
    @{$_[0]->{key_datas}} = @key_datas;
}
#------------------------------------------------------------------------------#
#   ＜＜ do(置換え指示コマンド)の定義 ＞＞                                     #
#------------------------------------------------------------------------------#
sub do{
    ############################################
    # $_[0] = オブジェクト                     #
    ############################################
    # 入力ファイルOPEN
    if (!-e "$_[0]->{infile}") {
        # 入力ファイル無し
        print STDERR "Input file($_[0]->{infile}) not found\n";
        exit 99;
    } elsif (!-r "$_[0]->{infile}") {
        # 入力ファイルに読込み権限無し
        print STDERR "Input file($_[0]->{infile}) is not read authority\n";
        exit 99;
    } elsif (!open (BASE_FILE, "< $_[0]->{infile}")) {
        # 入力ファイルOPENエラー
        print STDERR "Input file($_[0]->{infile}) cannot open file\n";
        exit 99;
    }
    # 入力ファイルの共用ロック
    flock(BASE_FILE, 1);
    
    # 抽出ファイルOPEN
    my $outfile = $_[0]->{outfile};
#    $outfile .= '\\'.basename($_[0]->{infile});
    $outfile .= '/'.basename($_[0]->{infile});
    if (!-d "$_[0]->{outfile}") {
        # 出力ディレクトリ無し
        print STDERR "Output file directory($_[0]->{outfile}) not found\n";
        exit 99;
    } elsif (!-w "$_[0]->{outfile}") {
        # 出力ディレクトリに書込み権限無し
        print STDERR "Output file directory($_[0]->{outfile}) is not write authority\n";
        exit 99;
    } elsif (-e "$outfile" and !-w "$outfile") {
        # 出力ファイルに書込み権限無し
        print STDERR "Output file($outfile) is not write authority\n";
        exit 99;
    } elsif (!open (EXTRACTION_FILE, "+> $outfile")) {
        # 出力ファイルOPENエラー
        print STDERR "Output file($outfile) cannot open file\n";
        exit 99;
    }
    # 抽出ファイルの排他ロック
    flock(EXTRACTION_FILE, 2);
    
    # 入力データを配列に退避
    my $line_cnt    = 0;
    my @input_datas = ();
    while (<BASE_FILE>){
        $line_cnt++;
        $input_datas[$line_cnt] = "$_";
    }
    
    # 抽出範囲を確定
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
    
    # 抽出を行う
    for (my $index1=1 ; $index1 <= $line_cnt; $index1++) {
        # 抽出判定
        my $extraction_kbn = '';
        #my $key_data    = '';
        for (my $index2=1 ; $index2 <= $_[0]->{extraction} && $extraction_kbn eq ''; $index2++) {
            # 行指定による抽出
            if (${$_[0]->{Point_nos}}[$index2] ne '') {
                if (${$_[0]->{Range_nos}}[$index2] eq '' and ${$_[0]->{Point_nos}}[$index2] == $index1) {
                    $extraction_kbn = '1';
                    next;
                } elsif (${$_[0]->{Point_nos}}[$index2] <= $index1 and ${$_[0]->{Range_nos}}[$index2] >= $index1) {
                    $extraction_kbn = '1';
                    next;
                }
            }
            # 正規表現による抽出
            if (${$_[0]->{key_datas}}[$index2] ne '' and $input_datas[$index1] =~ /${$_[0]->{key_datas}}[$index2]/) {
                $extraction_kbn = '1';
                next;
            }
        }
        
        # 抽出対象の出力
        if ($extraction_kbn eq '1') {
            print EXTRACTION_FILE "$input_datas[$index1]";
        }
    }
    
    close(EXTRACTION_FILE);
    close(BASE_FILE);
}
1;
