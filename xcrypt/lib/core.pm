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

    # ����֤򥸥�֤��Ȥ˺��������ǥ��쥯�ȥ�ǽ���
    my $dir = $self->{id};
    my $dotdir;
    if ($dir eq '') {
	die "Can't generate any job without id\n";
    } else {
	$dotdir = '.' . $dir;
    }

    # ����¹Ի��ˤǤ�������٥�ȥ�ե����뤬�����ȿ��
    &jobsched::load_inventory ($self->{id});
    # done�ˤʤäƤ�������ϤȤФ�
    unless ( &jobsched::get_job_status ($self->{id}) eq 'done') {
        # done�ʳ����ä���active�ˤ��ƥ���֥ǥ��쥯�ȥ��ʤ���С˺��
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

    # NQS ������ץȤ����������

    # ����done�ˤʤä�����֤ʤ�ȤФ���
    if ( &jobsched::get_job_status ($self->{id}) eq 'done') {
        print "Skipping " . $self->{id} . " because already done.\n";
    } else {
        $self->{request_id} = &jobsched::qsub($self);
        # ��̥ե����뤫���̤����
        &jobsched::wait_job_done($self->{id});

        my $stdofile = 'stdout';
        unless ($self->{stdofile} eq '') { $stdofile = $self->{stdofile}; }
        my $hoge = File::Spec->catfile($self->{id}, $stdofile);

	# NFS�ν�����ٱ���Ф������Ū�б�
	sleep(3);

        until ( (-e $hoge) or ($jobsched::job_status{$self->{id}} eq 'abort')  ) {
	    sleep 1;
	}
        my @stdlist = &pickup($hoge, $self->{stdodlmtr});
        $self->{stdout} = $stdlist[$self->{stdoclmn}];
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

    # exit_cond �ˤ����������른��֤η�̤�ǥ��쥯�ȥ�ʲ�����¸
=comment
    my $tracelog_filename = 'trace.log';
    my $tracelog = File::Spec->catfile($dir, $tracelog_filename);
    open ( EXITOUTPUT , ">> $tracelog" );
    print EXITOUTPUT join (' ', @{$self->{trace}}), "\n";
    close ( EXITOUTPUT );
=cut
}

1;
