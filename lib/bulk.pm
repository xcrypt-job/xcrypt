package bulk;

use strict;
use builtin;
use jobsched;
use Cwd;
use File::Basename;
use File::Spec;
use Time::HiRes;
use Coro;
use Coro::Channel;
use common;
use jsconfig;

our %bulk = ();

&add_key('bulk_jobs', 'bulk_id', 'time');

sub initialize {
    if ( $_[0] =~ /^CODE\(/ ) {
        ### user function bulk ###
        $bulk{user_bulk} = $_[0];
    } else {
        ### designated unit bulk ###
        %bulk = @_;
        # number of the jobs to do bulk
        if ( exists $bulk{max_num} ) {
            if ( $bulk{max_num} !~ /^\d+$/ or $bulk{max_num} <= 0 ) {
                die "Bulk Plan Number Error\n";
            }
        }
        # Bulk job plan maximum execute time
        if ( exists $bulk{max_time} ) {
            if ( $bulk{max_time} !~ /^\d+$/ or $bulk{max_time} <= 0 ) {
                die "Bulk Plan Time Error\n";
            }
        }
    }
}

sub bulk {
    my $id   = shift;
    my @jobs = @_;
    
    if ( %bulk == () ) {
        ### All jobs bulk ###
        my %frame         = %{$jobs[0]};
        $frame{id}        = "$id";
        $frame{exe}       = '';
        $frame{bulk_jobs} = \@jobs;
        delete $frame{status};
        my $bulk_job      = user->new(\%frame);
        # Entry job's
        &jobsched::entry_job_id ($bulk_job);
        &jobsched::set_job_initialized($bulk_job);
        &jobsched::set_job_prepared($bulk_job);
        # stderr & stdout
        $bulk_job->{'JS_stdout'} = "$bulk_job->{id}_stdout";
        $bulk_job->{'JS_stderr'} = "$bulk_job->{id}_stderr";
        # Job script related members
        $bulk_job->{'jobscript_file'}     = "$bulk_job->{id}_$bulk_job->{env}->{sched}.sh";
        $bulk_job->{'before_in_job_file'} = "$bulk_job->{id}_before_in_job.pl";
        $bulk_job->{'after_in_job_file'}  = "$bulk_job->{id}_after_in_job.pl";
        # return
        return ($bulk_job);
    } elsif ( exists $bulk{user_bulk} ) {
        ### user function bulk ###
        my @bulk_jobs = $bulk{user_bulk}->($id, @jobs);
        foreach my $bulk_job (@bulk_jobs) {
            delete $bulk_job->{status};
            # Entry job's
            &jobsched::entry_job_id ($bulk_job);
            &jobsched::set_job_initialized($bulk_job);
            &jobsched::set_job_prepared($bulk_job);
            # stderr & stdout
            $bulk_job->{'JS_stdout'} = "$bulk_job->{id}_stdout";
            $bulk_job->{'JS_stderr'} = "$bulk_job->{id}_stderr";
            # Job script related members
            $bulk_job->{'jobscript_file'} = "$bulk_job->{id}_$bulk_job->{env}->{sched}.sh";
            $bulk_job->{'before_in_job_file'} = "$bulk_job->{id}_before_in_job.pl";
            $bulk_job->{'after_in_job_file'} = "$bulk_job->{id}_after_in_job.pl";
        }
        # return
        return (@bulk_jobs);
    } else {
        ### designated unit bulk ###
        # Supplement）When queue names are different; an other bulk job
        my $job_cnt   = 0;
        my $jobs_max  = $#jobs;
        my $bulk_cnt  = 0;
        my @bulk_job  = ();
        my @bulk_jobs = ();
        my $time_cnt  = 0;
        my %frame     = %{$jobs[0]};
        for ( my $i = 0; $i <= $jobs_max; $i++ ) {
            my $job = shift @jobs;
            # check job plan execute time
            if ( (exists $bulk{max_time}) and $bulk{max_time} < $job->{time} ) {
                die "Bulk Plan Time Error\n";
            }
            # check bulk job plan maximum execute time and queue name
            if ( ((!exists $bulk{max_time}) or $bulk{max_time} >= ($time_cnt + $job->{time})) and $frame{JS_queue} eq $job->{JS_queue} ) {
                $time_cnt += $job->{time};
                push (@bulk_job, $job);
                $job_cnt++;
                # check bulk top job
                if ( $job_cnt == 1 ) {
                    # set top job information to bulk job information
                    %frame = %{$job};
                }
            } else {
                # register bulk job
                $bulk_cnt++;
                $frame{id}        = "${id}_${bulk_cnt}";
                $frame{exe}       = '';
                my @bulk_job_tmp  = @bulk_job;
                $frame{bulk_jobs} = \@bulk_job_tmp;
                delete $frame{status};
                my %frame_tmp     = %frame;
                push (@bulk_jobs, (user->new(\%frame_tmp)));
                # initial setting
                %frame    = %{$job};
                @bulk_job = ();
                push (@bulk_job, $job);
                $job_cnt  = 1;
                $time_cnt = $job->{time};
            }
            # check the number of the bulk jobs
            if ( ((exists $bulk{max_num}) and $bulk{max_num} <= $job_cnt) or $i >= $jobs_max ) {
                # register bulk job
                $bulk_cnt++;
                $frame{id}        = "${id}_${bulk_cnt}";
                $frame{exe}       = '';
                my @bulk_job_tmp  = @bulk_job;
                $frame{bulk_jobs} = \@bulk_job_tmp;
                delete $frame{status};
                my %frame_tmp        = %frame;
                push (@bulk_jobs, (user->new(\%frame_tmp)));
                # initial setting
                @bulk_job = ();
                $job_cnt  = 0;
                $time_cnt = 0;
            }
        }
        foreach my $bulk_job (@bulk_jobs) {
            # Entry job's
            &jobsched::entry_job_id ($bulk_job);
            &jobsched::set_job_initialized($bulk_job);
            &jobsched::set_job_prepared($bulk_job);
            # stderr & stdout
            $bulk_job->{'JS_stdout'} = "$bulk_job->{id}_stdout";
            $bulk_job->{'JS_stderr'} = "$bulk_job->{id}_stderr";
            # Job script related members
            $bulk_job->{'jobscript_file'} = "$bulk_job->{id}_$bulk_job->{env}->{sched}.sh";
            $bulk_job->{'before_in_job_file'} = "$bulk_job->{id}_before_in_job.pl";
            $bulk_job->{'after_in_job_file'} = "$bulk_job->{id}_after_in_job.pl";
        }
        # return
        return (@bulk_jobs);
    }
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    if ( $self->{exe} ne '' ) {
        $self->NEXT::start();
    } else {
        # 前回done, finishedになったジョブならとばす．
        my $stat = &jobsched::get_job_status($self);
        if ( $stat eq 'done' ) {
            print "Skipping " . $self->{id} . " because already $stat.\n";
        } else {
            $self->qsub_make($self);
            $self->{request_id} = &qsub($self);
            foreach my $sub_self (@{$self->{bulk_jobs}}) {
                $sub_self->{request_id} = $self->{request_id};
            }
        }
    }
}

sub before {}
sub after {}

# Create a job script from information of the job object.
# The result is stored in @{$self->{jobscript_header}} and @{$self->{jobscript_body}}
sub make_jobscript {
    my $self = shift;
    my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};
    # Chdir to the job's working directory
    my $wkdir_str = File::Spec->catfile($self->{env}->{wd}, $self->{workdir});
    # make_jobscript_header
    $self->make_jobscript_header($self);
    if (defined ($cfg{jobscript_workdir})) {
        my $js_wkdir = $cfg{jobscript_workdir};
        unless (ref ($js_wkdir)) {
            $wkdir_str = $js_wkdir;
        } elsif (ref ($js_wkdir) eq 'CODE') {
            $wkdir_str = &$js_wkdir($self);
        } else {
            warn "Error in config file $self->{env}->{sched}: jobscript_workdir is neither scalar nor CODE."
        }
    }
    unless ($self->{rhost} eq '') {
        $wkdir_str = File::Spec->catfile( $self->{rwd}, $wkdir_str );
    }
    
    # make_jobscript_body
    foreach my $sub_self (@{$self->{bulk_jobs}}) {
        $sub_self->make_jobscript_header($sub_self);
        $sub_self->make_jobscript_body($sub_self);
        push (@{$self->{jobscript_body}}, @{$sub_self->{jobscript_body}});
    }
    # Set the job's status to "running"
    unshift (@{$self->{jobscript_body}},  jobsched::inventory_write_cmdline($self, 'running'). " || exit 1");
    unshift (@{$self->{jobscript_body}}, "sleep 1"); # running が早すぎて queued がなかなか勝てないため
    # Set the job's status to "done" (should set to "aborted" when failed?)
    push (@{$self->{jobscript_body}}, "cd $wkdir_str");
    push (@{$self->{jobscript_body}}, jobsched::inventory_write_cmdline($self, 'done'). " || exit 1");
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
    #$self->make_before_in_job_script();
    #$self->make_after_in_job_script();
    $self->update_all_script_files();
    foreach my $sub_self (@{$self->{bulk_jobs}}) {
        $sub_self->make_before_in_job_script();
        $sub_self->make_after_in_job_script();
        $sub_self->update_all_script_files();
    }
}

sub qsub {
    my $self = shift;
    my $scriptfile = $self->workdir_member_file('jobscript_file');
    my $qsub_options = join(' ', @{$self->{qsub_options}});
    # Set job's status "submitted"
    &jobsched::set_job_submitted($self);
    foreach my $sub_self (@{$self->{bulk_jobs}}) {
        #&jobsched::set_job_initialized($sub_self);
        #&jobsched::set_job_prepared($sub_self);
        &jobsched::set_job_submitted($sub_self);
    }
    
    my $sched = $self->{env}->{sched};
    my %cfg = %{$jsconfig::jobsched_config{$sched}};
    my $qsub_command = $cfg{qsub_command};
    unless ( defined $qsub_command ) {
        die "qsub_command is not defined in $sched.pm";
    }
    
    my $flag;
    $flag = common::cmd_executable ($qsub_command, $self->{env});
    if ($flag) {
        # Execute qsub command
        my $cmdline = "$qsub_command $qsub_options $scriptfile";
        if ($xcropt::options{verbose} >= 2) { print "$cmdline\n"; }
        my @qsub_output = &xcr_qx($self->{env}, "$cmdline", $self->{workdir});
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
        $self->{request_id} = $req_id;
        # Set job's status "queued"
        &jobsched::set_job_queued($self);
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            $sub_self->{request_id} = $req_id;
            &jobsched::set_job_queued($sub_self);
        }
        return $req_id;
    } else {
        die "$qsub_command is not executable";
    }
}
1;
