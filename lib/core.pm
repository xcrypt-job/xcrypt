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

###
# configuration for Data::Dumper
$Data::Dumper::Deparse  = 1;
$Data::Dumper::Deepcopy = 1;
$Data::Dumper::Maxdepth = 5;
###

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
    set_member_if_empty ($self, 'jobscript_file', "$self->{id}_$self->{env}->{sched}.bat");
    set_member_if_empty ($self, 'dumped_environment', []);
    set_member_if_empty ($self, 'before_in_job_file', "$self->{id}_before_in_job.pl");
    set_member_if_empty ($self, 'exe_in_job_file', "$self->{id}_exe_in_job.pl");
    set_member_if_empty ($self, 'after_in_job_file', "$self->{id}_after_in_job.pl");
    set_member_if_empty ($self, 'qsub_options', []);
    set_member_if_empty ($self, 'not_transfer_info', []);
    push (@{$self->{not_transfer_info}}, 'dumped_environment', 'before_in_job_script', 'exe_in_job_script', 'after_in_job_script');       
    
    set_member_if_empty ($self, 'cmd_before_exe', []);
    set_member_if_empty ($self, 'cmd_after_exe', []);

    set_member_if_empty ($self, 'header', []);

    &jobsched::set_job_initialized($self); # <- builtin.pm
    &jobsched::set_job_prepared($self); # for compatibility, the same as initialized

    return bless $self, $class;
}

sub start {
    my $self = shift;
    # print "$self->{id}: calling qsub.\n";
    &qsub_make($self);
    # Returns request ID
    $self->{request_id} = (&qsub($self));
    &jobsched::write_log (":reqID $self->{id} $self->{request_id} $self->{env}->{host} $self->{env}->{sched} $self->{env}->{wd} $self->{env}->{location} $self->{workdir} $self->{jobscript_file} $self->{JS_stdout} $self->{JS_stderr}\n");
}

sub workdir_member_file {
    my $self = shift;
    my $member = shift;
    unless ($self->{$member}) {
        warn "The job object $self->{id} does not have a member '$member'";
    }
    return File::Spec->catfile($self->{workdir}, $self->{$member});
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
    $self->make_jobscript_header();
    $self->make_jobscript_body();
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
    ## Other user defined preamble
    if ( defined $self->{JS_user_preamble} ) {
        push (@header, @{mkarray($self->{JS_user_preamble})});
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
#    push (@body, "sleep 1"); # running が早すぎて queued がなかなか勝てないため
    push (@body, jobsched::inventory_write_cmdline($self, 'running'). " || exit 1");
    push(@body, @{$self->{'cmd_before_exe'}});
    # Do before_in_job by executing the perl script created by make_before_in_job_script
    push (@body, "perl $self->{before_in_job_file}");
    # Execute the program
    my $max_of_exe = &builtin::get_max_index_of_exe(%$self);
    my $max_of_second = &builtin::get_max_index_of_second_arg_of_arg(%$self);
    if ( defined $self->{exe} ) {
        # $self->{exe} is used.
        if ($max_of_exe>=0) {
            warn '['.$self->{id}.']: {exe0}..{exe'.$max_of_exe.'} is ignored because {exe} is defined as a function.';            
        }
        if ( ref $self->{exe} eq 'CODE' ) {
            # The perl script is generated by make_exe_in_job_script().
            push (@body, "perl $self->{exe_in_job_file}"); 
        } else {
            # If {exe} is not a code block, it is ignored.
            warn "$self->{id}: {exe} is ignored because it is not a code reference.";
        }
    } else {
        # $self->{exe0} .. $self->{exe$max_of_exe} are used.
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
    }
    # Do after_in_job by executing the perl script created by make_after_in_job_script
    push (@body, "perl $self->{after_in_job_file}"); 
    push(@body, @{$self->{'cmd_after_exe'}});
    # Set the job's status to "done" (should set to "aborted" when failed?)
    # inventory_write.pl をやめて mkdir に
    push (@body, jobsched::inventory_write_cmdline($self, 'done'). " || exit 1");
    $self->{jobscript_body} = \@body;
}

# Take a snapshot of the Perl(Xcrypt) environment for *_in_job_scripts
# and write it to $self->{dumped_environment}
sub make_dumped_environment {
    my ($self) = @_;
#    my @body = ();
    my @body = @{$self->{'header'}};
    ## Header
    push (@body, 'use File::Spec;');
    push (@body, 'use lib (File::Spec->catfile($ENV{XCRYPT}, "lib"));');
    push (@body, 'use lib (File::Spec->catfile($ENV{XCRYPT}, "lib", "cpan"));');
    push (@body, 'use lib (File::Spec->catfile($ENV{XCRYPT}, "lib", "algo", "lib"));');

    push (@body, 'use data_extractor;', 'use data_generator;', 'use return_transmission;'); # for return_transmission
    push (@body, 'use Data::Dumper;', '$Data::Dumper::Deparse = 1;', '$Data::Dumper::Deepcopy = 1;'); # for return_transmission
    push (@body, 'use Config::Simple; use File::Copy::Recursive;'); # since these modules are convenient
    if (exists $self->{transfer_reference_level} and $self->{transfer_reference_level} =~ /^[0-9]+$/) {
        push (@body, '$Data::Dumper::Maxdepth = '.$self->{transfer_reference_level}.';');
    } else {
        push (@body, '$Data::Dumper::Maxdepth = '. $Data::Dumper::Maxdepth .';');
    }
    ## Dumps the job object itself
    push (@body, $self->data_dumper());
    $self->{dumped_environment} = \@body;
}

# Generate the contents of a perl script and saves it to $self->{$memb_script}.
# The script (1) defines '$self' as a dumped job object, and
# (2) For each $name in @names:
# (2.1) calls the dumped method $self->{$name} by passing @{$self->{VALUE}} as arguments.
# (2.2) writes the return value to the "$self->{id}_return" by employing return_write().
sub make_in_job_script {
    my ($self, $memb_script, @names) = @_;
    my @body = ();
    ## The snapshot of the Perl(Xcyrpt) environment
    push (@body, @{$self->{dumped_environment}});
    ## Calling the dumped method and writing the return value.
    foreach my $name (@names) {
        if (ref ($self->{$name}) eq 'CODE') {
            push (@body, '$self->return_write("'.$name.'", ".", &{$self->{'.$name.'}}($self, @{$self->{VALUE}}));');
        }
    }
    $self->{$memb_script} = \@body;
}

sub make_before_in_job_script {
    my $self = shift;
    my @names = ();
    if ((exists $self->{before}) and $self->{before_to_job} == 1) {
        push (@names, 'before');
    }
    if (ref ($self->{before_in_job}) eq 'CODE') {
        push (@names, 'before_in_job');
    }
    # Calls it even if @names is empty because child methods may add code
    make_in_job_script ($self, 'before_in_job_script', @names);
}

sub make_exe_in_job_script {
    my $self = shift;
    if (ref ($self->{exe}) eq 'CODE') {
        make_in_job_script ($self, 'exe_in_job_script', 'exe');
    } else {
        $self->{exe_in_job_script} = [];
    }
}

sub make_after_in_job_script {
    my $self = shift;
    my @names = ();
    if (ref ($self->{after_in_job}) eq 'CODE') {
        push (@names, 'after_in_job')
    }
    if ((exists $self->{after}) and $self->{after_to_job} == 1) {
        push (@names, 'after');
    }
    # Calls it even if @names is empty because child methods may add code
    make_in_job_script ($self, 'after_in_job_script', @names);
}

# Make/Update script file
# args: $self, $scriptfile_basename, @string_array (script contents)
sub update_script_file {
    my $self = shift;
    my $file_base = shift;
    my $file = File::Spec->catfile($self->{workdir}, $file_base);
    write_string_array ($file, @_);
    if ($self->{env}->{location} eq 'remote') {
	if (-e $file) {
	    &put_into($self->{env}, $file, '.');
	}
    }
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

# Make/Update a perl script file for exe_in_job
sub update_exe_in_job_file {
    my $self = shift;
    $self->update_script_file ($self->{exe_in_job_file}, @{$self->{exe_in_job_script}});
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
    $self->update_exe_in_job_file();
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
    # User defined qsub options
    if ( defined $self->{JS_user_qsub_options} ) {
        push (@contents, @{mkarray($self->{JS_user_qsub_options})});
    }
    $self->{qsub_options} = \@contents;
}

sub before {
    my $self = shift;
}

sub after {
    my $self = shift;
    if ($self->{env}->{location} eq 'remote') {
	my $file = File::Spec->catfile($self->{workdir}, "$self->{id}_return");
	if (xcr_exist($self->{env}, $file)) {
	    &get_from($self->{env}, $file, '.');
	}
    }
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
    $self->make_exe_in_job_script();
    $self->make_after_in_job_script();
    $self->update_all_script_files();
}

sub qsub {
    my $self = shift;

    my $scriptfile = $self->{jobscript_file};
    my $qsub_options = join(' ', @{$self->{qsub_options}});

    # Set job's status "submitted"
    &jobsched::set_job_submitted($self);

    my $sched = $self->{env}->{sched};
    my %cfg = %{$jsconfig::jobsched_config{$sched}};
    my $qsub_command = $cfg{qsub_command};

    unless ( defined $qsub_command ) {
	die "qsub_command is not defined in $sched.pm";
    }

    # Delete garbage message files if exist.
    xcr_unlink ($self->{env}, jobsched::left_message_file_name($self, 'running'));
    xcr_unlink ($self->{env}, jobsched::left_message_file_name($self, 'done'));

    my $flag;
    $flag = cmd_executable ($qsub_command, $self->{env});
    if ($flag) {
        # Execute qsub command
	my $cmdline = "$qsub_command $qsub_options $scriptfile";
        #print STDERR "$cmdline\n";
        # xcr_qx() chdirs to working directory, executes $cmdline, and returns the stdout string.
	my @qsub_output = &xcr_qx($self->{env}, "$cmdline", $self->{workdir});
#        if ( @qsub_output == 0 ) { die "qsub command failed"; }

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

### Save the member values into a log file
sub save {
    my ($self, $mb_name) = @_;
    my $dumper = Data::Dumper->Dump([$self->{$mb_name}],['savedval']);
    $dumper =~ s/([\[\{])\n\s+(\')/$1$2/g;
    $dumper =~ s/([\',]{1})\n\s+(\')/$1$2/g;
    $dumper =~ s/(\')\n\s+([\]\}])/$1$2/g;
    $dumper =~ s/^(\$savedval = )(.*)$/$2/g;
    jobsched::write_log (":savedval $self->{id} $mb_name $dumper\n");
}

# Restore the member values save()ed in the log file
sub restore {
    my ($self) = @_;
    my $savedval = jobsched::get_last_job_savedval($self->{id});
    if ( $savedval ) {
        foreach my $k (keys %$savedval) {
            $self->{$k} = $savedval->{$k};
        }
    }
}    

1;
