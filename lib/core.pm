package core;

use strict;
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use File::Basename;
use jobsched;

sub new {
    my $class = shift;
    my $self = shift;

    # stderr & stdout
    unless ($self->{stdofile}) {
	$self->{stdofile} = 'stdout';
    }
    unless (defined $self->{stdefile}) {
	$self->{stdefile} = 'stderr';
    }

    # ジョブをジョブごとに作成されるディレクトリで処理
    my $jobname= $self->{id};
    my $dir = $jobname;
    if ($dir eq '') { die "Can't generate any job without id\n"; }

    # 前回実行時にできたインベントリファイルがあれば反映
    &jobsched::load_inventory ($jobname);
    my $last_stat = &jobsched::get_job_status ($jobname);
    if ( jobsched::is_signaled_job ($jobname) ) {
        # xcryptdelされていたらabortにして処理をとばす
        &jobsched::inventory_write ($jobname, "aborted");
        jobsched::delete_signaled_job ($jobname);
    } elsif ( $last_stat eq 'done' || $last_stat eq 'finished' ) {
        # done, finishedになってたら処理はとばす
        if ( $last_stat eq 'finished' ) {
            &jobsched::inventory_write ($jobname, "done");
        }
    } else {
        &jobsched::inventory_write ($jobname, "active");
        # done, finished以外だったらactiveにしてジョブディレクトリを（あれば）削除
        if ( -e $dir ) {
            print "Delete directory $dir\n";
            File::Path::rmtree ($dir);
        }
        mkdir $dir , 0755;

        for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
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
    # 前回done, finishedになったジョブならとばす．
    my $stat = &jobsched::get_job_status($self->{id});
    if ( $stat eq 'done' ) {
        print "Skipping " . $self->{id} . " because already $stat.\n";
    } else {
        # print "$self->{id}: calling qsub.\n";
        $self->{request_id} = &jobsched::qsub($self);
        # print "$self->{id}: qsub finished.\n";
    }
}

sub before {
    my $self = shift;
}

sub after {
    my $self = shift;
}

1;
