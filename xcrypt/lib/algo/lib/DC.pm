package DC;

use strict;
use NEXT;
use builtinfunc;


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
		my @children = &{$self->{divideFunc}}($self);
		my @jobs = ();
		foreach my $child (@children)
		{
			push(@jobs, &builtinfunc::prepare(%{$child}));
		}
		my @results = &builtinfunc::submit_sync(@jobs);
		&{$self->{mergeFunc}}($self->{id}."/".$self->{ofname}, @results);
		$self->{exe} = "echo hoge";
	}
	$self->NEXT::before();
}

sub after
{
	my $self = shift;
	print "\tafter DC\n";
	$self->NEXT::after();
}

sub divide
{
	
}

sub merge
{

}

1;
