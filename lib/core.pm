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

    $jobsched::initialized_nosync_jobs{$self->{id}} = $self;

    unless (@{$xcropt::options{rhost}} == ()) {
	$self->{rhost} = ${$xcropt::options{rhost}}[0];
    }
    unless (@{$xcropt::options{rwd}} == ()) {
	$self->{rwd} = ${$xcropt::options{rwd}}[0];
    }
    if ($xcropt::options{scheduler}) {
	$self->{scheduler} = $xcropt::options{scheduler};
    } else {
	unless (defined $self->{scheduler}) {
	    if (defined $self->{rhost}) {
		my $rxcrjsch = qx/$xcropt::options{rsh} $self->{rhost} 'echo \$XCRJOBSCHED'/;
		chomp($rxcrjsch);
		if ($rxcrjsch) {
		    $self->{scheduler} = $rxcrjsch;
		} else {
		    die "Set the environment varialble \$XCRJOBSCHED at $self->{rhost}\n" ;
		}
	    } else {
		if ($ENV{XCRJOBSCHED}) {
		    $self->{scheduler} = $ENV{XCRJOBSCHED};
		} else {
		    die "Set the environment varialble \$XCRJOBSCHED\n" ;
		}
	    }
	}
    }

    # stderr & stdout
    set_member_if_empty ($self, 'JS_stdout', 'stdout');
    set_member_if_empty ($self, 'JS_stderr', 'stderr');

    # Check if the job ID is not empty
    my $jobname= $self->{id};
    if ($jobname eq '') { die "Can't generate any job without id\n"; }
    $self->{workdir} = $jobname;

    # Job script related members
    set_member_if_empty ($self, 'jobscript_header', []);
    set_member_if_empty ($self, 'jobscript_body', []);
    set_member_if_empty ($self, 'scheduler', $xcropt::options{scheduler});
    set_member_if_empty ($self, 'jobscript_file', $self->{scheduler}.'.sh');
    set_member_if_empty ($self, 'before_in_job_file', 'before_in_job.pl');
    set_member_if_empty ($self, 'after_in_job_file', 'after_in_job.pl');
    set_member_if_empty ($self, 'qsub_options', []);

    # Load the inventory file to recover the job's status after the previous execution
    if (defined $self->{rhost}) {
	&jobsched::entry_host_and_sched_for_qstat ($self->{rhost}, $self->{scheduler});
	&jobsched::entry_host_and_wd_for_qstat ($self->{rhost}, $self->{rwd});
    } else {
	&jobsched::entry_host_and_sched_for_qstat ('localhost', $self->{scheduler});
	&jobsched::entry_host_and_wd_for_qstat ('localhost', $self->{scheduler});
    }
    &jobsched::load_inventory ($jobname);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    # Skip if the job is done or finished in the previous execution
    # ↑ 「finishedも」というのはコメントの書き間違い？
    my $stat = &jobsched::get_job_status($self->{id});
    if ( $stat eq 'done' ) {
        print "Skipping " . $self->{id} . " because already $stat.\n";
    } else {
        # print "$self->{id}: calling qsub.\n";
        $self->{request_id} = &qsub($self);
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
    my %cfg = %{$jsconfig::jobsched_config{$self->{scheduler}}};
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
                warn "Error in config file $self->{scheduler}: $k is neither scalar nor CODE."
            }
        }
    }
    ## Environment variables
#    push (@header, "export XCRYPT=$ENV{XCRYPT}");
#    push (@header, 'export PERL5LIB=$XCRYPT/lib');
    $self->{jobscript_header} = \@header;
}

sub make_jobscript_body {
    my $self = shift;
    my @body = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{scheduler}}};
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
            warn "Error in config file $self->{scheduler}: jobscript_workdir is neither scalar nor CODE."
        }
    }
    unless ($self->{rhost} eq '') {
	$wkdir_str = File::Spec->catfile($self->{rwd}, $wkdir_str);
    }
    push (@body, "cd ". $wkdir_str);
    # Set the job's status to "running"
    push (@body, "sleep 1"); # running が早すぎて queued がなかなか勝てないため
    push (@body, jobsched::inventory_write_cmdline($self->{id}, 'running', $self->{rhost}, $self->{rwd}). " || exit 1");
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
    push (@body, jobsched::inventory_write_cmdline($self->{id}, 'done', $self->{rhost}, $self->{rwd}). " || exit 1");
    $self->{jobscript_body} = \@body;
}

# Create a perl script file for before/after_in_job
sub make_in_job_script {
    my ($self, $memb_evalstr, $memb_script) = @_;
    my @body = ();
    push (@body, 'use Data_Extraction;', 'use Data_Generation;');
    push (@body, Data::Dumper->Dump([$self],['self']));
    push (@body, $self->{$memb_evalstr});
    $self->{$memb_script} = \@body;
}

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
    my %cfg = %{$jsconfig::jobsched_config{$self->{scheduler}}};
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
                warn "Error in config file $self->{scheduler}: $k is neither scalar nor CODE."
            }
        }
    }
    $self->{qsub_options} = \@contents;
}

sub before {}
sub after {}

# Submit a job specified by a jop object ($self) by executing "qsub"
# after creating a job script file and a string of command-line option.
sub qsub {
    my $self = shift;
    my $sched = $self->{scheduler};
    unless (defined $jsconfig::jobsched_config{$sched}) {
	die "$sched.pm doesn't exist in lib/config" ;
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

    my $scriptfile = $self->workdir_member_file('jobscript_file');
    my $qsub_options = join(' ', @{$self->{qsub_options}});

    # Set job's status "submitted"
    &jobsched::inventory_write($self->{id}, 'submitted',
			       $self->{rhost}, $self->{rwd});

    my $qsub_command = $cfg{qsub_command};
    unless ( defined $qsub_command ) {
	die "qsub_command is not defined in $sched.pm";
    }
    my $flag = &xcr_exist('-f', $scriptfile, $self->{rhost}, $self->{rwd});
    unless ($flag) {
	die "Can't find a job script file \"$scriptfile\"";
    }

    my $flag;
    if ($self->{rhost}) {
	$flag = common::cmd_executable ($qsub_command, $self->{rhost});
    } else {
	$flag = common::cmd_executable ($qsub_command);
    }
    if ($flag) {
        # Execute qsub command
	my $cmdline = "$qsub_command $qsub_options $scriptfile";
        if ($xcropt::options{verbose} >= 2) { print "$cmdline\n"; }

	my @qsub_output = &xcr_qx("$cmdline", '.',
				  $self->{rhost}, $self->{rwd});
        if ( @qsub_output == 0 ) { die "qsub command failed."; }

        # Get request ID from qsub's output
        my $req_id;
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
	$self->{req_id} = $req_id;
        &jobsched::set_job_request_id ($self->{id}, $req_id);
        # Set job's status "queued"
	&inventory_write($self->{id}, 'queued', $self->{rhost}, $self->{rwd});
        return $req_id;
    } else {
        die "$qsub_command is not executable";
    }
}

1;
