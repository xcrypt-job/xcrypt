package sandbox;

use strict;

&add_key('linkedfile', 'copiedfile', 'copieddir');

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);

    $self->{workdir} = $self->{id};

    my $last_stat = &jobsched::get_job_status ($self);
    if ( jobsched::is_signaled_job ($self) ) {
	# If the job is 'xcryptdel'ed, make it 'aborted' and skip
	&jobsched::inventory_write ($self->{id}, "aborted",
				    $self->{rhost}, $self->{rwd});
	&jobsched::delete_signaled_job ($self);
    } elsif ( $last_stat eq 'done' || $last_stat eq 'finished' ) {
	# Skip if the job is 'done' or 'finished'
	if ( $last_stat eq 'finished' ) {
	    &jobsched::inventory_write ($self->{id}, "done",
					$self->{rhost}, $self->{rwd});
	}
    } else {
	# If the working directory already exists, delete it
	if ( -e $self->{workdir} ) {
	    print "Delete directory $self->{workdir}\n";
	    File::Path::rmtree ($self->{workdir});
	}
	unless ($self->{rhost} eq '') {
	    my $ex = &xcr_exist('-d', $self->{id},
				$self->{rhost}, $self->{rwd});
	    # If the working directory already exists, delete it
	    if ($ex) {
		print "Delete directory $self->{id}\n";
		&xcr_unlink($self->{id}, 'core', $self->{rhost}, $self->{rwd});
	    }
	}
	&xcr_mkdir($self->{id}, 'core', $self);
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
		    my $temp = File::Spec->catfile($self->{workdir}, $_);
		    rcopy $tmp, $temp;
		}
		}
	    # ここまでリモート実行未対応

	    if ($self->{"copiedfile$i"}) {
		    my $copied = $self->{"copiedfile$i"};
		    my $ex = &xcr_exist('-f', $copied, $self->{rhost});
		    if ($ex) {
			&xcr_copy($copied, $self->{id}, 'core', $self->{rhost}, $self->{rwd});
		    } else {
			warn "Can't copy $copied\n";
		    }
	    }
		if ($self->{"linkedfile$i"}) {
		    my $file = $self->{"linkedfile$i"};
		    &xcr_symlink($self->{id},
				 File::Spec->catfile($file),
				 File::Spec->catfile(basename($file)), 'core',
				 $self->{rhost}, $self->{rwd});
		}
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
        $self->{request_id} = &qsub($self);
    }
}

sub before {}
sub after {}

1;
