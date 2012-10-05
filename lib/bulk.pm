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
use Config::Simple;

our %bulk = ();

&add_key('bulk_jobs', 'max_num', 'max_time', 'user_bulk');

sub initialize {
    ### designated unit bulk ###
    %bulk = @_;
    
    if ( exists $bulk{user_bulk} ) {
        if ( ref($bulk{user_bulk}) ne 'CODE' ) {
            ### user function bulk ###
            die "Bulk User_Bulk Error\n";
        }
        if (exists $bulk{max_num}) {
            warn "max_num : invalid command because user_bulk exists\n";
        }
        if (exists $bulk{max_time}) {
            warn "max_time : invalid command because user_bulk exists\n";
        }
    } else {
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
    
    if ( exists $bulk{before} ) {
        if (ref($bulk{before}) ne 'CODE') {
            die "Bulk Before Error\n";
        }
    }
    if ( exists $bulk{after} ) {
        if (ref($bulk{after}) ne 'CODE') {
            die "Bulk After Error\n";
        }
    }
    if ( exists $bulk{before_in_job} ) {
        if (ref($bulk{before_in_job}) ne 'CODE') {
            die "Bulk Before_in_job Error\n";
        }
    }
    if ( exists $bulk{after_in_job} ) {
        if (ref($bulk{after_in_job}) ne 'CODE') {
            die "Bulk After_in_job Error\n";
        }
    }
}

sub bulk {
    my $id   = shift;
    my @jobs = @_;
    my @user_bulk_jobs = ();
    
    if ( exists $bulk{user_bulk} ) {
        ### user function bulk ###
        my @bulk_jobs = $bulk{user_bulk}->($id, @jobs);
        foreach my $bulk_job (@bulk_jobs) {
            push (@user_bulk_jobs, &prepare(%bulk_job, %bulk));
        }
        # return
        return (@user_bulk_jobs);
    } elsif ( !exists $bulk{max_time} and !exists $bulk{max_num} ) {
        ### All jobs bulk ###
        my %frame         = ();
        $frame{id}        = "$id";
        $frame{bulk_jobs} = \@jobs;
        my @bulk_job = &prepare(%frame, %bulk);
        # return
        return (@bulk_job);
    } else {
        ### designated unit bulk ###
        # Supplement）When queue names are different; an other bulk job
        my $job_cnt   = 0;
        my $jobs_max  = $#jobs;
        my $bulk_cnt  = 0;
        my @bulk_job  = ();
        my @bulk_jobs = ();
        my $time_cnt  = 0;
        my %frame     = ();
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
            } else {
                # register bulk job
                $bulk_cnt++;
                $frame{id}        = ();
                $frame{id}        = "${id}_${bulk_cnt}";
                $frame{exe}       = '';
                my @bulk_job_tmp  = @bulk_job;
                $frame{bulk_jobs} = \@bulk_job_tmp;
                push (@bulk_jobs, &prepare(%frame, %bulk));
                # initial setting
                @bulk_job = ();
                push (@bulk_job, $job);
                $job_cnt  = 1;
                $time_cnt = $job->{time};
            }
            # check the number of the bulk jobs
            if ( ((exists $bulk{max_num}) and $bulk{max_num} <= $job_cnt) or $i >= $jobs_max ) {
                # register bulk job
                $bulk_cnt++;
                $frame{id}        = ();
                $frame{id}        = "${id}_${bulk_cnt}";
                $frame{exe}       = '';
                my @bulk_job_tmp  = @bulk_job;
                $frame{bulk_jobs} = \@bulk_job_tmp;
                push (@bulk_jobs, &prepare(%frame, %bulk));
                # initial setting
                @bulk_job = ();
                $job_cnt  = 0;
                $time_cnt = 0;
            }
        }
        # return
        return (@bulk_jobs);
    }
}

sub is_bulk {
    my $self = shift;
    return (defined $self->{bulk_jobs});
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    if ( !($self->is_bulk()) ) {
        return $self->NEXT::start();
    } else {
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            $sub_self->qsub_make();
        }
        # Indirectly calls overridden make_jobscript_body()
        $self->qsub_make();
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            xcr_unlink ($sub_self->{env}, jobsched::left_message_file_name($sub_self, 'running'));
            xcr_unlink ($sub_self->{env}, jobsched::left_message_file_name($sub_self, 'done'));
            &jobsched::set_job_submitted($sub_self);
        }
        $self->{request_id} = $self->qsub();
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            # &jobsched::set_job_queued($sub_self);
            $sub_self->{request_id} = $self->{request_id};
        }
        &jobsched::write_log (":reqID $self->{id} $self->{request_id} $self->{env}->{host} $self->{env}->{sched} $self->{env}->{wd} $self->{env}->{location} $self->{workdir} $self->{jobscript_file} $self->{JS_stdout} $self->{JS_stderr}\n");
        return $self->{request_id};
    }
}

sub initially {
    my $self = shift;
    $self->make_dumped_environment();
    if ($self->is_bulk()) {
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            $sub_self->make_dumped_environment();
            $sub_self->EVERY::initially(@{$sub_self->{VALUE}});
        }
    }
}

sub before {
    my $self = shift;
    if ($self->is_bulk()) {
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            if ($sub_self->{before_to_job} and (exists $sub_self->{before})) {
                # Eliminate user's before() temporarily.
                $sub_self->{before_bkup} = $sub_self->{before};
                delete $sub_self->{before};
            }
            #if ($sub_self->{before_to_job} != 1) {
                my $before_return = $sub_self->EVERY::before(@{$sub_self->{VALUE}});
                foreach my $key (keys %{$before_return}) {
                    if ($key eq 'user::before' and $sub_self->{before} ne '') {
                        $sub_self->{before_return} = ${$before_return}{$key};
                        $sub_self->return_write("before", $sub_self->{workdir}, ${$before_return}{$key});
                    }
                }
            #}
            if (exists $sub_self->{before_bkup}) {
                # Restore user's before() from before_bkup
                $sub_self->{before} = $sub_self->{before_bkup};
                delete $sub_self->{before_bkup};
            }
        }
    }
}

sub after {
    my $self = shift;
    if ($self->is_bulk()) {
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            xcr_unlink ($sub_self->{env}, jobsched::left_message_file_name($sub_self, 'running'));
            xcr_unlink ($sub_self->{env}, jobsched::left_message_file_name($sub_self, 'done'));
            {
                local $jobsched::Warn_illegal_transition = 0;
                jobsched::set_job_done($sub_self);
            }
            if ($sub_self->{after_to_job} == 1 and (exists $sub_self->{after})) {
                # Eliminate user's after() temporarily.
                $sub_self->{after_bkup} = $sub_self->{after};
                delete $sub_self->{after};
            }
            #if ($sub_self->{after_to_job} != 1) {
                my $after_return = $sub_self->EVERY::LAST::after(@{$sub_self->{VALUE}});
                foreach my $key (keys %{$after_return}) {
                    if ($key eq 'user::after' and $sub_self->{after} ne '') {
                        $sub_self->{after_return} = ${$after_return}{$key};
                        $sub_self->return_write("after", $sub_self->{workdir}, ${$after_return}{$key});
                    }
                }
                builtin::delete_created_files ($sub_self);
            #}
            if (exists $sub_self->{after_bkup}) {
                # Restore user's after() from after_bkup
                $sub_self->{after} = $sub_self->{after_bkup};
                delete $sub_self->{after_bkup};
            }
        }
    }
}

sub finally {
    my $self = shift;
    if ($self->is_bulk()) {
        foreach my $sub_self (@{$self->{bulk_jobs}}) {
            xcr_unlink ($sub_self->{env}, jobsched::left_message_file_name($sub_self, 'running'));
            xcr_unlink ($sub_self->{env}, jobsched::left_message_file_name($sub_self, 'done'));
            {
                my $stat = jobsched::get_job_status ($sub_self);
                unless ( $stat eq 'done' || $stat eq 'aborted' || $stat eq 'finished') {
                    local $jobsched::Warn_illegal_transition = 0;
                    jobsched::set_job_done($sub_self);
                }
            }
            &jobsched::set_job_finished($sub_self);
            $sub_self->EVERY::LAST::finally(@{$sub_self->{VALUE}});
            &builtin::delete_created_files($sub_self);
        }
    }
}

sub make_jobscript_body {
    my $self = shift;
    if (!(is_bulk($self))) {
        # Call parent if $self is not a bulk job
        return $self->NEXT::make_jobscript_body();
    }
    # A copy of core::make_job_script_body except between '<*****' and '*****>'
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
    # <*****
    push (@body, 'ORIG_BULK_PWD=`pwd`');
    # *****>
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
    # <*****
    # Execute the program
    foreach my $sub_self (@{$self->{bulk_jobs}}) {
        my %sub_cfg = %{$jsconfig::jobsched_config{$sub_self->{env}->{sched}}};
        # Return to original directory
        push (@body, 'cd $ORIG_BULK_PWD');
        # Chdir to the job's working directory
        my $sub_wkdir_str = File::Spec->catfile($sub_self->{env}->{wd}, $sub_self->{workdir});
        if (defined ($sub_cfg{jobscript_workdir})) {
            my $js_wkdir = $sub_cfg{jobscript_workdir};
            unless (ref ($js_wkdir)) {
                $sub_wkdir_str = $js_wkdir;
            } elsif (ref ($js_wkdir) eq 'CODE') {
                $sub_wkdir_str = &$js_wkdir($sub_self);
            } else {
                warn "Error in config file $sub_self->{env}->{sched}: jobscript_workdir is neither scalar nor CODE."
                }
        }
        my $jobscript_file = File::Spec->catfile($sub_wkdir_str, $sub_self->{jobscript_file});
        push (@body, "sh $jobscript_file");
    }
    # Return to original directory
    push (@body, 'cd $ORIG_BULK_PWD');
    # Re-enter to workdir of the bulk job
    push (@body, "cd $wkdir_str");
    # *****>
    # Do after_in_job by executing the perl script created by make_after_in_job_script
    push (@body, "perl $self->{after_in_job_file}"); 
    push(@body, @{$self->{'cmd_after_exe'}});
    # Set the job's status to "done" (should set to "aborted" when failed?)
    # inventory_write.pl をやめて mkdir に
    push (@body, jobsched::inventory_write_cmdline($self, 'done'). " || exit 1");
    $self->{jobscript_body} = \@body;    
}

1;
