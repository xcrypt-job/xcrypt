package core;

use strict;
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use File::Basename;

use jobsched;
use jsconfig;
use xcropt;
use common;

sub new {
    my $class = shift;
    my $self = shift;

    # stderr & stdout
    set_member_if_empty ($self, 'stdofile', 'stdout');
    set_member_if_empty ($self, 'stdefile', 'stderr');

    # Check if the job ID is not empty
    my $jobname= $self->{id};
    if ($jobname eq '') { die "Can't generate any job without id\n"; }
    # Absolute path of the working directory
    $self->{workdir} = File::Spec->rel2abs ($jobname);

    # Job script related members
    set_member_if_empty ($self, 'job_script', []);
    set_member_if_empty ($self, 'job_scheduler', $xcropt::options{scheduler});
    set_member_if_empty ($self, 'job_script_file', $self->{job_scheduler}.'.sh');
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
            &jobsched::inventory_write ($jobname, "done");
        }
    } else {
        # Otherwise, make the job 'active'
        &jobsched::inventory_write ($jobname, "active");
        # If the working directory already exists, delete it
        if ( -e $self->{workdir} ) {
            print "Delete directory $self->{workdir}\n";
            File::Path::rmtree ($self->{workdir});
        }
        mkdir $self->{workdir} , 0755;

        for ( my $i = 0; $i <= $user::maxargetc; $i++ ) {
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
		if ( -e $copied ) {
		    fcopy($copied, $self->{workdir});
		} else {
		    warn "Can't copy $copied\n";
		}
            }
            if ($self->{"linkedfile$i"}) {
                my $prelink = File::Spec->catfile(basename($self->{"linkedfile$i"}));
                my $link = File::Spec->catfile($self->{workdir}, $prelink);
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
    return File::Spec->catfile ($self->{workdir}, $basename);
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
# The result is stored in @{$self->{job_script}}
sub make_job_script {
    my $self = shift;
    my @contents = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{job_scheduler}}};
    ## Preamble
    push (@contents, "#!/bin/sh\n");
    push (@contents, $cfg{jobscript_preamble});
    ## Options
    # queue & group
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_queue}, $self->{queue});
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_group}, $self->{group});
    # stderr & stdout
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl,
                             $cfg{jobscript_stdout}, $self->workdir_member_file('stdofile'));
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl,
                             $cfg{jobscript_stderr}, $self->workdir_member_file('stdefile'));
    # computing resources
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_proc}, $self->{proc});
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_cpu}, $self->{cpu});
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_memory}, $self->{memory});
    apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_stack}, $self->{stack});
    # verbosity
    if ($self->{verbose})
    { apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_verbose}); }
    if ($self->{verbose_node})
    { apply_push_if_valid_arg (\@contents, \&any_to_string_nl, $cfg{jobscript_verbose_node}); }
    # other options
    push (@contents, $self->{option});

    ## Job script body
    # print SCRIPT "PATH=$ENV{'PATH'}\n";
    # print SCRIPT "set -x\n";
    # Chdir to the job's working directory
    my $wkdir_str = defined ($cfg{jobscript_workdir})
        ? any_to_string_nl ($cfg{jobscript_workdir})
        : $ENV{'PWD'};
    push (@contents, "cd ". File::Spec->catfile($wkdir_str, $self->{id}));
    # Set the job's status to "running"
    push (@contents, jobsched::inventory_write_cmdline($self->{id}, 'running'). " || exit 1");
    # Execute the program
#    foreach (0..$user::maxargetc) {
    foreach my $j (0..$user::maxargetc) {
	if ($self->{"exe$j"}) {
	    my @args = ();
	    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) { push(@args, $self->{"arg$j".'_'."$i"}); }
	    my $cmd = $self->{"exe$j"} . ' ' . join(' ', @args);
	    push (@contents, $cmd);
	}
    }
    # Set the job's status to "done" (should set to "aborted" when failed?)
    push (@contents, jobsched::inventory_write_cmdline($self->{id}, 'done'). " || exit 1");

    $self->{job_script} = \@contents;
}

sub update_job_script_file {
    my $self = shift;
    my $file = $self->workdir_member_file('job_script_file');
    open (my $script_out, '>', $file);
    foreach (@{$self->{job_script}}) {
        print $script_out "$_\n";
    }
    close ($script_out);
}

sub make_qsub_options {
    my $self = shift;
    my @contents = ();
    my %cfg = %{$jsconfig::jobsched_config{$self->{job_scheduler}}};
    apply_push_if_valid_arg (\@contents, \&any_to_string_spc,
                             $cfg{qsub_stdout_option}, $self->workdir_member_file('stdofile'));
    apply_push_if_valid_arg (\@contents, \&any_to_string_spc,
                             $cfg{qsub_stderr_option}, $self->workdir_member_file('stdefile'));
    # under consideration
    # push (@contents, $self->{additional_qsub_options}
    $self->{qsub_options} = \@contents;
}

sub before {}
sub after {}

1;
