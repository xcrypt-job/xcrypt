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

our @outputs1 : shared = ();

$job100 = {
    'id' => 'job100',
    'predecessors' => [],
    'exe' => './kempo.pl',
    'arg1' => '',
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034',
    'after_processing' => 'push (@xcrypt::outputs1, $self->{output});'
};

$limit::smph=Thread::Semaphore->new(6);

my @outputs2 = &parexec('job100', \&function::plus1, [1..10]);
print join (" ", @outputs1), "\n";
print join (" ", @outputs2), "\n";

$jobsched::inventory_watch_thread->detach;

=comment
$foo = 0;
$bar = 1;

until ($foo) {
    my @kkk = ($bar..($bar+9));
    my @iii = &parexec('job100', \&function::plus10, \@kkk);
    foreach (@iii) {
	if ($_ < 0.1) {
	    print $_ , "\n";
	$foo = 1;
	}
    }
    $bar = $bar + 10;
}
=cut

sub parexec {
    my $thrd;
    my $thrd_card : shared = 0;

    my $id = $_[0] . 's1';
    eval "\$$id = { 'id' => '$_[0]' };";
    my $jobgraph = $$id;
    $jobgraph->{arg1s} = $_[2];
    $jobgraph->{amplifier} = $_[1];

    my @jobgraph_ids = &generate($jobgraph);
    foreach (@jobgraph_ids) {
	eval "\$jg = \$$_;";
	my $obj = xcrypt->new($jg);
	$thrd[$thrd_card] = threads->new(\&constructor::start, $obj);
	$thrd_card++;
    }
    for (my $k = 0; $k < $thrd_card; $k++) {
	$thrd[$k]->join;
    }
    return &pickup_outputs($jobgraph);
}

sub pickup_outputs {
    my $jobgraph = shift;
    my $id = $jobgraph->{id};
    my $self = $$id;
    foreach my $arg1 (@{$jobgraph->{arg1s}}) {
	my $real_id = $id . '_' . $arg1;
	my $dir = $real_id . '/';
	my $outputfile = $dir . $self->{output_file};
	open ( OUTPUTS , "< $outputfile" );
	my $line = <OUTPUTS>;
	my $delimiter = $self->{delimiter};
	my @list = split(/$delimiter/, $line);
	close ( OUTPUTS );
	push (@{$jobgraph->{outputs}} , $list[$self->{output_column}]);
    }
    return @{$jobgraph->{outputs}};
}

sub generate {
    my $jobgraph = shift;
    my $id = $jobgraph->{id};
    my $self = $$id;
    my @real_ids;
    foreach my $arg1 (@{$jobgraph->{arg1s}}) {
	$arg1 = &{$jobgraph->{amplifier}}($arg1);
	my $real_id = $id . '_' . $arg1;
	push (@real_ids , $real_id);
	eval "\$$real_id = {
'id' => '$real_id',
'exe' => '$self->{exe}',
'arg1' => $arg1,
'input_file' => '$self->{input_file}',
'output_file' => '$self->{output_file}',
'output_column' => '$self->{output_column}',
'delimiter' => '$self->{delimiter}',
'queue' => '$self->{queue}',
'after_processing' => '$self->{after_processing}'
};";
	my $jg = $$real_id;
	$jg->{option} = $self->{option};
    }
    return @real_ids;
}


=comment
$job100s1 = {
    'id' => 'job100',
    'arg1s' => [1..10],
    'amplifier' => sub { $_[0]; }
};

$job100s2 = {
    'id' => 'job100',
    'arg1s' => [11..20],
    'amplifier' => sub { $_[0]; }
};

&parexec_custom($job100s1, $job100s2);
print join (" ", @{$job100s1->{outputs}}), "\n";

until ($foo) {
    &parexec($job100s1);
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
