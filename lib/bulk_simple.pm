package bulk_simple;

use strict;
use builtin;

&add_key('bulked_jobs');

my $count = 0;
sub bulk {
    my $pre_template = shift;
    my @jobs = @_;
    my %template = %{$pre_template};
    $template{id} = "$pre_template->{id}"."$count";
    $template{bulked_jobs} = \@jobs;
    my $count_exe = 0;
    foreach my $job (@jobs) {
	foreach my $key (keys(%$job)) {
	    if ($key =~ /\Aexe([0-9]+)\Z/) {
		my $tmp = $1;
		$template{"exe$count_exe"} = $job->{$key};
		foreach my $key (keys(%$job)) {
		    my $str = '\Aarg'.$tmp.'_([0-9]+)\Z';
		    if ($key =~ /$str/) {
			my $temp = $1;
			$template{"arg$count_exe"."_$temp"} = $job->{$key};
		    }
		}
		$count_exe++;
	    }
	}
    }
    my @ret = &prepare(%template);
    $count++;
    return @ret;
}

sub initially {
    my $self = shift;
    foreach my $job (@{$self->{bulked_jobs}}) {
	if (defined $job->{initially}) {
	    @user::VALUE = @{$job->{VALUE}};
	    &{$job->{initially}}($job, @user::VALUE);
	}
    }
}

sub before {
    my $self = shift;
    foreach my $job (@{$self->{bulked_jobs}}) {
	if (defined $job->{before}) {
	    @user::VALUE = @{$job->{VALUE}};
	    &{$job->{before}}($job, @user::VALUE);
	}
    }
}

sub after {
    my $self = shift;
    foreach my $job (@{$self->{bulked_jobs}}) {
	if (defined $job->{after}) {
	    @user::VALUE = @{$job->{VALUE}};
	    &{$job->{after}}($job, @user::VALUE);
	}
    }
}

sub finally {
    my $self = shift;
    foreach my $job (@{$self->{bulked_jobs}}) {
	if (defined $job->{finally}) {
	    @user::VALUE = @{$job->{VALUE}};
	    &{$job->{finally}}($job, @user::VALUE);
	}
    }
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start();
}

1;
