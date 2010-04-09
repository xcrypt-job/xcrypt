package core;

use strict;
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use File::Basename;
use Data::Dumper;

use jobsched;
use jsconfig;
use xcropt;
use common;

sub new {
    my $class = shift;
    my $self = shift;

    # stderr & stdout
    set_member_if_empty ($self, 'JS_stdout', 'stdout');
    set_member_if_empty ($self, 'JS_stderr', 'stderr');

    # Check if the job ID is not empty
    my $jobname= $self->{id};
    if ($jobname eq '') { die "Can't generate any job without id\n"; }
    # Absolute path of the working directory
#    $self->{workdir} = File::Spec->rel2abs($jobname);
    $self->{workdir} = $jobname;

    # Job script related members
    set_member_if_empty ($self, 'rhost', ${$xcropt::options{rhost}}[0]);
    set_member_if_empty ($self, 'rwd', ${$xcropt::options{rwd}}[0]);
    set_member_if_empty ($self, 'rsched', ${$xcropt::options{rsched}}[0]);

    set_member_if_empty ($self, 'jobscript_header', []);
    set_member_if_empty ($self, 'jobscript_body', []);
    set_member_if_empty ($self, 'job_scheduler', $xcropt::options{scheduler});
    set_member_if_empty ($self, 'jobscript_file', $self->{job_scheduler}.'.sh');
    set_member_if_empty ($self, 'before_in_job_file', 'before_in_job.pl');
    set_member_if_empty ($self, 'after_in_job_file', 'after_in_job.pl');
    set_member_if_empty ($self, 'qsub_options', []);

    # Load the inventory file to recover the job's status after the previous execution
    &jobsched::load_inventory ($jobname);
    my $last_stat = &jobsched::get_job_status ($jobname);
    if ( jobsched::is_signaled_job ($jobname) ) {
        # If the job is 'xcryptdel'ed, make it 'aborted' and skip
        &jobsched::inventory_write ($jobname, "aborted");
       jobsched::delete_signaled_job ($jobname);
    } elsif ( $last_stat eq 'done' || $last_stat eq 'finished' ) {
        # Skip if the job is 'done' or 'finished'
        if ( $last_stat eq 'finished' ) {
	    &jobsched::inventory_write ($jobname, "done",);
        }
    } else {
        # If the working directory already exists, delete it
        if ( -e $self->{workdir} ) {
            print "Delete directory $self->{workdir}\n";
            File::Path::rmtree ($self->{workdir});
        }
	unless ($self->{rhost} eq '') {
	    my $ex = &xcr_exist('-d', $self->{id}, $self->{rhost}, $self->{rwd});
	    if ($ex) {
		print "Delete directory $self->{id}\n";
		File::Path::rmtree($self->{id});
	    }
	}
	&xcr_mkdir($self->{id}, $self->{rhost}, $self->{rwd});
	unless (-d "$jobname") {
	    mkdir $jobname, 0755;
	}
        # Otherwise, make the job 'active'
	&jobsched::inventory_write ($jobname, "active");

        for ( my $i = 0; $i <= $user::max_exe_etc; $i++ ) {
	    # リモート実行未対応
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

            if ($self->{"copiedfile$i"}) {
                my $copied = $self->{"copiedfile$i"};
		my $ex = &xcr_exist('-f', $copied, $self->{rhost});
		if ($ex) {
		    &xcr_copy($copied, $self->{'id'}, $self->{rhost}, $self->{rwd});
		} else {
		    warn "Can't copy $copied\n";
		}
            }
            if ($self->{"linkedfile$i"}) {
                my $file = $self->{"linkedfile$i"};
		&xcr_symlink($self->{id},
			     File::Spec->catfile($file),
			     File::Spec->catfile(basename($file)),
			     $self->{rhost},
			     $self->{rwd});
            }
        }
    }
    return bless $self, $class;
}

sub start {
    my $self = shift;
    # Skip if the job is done or finished in the previous execution
    my $stat = &jobsched::get_job_status($self->{id});
    if ( $stat eq 'done' ) {
        print "Skipping " . $self->{id} . " because already $stat.\n";
    } else {
        # print "$self->{id}: calling qsub.\n";
        $self->{request_id} = &jobsched::qsub($self);
        # print "$self->{id}: qsub finished.\n";
    }
}

sub workdir_file {
    my $self = shift;
    my $basename = shift;
    return File::Spec->catfile($self->{id}, $basename);
}

sub workdir_member_file {
    my $self = shift;
    my $member = shift;
    unless ($self->{$member}) {
        warn "The job object $self->{id} does not have a member '$member'";
    }
    return $self->workdir_file($self->{$member});
}

# not a method
sub apply_push_if_valid_arg ($&@) {
    my ($arrayref, $func, @args) = @_;
    foreach (@args) {
        unless ($_) {return 0;}
    }
    push (@{$arrayref}, &$func(@args));
}

# Create a job script from information of the job object.
# The result is stored in @{$self->{jobscript_header}} and @{$self->{jobscript_body}}
sub make_jobscript {
    my $self = shift;
    $self->make_jobscript_header($self);
    $self->make_jobscript_body($self);
}

sub make_jobscript_header {
    my $self = shift;
    my @header = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{job_scheduler}}};
    ## preamble
    my $preamble = $cfg{jobscript_preamble};
    if ( ref($preamble) eq 'CODE' ) {
        push (@header, &$preamble($self));
    } else {
        push (@header, @{mkarray($preamble)});
    }
    ## Options
    foreach my $k (keys %cfg) {
        if ( $k =~ /^jobscript_option_(.*)/ ) {
            my $v = $cfg{$k};
            my $optname = $1;
            my $mb_name = "JS_$1";
            # $v must be String or (Job*String)->String[]
            unless ( ref($v) ) {
                if (defined $self->{$mb_name}) {
                    push (@header, $v . $self->{$mb_name});
                }
            } elsif ( ref($v) eq 'CODE' ) {
                my @ret = &$v($self, $mb_name);
                push (@header, @ret);
            } else {
                warn "Error in config file $self->{job_scheduler}: $k is neither scalar nor CODE."
            }
        }
    }
    $self->{jobscript_header} = \@header;
}

sub make_jobscript_body {
    my $self = shift;
    my @body = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{job_scheduler}}};
    ## Job script body
    # Chdir to the job's working directory
    my $wkdir_str = $self->{workdir};
    if (defined ($cfg{jobscript_workdir})) {
        my $js_wkdir = $cfg{jobscript_workdir};
        unless ( ref($js_wkdir) ) {
            $wkdir_str = $js_wkdir;
        } elsif ( ref($js_wkdir) eq 'CODE' ) {
            $wkdir_str = &$js_wkdir($self);
        } else {
            warn "Error in config file $self->{job_scheduler}: jobscript_workdir is neither scalar nor CODE."
        }
    }
    unless ($self->{rhost} eq '') {
	$wkdir_str = File::Spec->catfile($self->{rwd}, $wkdir_str);
    } else {
	$wkdir_str = File::Spec->rel2abs($wkdir_str);
    }
    push (@body, "cd ". $wkdir_str);
    # Set the job's status to "running"
    push (@body, "sleep 6"); # running が早すぎて queued がなかなか勝てないため
    push (@body, jobsched::inventory_write_cmdline($self->{id}, 'running'). " || exit 1");
    # Do before_in_job
    if ( $self->{before_in_job} ) { push (@body, "perl $self->{before_in_job_file}"); }
    # Execute the program
    foreach my $j (0..$user::max_exe_etc) {
	if ($self->{"exe$j"}) {
	    my @args = ();
	    for ( my $i = 0; $i <= $user::max_arg; $i++ ) {
		if ($self->{"arg$j".'_'."$i"}) {
		    push(@args, $self->{"arg$j".'_'."$i"});
		}
	    }
	    my $cmd = $self->{"exe$j"} . ' ' . join(' ', @args);
	    push (@body, $cmd);
	}
    }
    # Do after_in_job
    if ( $self->{after_in_job} ) { push (@body, "perl $self->{after_in_job_file}"); }
    # Set the job's status to "done" (should set to "aborted" when failed?)
    push (@body, jobsched::inventory_write_cmdline($self->{id}, 'done'). " || exit 1");
    $self->{jobscript_body} = \@body;
}

# Create a perl script file for before_in_job
sub make_before_in_job_script {
    my $self = shift;
    my @body = ();
    push (@body, Data::Dumper->Dump([$self],['self']));
    push (@body, $self->{before_in_job});
    $self->{before_in_job_script} = \@body;
}

# Create a perl script file for after_in_job
sub make_after_in_job_script {
    my $self = shift;
    my @body = ();
    push (@body, Data::Dumper->Dump([$self],['self']));
    push (@body, $self->{after_in_job});
    $self->{after_in_job_script} = \@body;
}

# Make/Update script file
# args: $self, $scriptfile_basename, @string_array (script contents)
sub update_script_file {
    my $self = shift;
    my $file_base = shift;
    my $file = $self->workdir_file($file_base);
    write_string_array ($file, @_);
    unless ($self->{rhost} eq '') {
	&xcr_push($file, $self->{rhost}, $self->{rwd});
    }
}

# Make/Update a jobscript file of $self->{jobscript_header} and $self->{jobscript_body}
sub update_jobscript_file {
    my $self = shift;
    $self->update_script_file ($self->{jobscript_file},
                               @{$self->{jobscript_header}},@{$self->{jobscript_body}});
}

# Make/Update a perl script file for before_in_job
sub update_before_in_job_file {
    my $self = shift;
    $self->update_script_file ($self->{before_in_job_file}, @{$self->{before_in_job_script}});
}

# Make/Update a perl script file for after_in_job
sub update_after_in_job_file {
    my $self = shift;
    $self->update_script_file ($self->{after_in_job_file}, @{$self->{after_in_job_script}});
}

# Make/Update all job-related script files
sub update_all_script_files {
    my $self = shift;
    $self->update_jobscript_file();
    $self->update_before_in_job_file();
    $self->update_after_in_job_file();
}

# Make qsub options and set them to $self->{qsub_options}
sub make_qsub_options {
    my $self = shift;
    my @contents = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{job_scheduler}}};
    foreach my $k (keys %cfg) {
        if ( $k =~ /^qsub_option_(.*)/ ) {
            my $v = $cfg{$k};
            my $optname = $1;
            my $mb_name = "JS_$1";
            # $v must be String or (Job*String)->String[]
            unless ( ref($v) ) {
                if (defined $self->{$mb_name}) {
                    push (@contents, $v, $self->{$mb_name});
                }
            } elsif ( ref($v) eq 'CODE' ) {
                my @ret = &$v($self, $mb_name);
                push (@contents, @ret);
            } else {
                warn "Error in config file $self->{job_scheduler}: $k is neither scalar nor CODE."
            }
        }
    }
    $self->{qsub_options} = \@contents;
}

sub before {}
sub after {}

1;
