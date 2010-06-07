package bulk;

use strict;
use builtin;
use jobsched;
use Cwd;
use File::Basename;
use File::Spec;
use jsconfig;

our %bulk = ();

&addkeys('bulkedjobs');

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
    my $id = shift;
    my @jobs = @_;
    if ( %bulk == () ) {
        ### All jobs bulk ###
        my %frame            = %{$jobs[0]};
        $frame{id}         = "$id";
        $frame{exe}        = '';
        $frame{bulkedjobs} = \@jobs;
        my $bulk_job = user->new(\%frame);
        return ($bulk_job);
    } elsif ( exists $bulk{user_bulk} ) {
        ### user function bulk ###
        my @bulk_jobs = $bulk{user_bulk}->($id, @jobs);
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
        my %frame      = %{$jobs[0]};
        for ( my $i = 0; $i <= $jobs_max; $i++ ) {
            my $job = shift @jobs;
            # check job plan execute time
            if ( (exists $bulk{max_time}) and $bulk{max_time} < $job->{time} ) {
                die "Bulk Plan Time Error\n";
            }
            # check bulk job plan maximum execute time and queue name
            if ( ((!exists $bulk{max_time}) or $bulk{max_time} >= ($time_cnt + $job->{time})) and $frame{queue} eq $job->{queue} ) {
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
                $frame{id}         = "${id}_${bulk_cnt}";
                $frame{exe}        = '';
                my @bulk_job_tmp     = @bulk_job;
                $frame{bulkedjobs} = \@bulk_job_tmp;
                my %frame_tmp        = %frame;
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
                $frame{id}         = "${id}_${bulk_cnt}";
                $frame{exe}        = '';
                my @bulk_job_tmp     = @bulk_job;
                $frame{bulkedjobs} = \@bulk_job_tmp;
                my %frame_tmp        = %frame;
                push (@bulk_jobs, (user->new(\%frame_tmp)));
                # initial setting
                @bulk_job = ();
                $job_cnt  = 0;
                $time_cnt = 0;
            }
        }
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
            $self->{request_id} = &qsub($self);
        }
    }
}

sub qsub {
    my $self = shift;
    # for inventory_write_file
    my $inventory_path = $xcropt::options{inventory_path};
    my $LOCKDIR = File::Spec->rel2abs(File::Spec->catfile($inventory_path, 'inventory_lock'));
    my $REQUESTFILE = File::Spec->rel2abs(File::Spec->catfile($inventory_path, 'inventory_req'));
    my $ACKFILE = File::Spec->rel2abs(File::Spec->catfile($inventory_path, 'inventory_ack'));
    my $REQUEST_TMPFILE = $REQUESTFILE . '.tmp';
    my $ACK_TMPFILE = $ACKFILE . '.tmp';
    rmdir $LOCKDIR;
    unlink $REQUEST_TMPFILE, $REQUESTFILE, $ACK_TMPFILE, $ACKFILE;
    # print job script file
    $self = &jobsched::print_job_scriptfile ($self);
    foreach my $subself (@{$self->{bulkedjobs}}) {
        &jobsched::inventory_write($subself, 'prepared');
        &jobsched::print_job_scriptfile ($subself);
    }
    # Set job's status "submitted"
    &jobsched::inventory_write($self, "submitted");
    foreach my $subself (@{$self->{bulkedjobs}}) {
        &jobsched::inventory_write($subself, "submitted");
    }
    # qsub job script file
    return &jobsched::qsub_job_scriptfile ($self);
}

sub before {}

sub after {}

1;
