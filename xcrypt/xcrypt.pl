#!/usr/bin/perl

package xcrypt;

use Getopt::Long;
use function;
use threads;
use threads::shared;
use limit;
use jobsched;
use base qw(constructor);

$opt_dry = 0;
GetOptions('dry' => \$opt_dry);

$limit::smph=Thread::Semaphore->new(8);

#&submit('id' => 'job33', 'exe' => './hello');

%xyz = (
    'id' => 'job100',
    'exe' => './kempo.pl',
    'arg1' => '100',
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034',
    'after_processing' => 'push (@xcrypt::outputs1, $self->{output});'
);

=comment
our @outputs1 : shared = ();
#&submit(%xyz);

my @outputs2 = &submit(%xyz, 'range1' => [1..10]);
#my @outputs2 = &submit(%xyz, 'range1' => [1..10], 'amp1' => \&function::plus1);

print join (" ", @outputs1), "\n";
print join (" ", @outputs2), "\n";
=cut

$foo = 0;
$bar = 1;

until ($foo) {
    my @kkk = ($bar..($bar+9));
    my @iii = &submit(%xyz, 'range1' => \@kkk);
    foreach (@iii) {
	if ($_ < 0.5) {
	    print $_ , "\n";
	$foo = 1;
	}
    }
    $bar = $bar + 10;
}

$jobsched::inventory_watch_thread->detach;

sub submit {
    my %jg_rng_amp = @_;
    my $id = $jg_rng_amp{'id'};
    my @outputs;
    if ($jg_rng_amp{'range1'} eq '') {
	xcrypt->new(\%jg_rng_amp)->start;
    }
    my $thrd;
    my $thrd_card : shared = 0;
    my @arg1s;
    foreach (@{$jg_rng_amp{'range1'}}) {
	my $arg1;
	if ($jg_rng_amp{'amp1'} eq '') {
	    $arg1 = &function::identity($_);
	} else {
	    $arg1 = &{$jg_rng_amp{'amp1'}}($_);
	}
	push (@arg1s, $arg1);
    }
    foreach (@arg1s) {
	my $jobgraph = \%jg_rng_amp;
	$jobgraph->{id} = $id . '_' . $_;
	$jobgraph->{arg1} = $_;
	my $obj = xcrypt->new($jobgraph);
	$thrd[$thrd_card] = threads->new(\&constructor::start, $obj);
	$thrd_card++;
    }
    for (my $k = 0; $k < $thrd_card; $k++) {
	$thrd[$k]->join;
    }
    foreach (@arg1s) {
	my $outputfile = $id . '_' . $_ . '/' . $jg_rng_amp{'output_file'};
	open ( OUTPUTS , "< $outputfile" );
	my $line = <OUTPUTS>;
	my $delimiter = $jg_rng_amp{'delimiter'};
	my @list = split(/$delimiter/, $line);
	close ( OUTPUTS );
	push (@outputs , $list[$jg_rng_amp{'output_column'}]);
    }
    return @outputs;
}

=comment

&submit_custom($job100s1, $job100s2);
print join (" ", @{$job100s1->{outputs}}), "\n";

until ($foo) {
    &submit($job100s1);
    &bar();
    my @arg1s = &map(\&function::plus10, $job100s1->{arg1s});
    $job100s1->{arg1s} = \@arg1s;
}

# an example of a jobgraph

$job0 = {
    'id' => 'job0',
    'option' => '# @$-q eh',
    'exit_cond' => sub { &function::tautology; },
    'successors' => ['job3','job4','job5']
};
$job3 = {
    'id' => 'job3',
    'predecessors' => ['job4','job5'],
    'exe' => './kempo.pl',
    'arg1' => 50,
    'arg2' => 100000000,
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'exit_cond' => sub { &function::tautology; },
    'option' => '# @$-q eh'
};
$job4 = {
    'id' => 'job4',
    'cnvg' => 'job1',
    'option' => '# @$-q eh',
    'trace' => [40, 400],
    'exit_cond' => sub { &function::forward_difference; },
    'change_arg1' => sub { $_[0] + 10; },
    'change_arg2' => sub { 100; },
    'change_input_file' => sub {}
};
$job5 = {
    'id' => 'job5',
    'cnvg' => 'job2',
    'option' => '# @$-q eh',
    'trace' => [50, 500],
    'exit_cond' => sub { &function::forward_difference; },
    'change_arg1' => sub { $_[0] + 1; },
    'change_arg2' => sub { 100; },
    'change_input_file' => sub {}
};
$job1 = {
    'id' => 'job1',
    'predecessors' => [],
    'exe' => './kempo.pl',
    'arg1' => 20,
    'arg2' => 100,
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'option' => '# @$-q eh',
    'trace' => [10, 100]
};
$job2 = {
    'id' => 'job2',
    'predecessors' => [],
    'exe' => './kempo.pl',
    'arg1' => 30,
    'arg2' => 100,
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'option' => '# @$-q eh',
    'trace' => [20, 200]
};

$limit::smph=Thread::Semaphore->new(6);
xcrypt->new($job0)->start;

=cut
