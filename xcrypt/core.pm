package core;

use strict;
use Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use UI;
use function;
use jobsched;
use Data_Generation;

sub new {
    my $class = shift;
    my $self = shift;
    # ジョブをジョブごとに作成されるディレクトリで処理
    my $dir = $self->{id};
    my $dotdir = '.' . $dir;

    # 前回実行時にできたインベントリファイルがあれば反映
    &jobsched::load_inventory ($self->{id});
    # doneになってたら処理はとばす
    unless ( &jobsched::get_job_status ($self->{id}) eq 'done') {
        # done以外だったらactiveにしてジョブディレクトリを（あれば）削除
        &jobsched::set_job_status ($self->{id}, 'active');
        if ( -e $dir ) {
            print "Delete directory $dir\n";
            File::Path::rmtree ($dir);
        }

	if ( -e $dotdir ) {
            print "Delete directory $dotdir\n";
	    File::Path::rmtree ($dotdir);
	}
        mkdir $dotdir , 0755;

        for ( my $i = 0; $i <= $user::max; $i++ ) {
            if ($self->{"copieddir$i"}) {
                my $copied = $self->{"copieddir$i"};
                opendir(DIR, $copied);
                my @params = grep { !m/^(\.|\.\.)/g } readdir(DIR);
                closedir(DIR);
                foreach (@params) {
                    my $tmp = File::Spec->catfile($copied, $_);
                    my $temp = File::Spec->catfile($dotdir, $_);
                    rcopy $tmp, $temp;
                }
            }
            if ($self->{"copiedfile$i"}) {
#	    $self->{"input$i"} = &Data_Generation::CF($self->{"copiedfile$i"}, $dotdir);
                fcopy $self->{"copiedfile$i"}, $dotdir;
            }
            if ($self->{"linkedfile$i"}) {
                my $link = File::Spec->catfile($dotdir, $self->{"linkedfile$i"});
                my $file = File::Spec->catfile('..', $self->{"linkedfile$i"});
                symlink($file, $link) or warn "Can't link to $file";
            }
        }
	if ( -e $dir ) {
            print "Delete directory $dir\n";
	    File::Path::rmtree ($dir);
	}
        rename $dotdir, $dir;
    }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $dir = $self->{id};

    $self->before();

    # NQS スクリプトを作成・投入

    # 前回doneになったジョブならとばす．
    if ( &jobsched::get_job_status ($self->{id}) eq 'done') {
        print "Skipping " . $self->{id} . " because already done.\n";
    } else {
#        $self->{request_id} = &jobsched::qsub($self);
        $self->{request_id} = &jobsched::qsub($self);
        jobsched::set_job_request_id ($self->{id}, $self->{request_id});
#    print $self->{id} . " is submitted.\n";

        # 結果ファイルから結果を取得
        &jobsched::wait_job_done($self->{id});
#    print $self->{id} . " is done.\n";

        my $stdofile = 'stdout';
        unless ($self->{stdofile} eq '') { $stdofile = $self->{stdofile}; }
        my $hoge = File::Spec->catfile($self->{id}, $stdofile);

        until (-e $hoge) { sleep 2; }
        my @stdlist = &pickup($hoge, ',');
        $self->{stdout} = $stdlist[0];
    }

    $self->after();
}

sub before {
    my $self = shift;
    foreach (@{$self->{predecessor}}) {
	&jobsched::wait_job_done($_);
    }
}

sub after {
    my $self = shift;

    my @thrds = ();
    foreach (@{$self->{successor}}) {
	no strict 'refs';
	my $foo = 'user::' . $_;
	my %bar = %$foo;
	my $obj = user->new(\%bar);
	my $thrd = threads->new(\&start, $obj);
	push(@thrds , $thrd);
    }
    foreach (@thrds) { $_->join; }

    my $dir = $self->{id};
    unless ($self->{ofile}) {}
    else {
	my $outputfile = File::Spec->catfile($dir, $self->{ofile});
	my @list = &pickup($outputfile, $self->{odlmtr});
	$self->{output} = $list[$self->{oclmn}];
	unshift (@{$self->{trace}} , $list[$self->{oclmn}]);
    }

    # exit_cond により生成されるジョブの結果もディレクトリ以下に保存
=comment
    my $tracelog_filename = 'trace.log';
    my $tracelog = File::Spec->catfile($dir, $tracelog_filename);
    open ( EXITOUTPUT , ">> $tracelog" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
=cut
}

1;
