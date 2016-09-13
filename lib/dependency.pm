# Define dependencis among jobs declaratively
package dependency;

use builtin;
use jobsched;
use common;
use strict;

&add_key('depend_on');

sub initially {
    my $self = shift;
    my @dep_jobs0 = @{mkarray ($self->{depend_on})};
    my @dep_jobs = ();
    
    foreach my $j0 (@dep_jobs0) {
        if ( ref $j0 eq '' ) {
            my $j = jobsched::find_job_by_id ($j0);
            if ($j) {push (@dep_jobs, $j);}
        } elsif ( ref $j0 eq 'user' ) {
            push (@dep_jobs, $j0);
        }
    }
    foreach (@dep_jobs) {
	jobsched::wait_job_status ($_, 'finished');
    }
}

1;
