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
    my $copied;
    if ($self->{dir}) {
	$copied = File::Spec->catfile($self->{dir}, $self->{ifile});
#	$self->{input} = &Data_Generation::CF($copied, $dir);
	copy $copied, $dir;
    } else {
	$copied = $self->{ifile};
	$self->{input} = &Data_Generation::CF($copied, $dir);
    }
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
    my $stdout = File::Spec->catfile($dir, 'stdout');
    if ($self->{stdout}) { $stdout = $self->{stdout}; }
    my $stderr = File::Spec->catfile($dir, 'stderr');
    if ($self->{stderr}) { $stderr = $self->{stderr}; }
    my $process = 1;
    if ($self->{process}) { $process = $self->{process}; }
    my $cpu = 1;
    if ($self->{cpu}) { $process = $self->{cpu}; }
    &jobsched::qsub($self->{id},
		    $cmd,
		    $self->{id},
		    $nqs_script,
		    $self->{queue},
		    $self->{option},
		    $stdout,
		    $stderr,
		    $process,
		    $cpu);
    # 結果ファイルから結果を取得
    # 拾い方をユーザに書かせないといけないけどどのようにする？
    &jobsched::wait_job_done($self->{id});
    my @stdlist = &pickup($stdout, ',');
    $self->{stdoutput} = $stdlist[0];

    $self->after();
}

sub before {
    my $self = shift;
    unless ($self->{dir}) {
	$self->{input}->do();
    }
    my $exe = $self->{exe};
    my $dir = $self->{id};
    if ( -e $exe ) {
	symlink File::Spec->catfile('..',  $exe), File::Spec->catfile($dir, $exe);
    }
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
