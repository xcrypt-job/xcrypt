package sandbox;

use strict;
use builtin;
use common;
use File::Basename;
use core;

&add_keys('linkedfile', 'copiedfile', 'copieddir');

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);

=comment
    # If the working directory already exists, delete it
    my $ex = &xcr_exist('-d', $self->{id}, $self->{env});
    if ($ex) {
	print "Delete directory $self->{id}\n";
	&xcr_rmtree($self->{id}, $self->{env});
    }
=cut
    &xcr_mkdir($self->{id}, $self->{env});

    for ( my $i = 0; $i <= $user::max_exe; $i++ ) {
	# ここからリモート実行未対応
	if ($self->{"copieddir$i"}) {
	    my $copied = $self->{"copieddir$i"};
	    opendir(DIR, $copied);
	    my @params = grep { !m/^(\.|\.\.)/g } readdir(DIR);
	    closedir(DIR);
	    foreach (@params) {
		my $tmp = File::Spec->catfile($copied, $_);
		my $temp = File::Spec->catfile($self->{id}, $_);
		rcopy $tmp, $temp;
	    }
	}
	# ここまでリモート実行未対応

	if ($self->{"copiedfile$i"}) {
	    my $copied = $self->{"copiedfile$i"};
	    my $ex = &xcr_exist('-f', $copied, $self->{env});
	    if ($ex) {
		&xcr_copy($copied, $self->{id}, $self->{env});
	    } else {
			warn "Can't copy $copied\n";
	    }
	    }
	if ($self->{"linkedfile$i"}) {
	    my $file = $self->{"linkedfile$i"};
	    &xcr_symlink($self->{id}, File::Spec->catfile($file),
			 File::Spec->catfile(basename($file)), $self->{env});
	}
    }
    return bless $self, $class;
}

sub start {
    my $self = shift;

    # Skip if the job is done or finished in the previous execution
    # ↑ 「finishedも」というのはコメントの書き間違い？
    my $stat = &jobsched::get_job_status($self);
    if ( $stat eq 'done' ) {
        print "Skipping " . $self->{id} . " because already $stat.\n";
    } else {
        $self->{workdir} = File::Spec->catfile($self->{workdir}, $self->{id});
        &core::qsub_make($self);
        $self->{request_id} = &core::qsub($self);
    }
}

sub before {}
sub after {}

1;
