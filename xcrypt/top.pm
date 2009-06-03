package top;

use File::Copy;
use File::Spec;
use UI;
use function;
use jobsched;
use Data_Generation;

sub new {
    my $class = shift;
    my $self = shift;
    # ジョブをジョブごとに作成されるディレクトリで処理
    my $dir = $self->{id};
    mkdir $dir , 0755;
#    unless ($self->{input_arg_dirname} eq '') {
#	my $hoge = $self->{input_arg_dirname} . "/" . $self->{ifile};
    $self->{input} = &Data_Generation::CF($self->{ifile}, $dir);
#    }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $dir = $self->{id};
    unless (-e $dir) { mkdir $dir , 0755; }

    $self->before();

    # NQS スクリプトを作成・投入
    my $nqs_script = File::Spec->catfile($dir, 'nqs.sh');
    my $cmd = $self->{exe} . " $self->{arg1} $self->{arg2}";
    my $stdoutfile = File::Spec->catfile($dir, 'stdout');
    if ($self->{stdout_file}) { $stdoutfile = $self->{stdout_file}; }
    my $stderrfile = File::Spec->catfile($dir, 'stderr');
    if ($self->{stderr_file}) { $stderrfile = $self->{stderr_file}; }
    &jobsched::qsub($self->{id},
		    $cmd,
		    $self->{id},
		    $nqs_script,
		    $self->{queue},
		    $self->{option},
		    $stdoutfile,
		    $stderrfile);
    # 結果ファイルから結果を取得
    # 拾い方をユーザに書かせないといけないけどどのようにする？
    &jobsched::wait_job_done($self->{id});
    my @stdlist = &pickup($stdoutfile, ',');
    $self->{stdout} = $stdlist[0];

    $self->after();
}

sub before {
    my $self = shift;
    $self->{input}->do();
    my $exe = $self->{exe};
    my $dir = $self->{id};
    if ( -e $exe ) { symlink File::Spec->catfile('..',  $exe), File::Spec->catfile($dir, $exe); }
}

sub after {
    my $self = shift;
    my $dir = $self->{id};
    unless ($self->{ofile}) {}
    else {
	my $outputfile = File::Spec->catfile($dir, $self->{ofile});
	my @list = &pickup($outputfile, $self->{odelimiter});
	$self->{output} = $list[$self->{ocolumn}];
	unshift (@{$self->{trace}} , $list[$self->{ocolumn}]);
    }
    # exit_cond により生成されるジョブの結果もディレクトリ以下に保存
    my $tracelog_filename = 'trace.log';
    my $tracelog = File::Spec->catfile($dir, $tracelog_filename);
    open ( EXITOUTPUT , ">> $tracelog" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
}

1;
