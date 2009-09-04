package core;

use strict;
use Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use UI;
use jobsched;

sub new {
    my $class = shift;
    my $self = shift;

    # ジョブをジョブごとに作成されるディレクトリで処理
    my $dir = $self->{id};
    if ($dir eq '') { die "Can't generate any job without id\n"; }

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
        mkdir $dir , 0755;

        for ( my $i = 0; $i <= $user::max; $i++ ) {
            if ($self->{"copieddir$i"}) {
                my $copied = $self->{"copieddir$i"};
                opendir(DIR, $copied);
                my @params = grep { !m/^(\.|\.\.)/g } readdir(DIR);
                closedir(DIR);
                foreach (@params) {
                    my $tmp = File::Spec->catfile($copied, $_);
                    my $temp = File::Spec->catfile($dir, $_);
                    rcopy $tmp, $temp;
                }
            }

            if ($self->{"copiedfile$i"}) {
                my $copied = $self->{"copiedfile$i"};
		if ( -e $copied ) {
		    fcopy($copied, $dir);
		} else {
		    warn "Can't copy $copied\n";
		}
            }
            if ($self->{"linkedfile$i"}) {
                my $link = File::Spec->catfile($dir, $self->{"linkedfile$i"});
                my $file1 = $self->{"linkedfile$i"};
                my $file2 = File::Spec->catfile('..', $self->{"linkedfile$i"});
		if ( -e $file1 ) {
		    symlink($file2, $link);
		} else {
		    warn "Can't link to $file1";
		}
            }
        }
    }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $dir = $self->{id};

    # 前回doneになったジョブならとばす．
    if ( &jobsched::get_job_status ($self->{id}) eq 'done') {
        print "Skipping " . $self->{id} . " because already done.\n";
    } else {
        $self->{request_id} = &jobsched::qsub($self);

    # 結果ファイルから結果を取得
    &jobsched::wait_job_done($self->{id});

    my $stdofile = 'stdout';
    unless ($self->{stdofile} eq '') { $stdofile = $self->{stdofile}; }

    # NFSの書込み遅延に対する暫定的対応
    sleep(3);

    my $pwdstdo = File::Spec->catfile($self->{id}, $stdofile);
    until ((-e $pwdstdo) or ($jobsched::job_status{$self->{id}} eq 'aborted')) {
	sleep 1;
    }
    unless ($self->{stdodlmtr}) { $self->{stdodlmtr} = ','; }
    unless ($self->{stdoclmn}) { $self->{stdoclmn} = '0'; }
    my @stdlist = &pickup($pwdstdo, $self->{stdodlmtr});
    $self->{stdout} = $stdlist[$self->{stdoclmn}];
    }
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
