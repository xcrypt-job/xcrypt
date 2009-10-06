package core;

use strict;
use Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use File::Basename;
use jobsched;

sub new {
    my $class = shift;
    my $self = shift;

    # ����֤򥸥�֤��Ȥ˺��������ǥ��쥯�ȥ�ǽ���
    my $dir = $self->{id};
    if ($dir eq '') { die "Can't generate any job without id\n"; }

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
                my $prelink = File::Spec->catfile(basename($self->{"linkedfile$i"}));
                my $link = File::Spec->catfile($dir, $prelink);
                my $file1 = $self->{"linkedfile$i"};
                my $file2 = File::Spec->catfile('..', $self->{"linkedfile$i"});
		if ( -e $file1 ) {
		    print $link, "\n";
		    print $file2, "\n";
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

    # ����done�ˤʤä�����֤ʤ�ȤФ���
    if ( &jobsched::get_job_status ($self->{id}) eq 'done') {
        print "Skipping " . $self->{id} . " because already done.\n";
    } else {
        $self->{request_id} = &jobsched::qsub($self);
	&jobsched::wait_job_done($self->{id});
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
}

1;
