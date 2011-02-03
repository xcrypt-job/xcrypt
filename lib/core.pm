package core;

use strict;
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use File::Basename;
use Data::Dumper;

use jobsched;
use jsconfig;
#use xcropt;
use common;
use builtin;
use return_transmission;

my $Inventory_Path = $xcropt::options{inventory_path}; # The directory that system administrative files are created in.

my $cwd = Cwd::getcwd();
sub new {
    my $class = shift;
    my $self = shift;

    set_member_if_empty ($self, 'workdir', '.');

    ## default env
    set_member_if_empty ($self, 'env', $builtin::env_d);

    ## stderr & stdout
    set_member_if_empty ($self, 'JS_stdout', "$self->{id}_stdout");
    set_member_if_empty ($self, 'JS_stderr', "$self->{id}_stderr");

    ## Check if the job ID is not empty
    if ($self->{id} eq '') { die "Can't generate any job without id\n"; }

    ## Job script related members
    set_member_if_empty ($self, 'jobscript_header', []);
    set_member_if_empty ($self, 'jobscript_body', []);
    set_member_if_empty ($self, 'jobscript_file', "$self->{id}_$self->{env}->{sched}.sh");
    set_member_if_empty ($self, 'before_in_job_file', "$self->{id}_before_in_job.pl");
    set_member_if_empty ($self, 'after_in_job_file', "$self->{id}_after_in_job.pl");
    set_member_if_empty ($self, 'qsub_options', []);

    &jobsched::set_job_initialized($self); # <- builtin.pm
    &jobsched::set_job_prepared($self); # for compatibility, the same as initialized

    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $stat = &jobsched::get_job_status($self);
    if ( $stat eq 'done' ) {
        print "Skipping " . $self->{id} . " because already $stat.\n";
    } else {
        # print "$self->{id}: calling qsub.\n";
        &qsub_make($self);
        # Returns request ID
	$self->{request_id} = (&qsub($self));
	&jobsched::write_log (":reqID $self->{id} $self->{request_id} $self->{env}->{host} $self->{env}->{sched} $self->{env}->{wd} $self->{env}->{location} $self->{workdir} $self->{jobscript_file} $self->{JS_stdout} $self->{JS_stderr}\n");
    }
}

sub workdir_member_file {
    my $self = shift;
    my $member = shift;
    unless ($self->{$member}) {
        warn "The job object $self->{id} does not have a member '$member'";
    }
    return $self->{$member};
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
    my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};
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
                warn "Error in config file $self->{env}->{sched}: $k is neither scalar nor CODE."
            }
        }
    }
    ## Other options
    my $others = $cfg{jobscript_other_options};
    if ( ref($others) eq 'CODE' ) {
        push (@header, &$others($self));
    } else {
        push (@header, @{mkarray($others)});
    }
    ## Environment variables
    my $p5l =
	File::Spec->catfile($self->{env}->{xd}, 'lib') . ':' .
	File::Spec->catfile($self->{env}->{xd}, 'lib', 'cpan') . ':' .
	File::Spec->catfile($self->{env}->{xd}, 'lib', 'algo', 'lib');
    push (@header, 'PERL5LIB=' . $p5l);
    push (@header, 'export PERL5LIB');
    $self->{jobscript_header} = \@header;
}

sub make_jobscript_body {
    my $self = shift;
    my @body = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};
    ## Job script body
    # Chdir to the job's working directory
    my $wkdir_str = File::Spec->catfile($self->{env}->{wd}, $self->{workdir});
    if (defined ($cfg{jobscript_workdir})) {
        my $js_wkdir = $cfg{jobscript_workdir};
        unless ( ref($js_wkdir) ) {
            $wkdir_str = $js_wkdir;
        } elsif ( ref($js_wkdir) eq 'CODE' ) {
            $wkdir_str = &$js_wkdir($self);
        } else {
            warn "Error in config file $self->{env}->{sched}: jobscript_workdir is neither scalar nor CODE."
        }
    }
    push (@body, "cd $wkdir_str");
    ## preamble
    my $preamble = $cfg{jobscript_body_preamble};
    if ( ref($preamble) eq 'CODE' ) {
        push (@body, &$preamble($self));
    } else {
        push (@body, @{mkarray($preamble)});
    }
    # Set the job's status to "running"
    push (@body, "sleep 1"); # running が早すぎて queued がなかなか勝てないため
    # inventory_write.pl をやめて touch に
#    push (@body, jobsched::inventory_write_cmdline($self, 'running'). " || exit 1");
    push (@body, 'touch ' . $self->{id} . '_is_running');
    # Do before_in_job
#    if ( $self->{before_in_job} ) { push (@body, "perl $self->{before_in_job_file}"); }
    if ( $self->{before_in_job} or $self->{before_to_job} == 1 ) { push (@body, "perl $self->{before_in_job_file}"); } # for return_transmission
    # Execute the program
    my $max_of_exe = &builtin::get_max_index_of_exe(%$self);
    my $max_of_second = &builtin::get_max_index_of_second_arg_of_arg(%$self);
    foreach my $j (0..$max_of_exe) {
	if ($self->{"exe$j"}) {
	    my @args = ();
	    for ( my $i = 0; $i <= $max_of_second; $i++ ) {
		if ($self->{"arg$j".'_'."$i"}) {
		    push(@args, $self->{"arg$j".'_'."$i"});
		}
	    }
	    my $cmd = $self->{"exe$j"} . ' ' . join(' ', @args);
	    push (@body, $cmd);
	}
    }
    # Do after_in_job
#    if ( $self->{after_in_job} ) { push (@body, "perl $self->{after_in_job_file}"); }
    if ( $self->{after_in_job} or $self->{after_to_job} == 1 ) { push (@body, "perl $self->{after_in_job_file}"); } # for return_transmission
    # Set the job's status to "done" (should set to "aborted" when failed?)
    # inventory_write.pl をやめて touch に
#    push (@body, jobsched::inventory_write_cmdline($self, 'done'). " || exit 1");
    push (@body, 'touch ' . $self->{id} . '_is_done');
    $self->{jobscript_body} = \@body;
}

# Create a perl script file for before/after_in_job
sub make_in_job_script {
    my ($self, $memb_evalstr, $memb_script) = @_;
    my @body = ();
    push (@body, 'use data_extractor;', 'use data_generator;', 'use return_transmission;'); # for return_transmission
    push (@body, 'use Data::Dumper;', '$Data::Dumper::Deparse = 1;', '$Data::Dumper::Deepcopy = 1;'); # for return_transmission
    if (exists $self->{transfer_reference_level} and $self->{transfer_reference_level} =~ /^[0-9]+$/) {
        push (@body, '$Data::Dumper::Maxdepth = '.$self->{transfer_reference_level}.';');
    } else {
        push (@body, '$Data::Dumper::Maxdepth = '. $Data::Dumper::Maxdepth .';');
    }
   #push (@body, Data::Dumper->Dump([$self],['self']));
    push (@body, $self->data_dumper());
   #push (@body, $self->{$memb_evalstr});
    if ($memb_evalstr eq 'before_in_job' and (exists $self->{before}) and $self->{before_to_job} == 1) {
        push (@body, '$self->return_write("before", ".", &before($self));');
    }
    if (ref ($self->{$memb_evalstr}) eq 'CODE') {
        push (@body, '$self->return_write("'.$memb_evalstr.'", ".", &{$self->{'.$memb_evalstr.'}}());');
    } elsif (exists $self->{$memb_evalstr}) {
        push (@body, '$self->return_write("'.$memb_evalstr.'",  ".", $self->{'.$memb_evalstr.'});');
    }
    if ($memb_evalstr eq 'after_in_job' and (exists $self->{after}) and $self->{after_to_job} == 1) {
        push (@body, '$self->return_write("after", ".", &after($self));');
    }
    $self->{$memb_script} = \@body;
}

# original
#sub make_in_job_script {
#    my ($self, $memb_evalstr, $memb_script) = @_;
#    my @body = ();
#    push (@body, 'use data_extractor;', 'use data_generator;');
#    push (@body, Data::Dumper->Dump([$self],['self']));
#    push (@body, $self->{$memb_evalstr});
#    $self->{$memb_script} = \@body;
#}

sub make_before_in_job_script {
    my $self = shift;
    make_in_job_script ($self, 'before_in_job', 'before_in_job_script');
}

sub make_after_in_job_script {
    my $self = shift;
    make_in_job_script ($self, 'after_in_job', 'after_in_job_script');
}

# Make/Update script file
# args: $self, $scriptfile_basename, @string_array (script contents)
sub update_script_file {
    my $self = shift;
    my $file_base = shift;
    my $file = File::Spec->catfile($self->{workdir}, $file_base);
    write_string_array ($file, @_);
#    if ($self->{env}->{location} eq 'remote') {
#	&put_into($self->{env}, $file, '.');
#	unlink $file;
#    }
}

# Make/Update a jobscript file of $self->{jobscript_header} and $self->{jobscript_body}
sub update_jobscript_file {
    my $self = shift;
    $self->update_script_file ($self->{jobscript_file},
                               @{$self->{jobscript_header}},
			       @{$self->{jobscript_body}});
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
    my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};
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
                warn "Error in config file $self->{env}->{sched}: $k is neither scalar nor CODE."
            }
        }
    }
    $self->{qsub_options} = \@contents;
}

sub before_in_xcrypt {
    my $self = shift;
#    if ($self->{env}->{location} eq 'remote') {
#	my $file = File::Spec->catfile($self->{workdir}, "$self->{id}_return");
#	if (-e $file) {
#	    print "hoge\n";
#	    &put_into($self->{env}, $file, '.');
#	    unlink $file;
#	}
#    }
}
sub after_in_xcrypt {
    my $self = shift;
#    if ($self->{env}->{location} eq 'remote') {
#	&get_from($self->{env}, File::Spec->catfile($self->{workdir}, "$self->{id}_return"), '.');
#	&rmt_unlink($self->{env}, File::Spec->catfile($self->{workdir}, "$self->{id}_return"));
#    }
}

# Submit a job specified by a jop object ($self) by executing "qsub"
# after creating a job script file and a string of command-line option.
sub qsub_make {
    my $self = shift;

    my $sched = $self->{env}->{sched};
    unless (defined $jsconfig::jobsched_config{$sched}) {
	die "$sched.pm doesn't exist in lib/config";
    }
    my %cfg = %{$jsconfig::jobsched_config{$sched}};

    # Create JobScript & qsub options
    $self->make_jobscript();
    $self->make_qsub_options();
    if (defined $cfg{modify}) {
        &{$cfg{modify}} ($self);
    }
    $self->make_before_in_job_script();
    $self->make_after_in_job_script();
    $self->update_all_script_files();
}

sub qsub {
    my $self = shift;

    my $scriptfile = $self->workdir_member_file('jobscript_file');
    my $qsub_options = join(' ', @{$self->{qsub_options}});

    # Set job's status "submitted"
    &jobsched::set_job_submitted($self);

    my $sched = $self->{env}->{sched};
    my %cfg = %{$jsconfig::jobsched_config{$sched}};
    my $qsub_command = $cfg{qsub_command};

    unless ( defined $qsub_command ) {
	die "qsub_command is not defined in $sched.pm";
    }

    my $flag;
    $flag = cmd_executable ($qsub_command, $self->{env});
    if ($flag) {
        # Execute qsub command
	my $cmdline = "$qsub_command $qsub_options $scriptfile";

	my @qsub_output = &xcr_qx($self->{env}, "$cmdline", $self->{workdir});
        if ( @qsub_output == 0 ) { die "qsub command failed"; }

        # Get request ID from qsub's output
        my $req_id;
        # Call an extractor defined in a configuration file
        if ( defined ($cfg{extract_req_id_from_qsub_output}) ) {
            unless ( ref $cfg{extract_req_id_from_qsub_output} eq 'CODE' ) {
                die "Error in $sched.pm: extract_req_id_from_qsub_output must be a function";
            }
            $req_id = &{$cfg{extract_req_id_from_qsub_output}} (@qsub_output);
        } else { # default extractor
            $req_id = ($qsub_output[0] =~ /([0-9]+)/) ? $1 : -1;
        }
        if ( $req_id < 0 ) { die "Can't extract request ID from qsub output." }
        # Remember request ID
	$self->{request_id} = $req_id;
        # Set job's status "queued"
        return $req_id;
    } else {
        die "$qsub_command is not executable";
    }
}

##################################################
# qdelコマンドを実行して指定されたジョブを殺す
sub qdel {
    my ($self) = @_;
    # qdelコマンドをconfigから獲得
    my $qdel_command = $jsconfig::jobsched_config{$self->{env}->{sched}}{qdel_command};
    unless ( defined $qdel_command ) {
        die "qdel_command is not defined in $self->{env}->{sched}.pm";
    }
    my $req_id = $self->{request_id};
    if ($req_id) {
        # execute qdel
        my $command_string = any_to_string_spc ("$qdel_command ", $req_id);
	if ($self->{env}->{location} eq 'local') {
	    if (cmd_executable ($command_string, $self->{env})) {
		print "Deleting $self->{id} (request ID: $req_id)\n";
		exec_async ($command_string);
	    } else {
		warn "$command_string not executable.";
	    }
	} else {
	    print "Deleting $self->{id} (request ID: $req_id)\n";
	    &xcr_system($self->{env}, $command_string, $self->{env}->{workdir});
	}
    }
}

# If the job is 'queued' or 'running', qdel it and returns 1
# Otherwise returns 0
sub qdel_if_queued_or_running {
    my ($self) = @_;
    my $stat = jobsched::get_job_status ($self);
    if ( $stat eq 'queued' || $stat eq 'running' ) {
        $self->qdel();
        return 1;
    } else {
        return 0;
    }
}

### Abort, cancel, or invalidate jobs
# Stop the job. The job is restarted when Xcrypt is executed again.
sub abort {
    my ($self) = @_;
    print "$self->{id} is aborted by user.\n";
    unless (jobsched::get_signal_status ($self) eq 'sig_invalidate') {
        jobsched::set_signal ($self, 'sig_abort');
    }
    $self->qdel_if_queued_or_running();
    jobsched::set_job_status_according_to_signal ($self);
}

# Same as abort except that this method also aborts finished or invalidated jobs.
sub cancel {
    my ($self) = @_;
    print "$self->{id} is cancelled by user.\n";
    jobsched::set_signal ($self, 'sig_cancel');
    $self->qdel_if_queued_or_running();
    jobsched::set_job_status_according_to_signal ($self);
}

# Stop the job. The job is never executed until reset is invoked.
sub invalidate {
    my ($self) = @_;
    print "$self->{id} is invalidated by user.\n";
    jobsched::set_signal ($self, 'sig_invalidate');
    $self->qdel_if_queued_or_running();
    jobsched::set_job_status_according_to_signal ($self);
}

1;
