package DC;

use strict;
use NEXT;
use builtin;

&add_key('ofname', 'mergeFunc','divideFunc','canDivideFunc');

sub new
{
	my $class = shift;
	my $self = $class->NEXT::new(@_);
	print "\tnew DC\n";
	return bless $self, $class;
}

sub start
{
	my $self = shift;
	print "\tstart DC\n";
	$self->NEXT::start();
}

sub before
{
	my $self = shift;
	print "\tbefore DC\n";
	
	#if( &{$self->{canDivideFunc}}($self) )
	if( $self->{arg0} > 10 )
	{
		#{
		#	no strict "refs";
			my @children = &{$self->{divideFunc}}($self);
		
			#my @children = $self{divideFunc}->{$self};
			my @jobs = ();
			foreach my $child (@children)
			{
				push(@jobs, &builtin::prepare(%{$child}));
			}
#			my @results = &builtin::submit_sync(@jobs);
	# submit by myself
	my @objs;
	foreach my $job (@jobs) {
	    &jobsched::inventory_write($job->{'id'}, 'prepared');
	    &user::before($job);
	    &user::start($job);
	}
	push(@objs, @jobs);
    # after by myself
    foreach my $job (@objs) {
	&jobsched::wait_job_done ($job->{'id'});
#		my $stat = &jobsched::get_job_status($job->{'id'});
#		if ($stat eq 'done') {
#		    print $job->{'id'} . "\'s post-processing finished.\n";
	$job->after();
	until ((-e "$job->{'id'}/$job->{'stdofile'}")
	       && (-e "$job->{'id'}/$job->{'stdefile'}")) {
	    sleep(1);
	}
	&jobsched::inventory_write($job->{'id'}, "finished");
#		}
    }
    # sync by myself
    my @results = &sync(@objs);

			&{$self->{mergeFunc}}($self->{id}."/".$self->{ofname}, @results);
			$self->{exe} = "echo hoge";
		#}
	}
#	$self->NEXT::before();
}

sub after
{
#	my $self = shift;
	print "\tafter DC\n";
#	$self->NEXT::after();
}

sub divide
{
	
}

sub merge
{

}

1;
