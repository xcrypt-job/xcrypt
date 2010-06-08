package sandbox;

use strict;
use builtin;
use common;
use File::Basename;
use core;

#&add_key('linkedfile', 'copiedfile', 'copieddir');

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);

    # If the working directory already exists, delete it
    if ( -e $self->{id} ) {
	print "Delete directory $self->{id}\n";
	File::Path::rmtree ($self->{id});
    }
    unless ($self->{host} eq 'localhost' || $self->{host} eq '') {
	my $ex = &xcr_exist('-d', $self->{id}, $self);
	# If the working directory already exists, delete it
	if ($ex) {
	    print "Delete directory $self->{id}\n";
	    &xcr_unlink($self->{id}, $self);
	}
    }
    &xcr_mkdir($self->{id}, $self);
    unless (-d "$self->{id}") {
	mkdir $self->{id}, 0755;
    }
    for ( my $i = 0; $i <= $user::max_exe_etc; $i++ ) {
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
	    my $ex = &xcr_exist('-f', $copied, $self);
	    if ($ex) {
		&xcr_copy($copied, $self->{id}, $self);
	    } else {
			warn "Can't copy $copied\n";
	    }
	    }
	if ($self->{"linkedfile$i"}) {
	    my $file = $self->{"linkedfile$i"};
	    &xcr_symlink($self->{id}, File::Spec->catfile($file),
			 File::Spec->catfile(basename($file)), $self);
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
	chdir $self->{id};
        $self->{request_id} = &core::qsub($self);
    }
}

sub before {}
sub after {}

1;
