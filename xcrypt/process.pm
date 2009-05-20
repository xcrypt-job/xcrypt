package process;

use File::Copy;
use jobsched;

my $tracelog_file = 'trace.log';

sub new {
    my $class = shift;
=comment
    my $self = {
    'id' => '',
    'predecessors' => [],
    'exe' => '',
    'arg1' => [],
    'arg2' => [],
    'input_file' => '',
    'output_file' => '',
    'output_column' => 0,
    'delimiter' => ',',
    'option' => '# @$-q eh',
    'trace' => [],
    'exit_cond' => sub { &function::tautology; },
    'successors' => []
    };
=cut
    my $self = shift;
    return bless $self, $class;
}

sub start {
    my $self = shift;

    $self->before();

    my $dir = $self->{id} . '/';

    # ジョブをジョブごとに作成されるディレクトリで処理
    mkdir $dir , 0755;
    my $inputfile = $self->{input_file};
    if ( -e $inputfile ) { copy( $inputfile , $dir . $inputfile ); }
    my $exe = $self->{exe};
    if ( -e $exe ) { symlink '../' . $exe , $dir . $exe; }

    # NQS スクリプトを作成・投入
    my $nqs_script = $dir . 'nqs.sh';
    my $cmd = $self->{exe} . " $self->{arg1} $self->{arg2}";
    &jobsched::qsub($self->{id}, $cmd, $self->{id}, $nqs_script, $self->{option});

    # 結果ファイルから結果を取得
    # 拾い方をユーザに書かせないといけないけどどのようにする？
    my $outputfile = $dir . $self->{output_file};
    unless ($self->{output_file}) {}
    else {
	until ( -e $outputfile ) {
	    sleep(1);
	}
	open ( OUTPUT , "< $outputfile" );
	my $line = <OUTPUT>;
	my $delimiter = $self->{delimiter};
	my @list = split(/$delimiter/, $line);
	close ( OUTPUT );
	$self->{output} = $list[$self->{output_column}];
	unshift (@{$self->{trace}} , $list[$self->{output_column}]);
    }

    $self->after();

    # exit_cond により生成されるジョブの結果もディレクトリ以下に保存
    my $hoge = $dir . $tracelog_file;
    open ( EXITOUTPUT , ">> $hoge" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
}

sub before {}

sub after {}

1;
