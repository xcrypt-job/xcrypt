# Define dependencis among jobs declaratively
package dependency;

use strict;
use NEXT;
use common;
use builtin;

&add_key('depend_on');

sub before {
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
    # Do not sync if @dep_jobs is empty (when an empty list is given, sync waits for
    # all the jobs submitted inside the nearest (implicit) join block)
    if (@dep_jobs) { sync (@dep_jobs) };
}

1;
