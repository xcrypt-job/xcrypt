package sandbox;

use strict;
use builtin;
use common;
use File::Basename;
use core;

my $max_of_added_key = 15;
foreach (0..15) {
    &add_key("linkedfile$_", "copiedfile$_", "copieddir$_");
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);

    $self->{workdir} = $self->{id};
=comment
    # If the working directory already exists, delete it
    my $ex = &xcr_exist($self->{env}, $self->{id});
    if ($ex) {
	print "Delete directory $self->{id}\n";
	&xcr_rmtree($self->{id}, $self->{env});
    }
=cut
    mkdir $self->{workdir}, 0755;
    &xcr_mkdir($self->{env}, $self->{workdir});

    for ( my $i = 0; $i <= $max_of_added_key; $i++ ) {
	# ここからリモート実行未対応
	if ($self->{"copieddir$i"}) {
	    my $copied = $self->{"copieddir$i"};
	    opendir(DIR, $copied);
	    my @params = grep { !m/^(\.|\.\.)/g } readdir(DIR);
	    closedir(DIR);
	    foreach (@params) {
		my $tmp = File::Spec->catfile($copied, $_);
		my $temp = File::Spec->catfile($self->{workdir}, $_);
		rcopy $tmp, $temp;
	    }
	}
	# ここまでリモート実行未対応

	if ($self->{"copiedfile$i"}) {
	    my $copied = $self->{"copiedfile$i"};
#	    my $ex = &xcr_exist($self->{env}, $copied);
	    &xcr_copy($self->{env}, $copied, $self->{workdir});
	}
	if ($self->{"linkedfile$i"}) {
	    my $file = $self->{"linkedfile$i"};
	    &xcr_symlink($self->{env}, $self->{workdir},
			 File::Spec->catfile('..', $file),
			 File::Spec->catfile(basename($file)));
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
        &core::qsub_make($self);
        $self->{request_id} = &core::qsub($self);
    }
}

sub before {}
sub after {}

1;
