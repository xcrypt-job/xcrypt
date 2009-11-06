package simple_convergence;

use strict;
use File::Spec;
use builtin;
use Data_Extraction;
use Data_Generation;
use Recursive qw(fcopy dircopy rcopy);
use NEXT;
use base qw(Exporter);
our @EXPORT = qw(backward_difference_loop);

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

sub before {
    my $self = shift;
    my $dir = $self->{id};
    my $copied = $self->{":inputfile"};
    if ( -e $copied ) {
	fcopy($copied, $dir);
    } else {
	warn "Can't copy $copied\n";
    }
    # use Data_Generation
    my $tmp1 = File::Spec->catfile($ENV{'PWD'}, $self->{':inputfile'});
    my $tmp2 = File::Spec->catfile($ENV{'PWD'}, $self->{'id'});
    my $gen = CF($tmp1, $tmp2);
    $gen->KR($self->{':inputname'}, $self->{':initialvalue'});
    $gen->do();

    $self->NEXT::before();
}

sub after {
    my $self = shift;
    $self->NEXT::after();
}

sub backward_difference_loop {
    my $yesterday = undef;
#    my $oname = shift;
    my %job = @_;

    until ((defined $yesterday) &&
	   (abs($job{':initialvalue'} - $yesterday) < $job{':isConvergent'})) {
	$yesterday = $job{':initialvalue'};
	$job{'id'} = $job{'id'} . '_';
	my @results = &prepare_submit_sync(%job);
	foreach (@results) {
	    # use Data_Extraction
	    my $tmp = File::Spec->catfile($ENV{'PWD'},
					  $_->{'id'},
					  $job{':outputfile'});
	    my $datum = EF("file:$tmp");
	    $datum->ED('L/E');
#	    $oname;
	    my @foo = $datum->ER();
	    $job{':initialvalue'} = $foo[0];
print $yesterday, "\n";
print $job{':initialvalue'}, "\n";
	}
    }
}

1;
