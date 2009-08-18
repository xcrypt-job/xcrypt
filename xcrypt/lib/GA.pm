package GA;

use strict;
use NEXT;
use jobsched;
use Recursive qw(fcopy dircopy rcopy);
use File::Spec;
use File::Path;
use UI;
use function;
use Data_Generation;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    $self->{exe} = $ENV{XCRYPT} . '/bin/GA ' . $self->{GA_count}
                                . ' ' . $self->{GA_lengthOfStr}
                                . ' ' . $self->{GA_howToCrossover}
                                . ' ' . $self->{GA_howToSelect};
    return bless $self, $class;
}

sub start {
    my $self = shift;

    # 前回doneになったジョブならとばす．
    if ( &jobsched::get_job_status ($self->{id}) eq 'done') {
        print "Skipping " . $self->{id} . " because already done.\n";
    } else {
        $self->{request_id} = &jobsched::qsub($self);
        # 結果ファイルから結果を取得
        &jobsched::wait_job_done($self->{id});

        my $stdofile = 'stdout';
        unless ($self->{stdofile} eq '') { $stdofile = $self->{stdofile}; }

	# NFSの書込み遅延に対する暫定的対応
	sleep(3);

        my $pwdstdo = File::Spec->catfile($self->{id}, $stdofile);
        until ( (-e $pwdstdo) or ($jobsched::job_status{$self->{id}} eq 'abort')  ) {
	    sleep 1;
	}

	unless ($self->{stdodlmtr}) { $self->{stdodlmtr} = ','; }
	unless ($self->{stdoclmn}) { $self->{stdoclmn} = '0'; }
        my @stdlist = &pickup($pwdstdo, $self->{stdodlmtr});
        $self->{stdout} = $stdlist[$self->{stdoclmn}];
    }
}

sub before {
    my $self = shift;
    $self->NEXT::before();
}

sub after {
    my $self = shift;
    $self->NEXT::after();
}

1;
