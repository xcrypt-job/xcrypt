#!/usr/bin/perl

package xcrypt;

use Getopt::Long;
use function;
use threads;
use threads::shared;
use jobsched;
use limit;
use base qw(constructor);

$opt_dry = 0;
GetOptions('dry' => \$opt_dry);

our @outputs : shared = ();

$job100 = {
    'id' => 'job100',
    'predecessors' => [],
    'exe' => './kempo.pl',
    'arg1' => '',
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'option' => '# @$-q eh',
    'after_process' => 'push (@xcrypt::outputs, $self->{output});'
};

=comment
&parexec('job100', \&function::plus1, [1..10]);
print join (" ", @{$job100s1->{outputs}}), "\n";
print join (" ", @outputs), "\n";
=cut

$foo = 0;
@hhh = (1..10);

until ($foo) {
    @iii = &parexec('job100', \&function::plus10, \@hhh);
    &bar(@iii);
    @hhh = &map(\&function::plus10, \@hhh);
}

sub map {
    my @result;
    foreach (@{$_[1]}) {
	push (@result , &{$_[0]}($_));
    }
    return @result;
}

sub bar {
    foreach (@_) {
	if ($_ < 0.1) {
	    print $_ , "\n";
	$foo = 1;
	}
    }
}

sub parexec {
    my $hoge = $_[0] . 's1';
	eval "\$$hoge = { 'id' => '$_[0]' };";
    my $hage = $$hoge;
    $hage->{arg1s} = $_[2];
    $hage->{amplifier} = $_[1];
    my @foo = &parexec_custom($hage);
    return @foo;
}

sub parexec_custom {
    my $thrd;
    my $thrd_card : shared = 0;
    foreach my $jobgraph (@_) {
	my @aaa = &generate($jobgraph);
	foreach (@aaa) {
	    eval "\$ccc = \$$_;";
	    my $obj = xcrypt->new($ccc);
	    $thrd[$thrd_card] = threads->new(\&constructor::start, $obj);
	    $thrd_card++;
	}
    }
    for (my $k = 0; $k < $thrd_card; $k++) {
	$thrd[$k]->join;
    }
    my @bar;
    foreach my $jobgraph (@_) {
	my @foo = &pickup_outputs($jobgraph);
	push (@bar, @foo);
    }
    return @bar;
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
'option' => '# @$-q eh',
'input_file' => '$self->{input_file}',
'output_file' => '$self->{output_file}',
'output_column' => '$self->{output_column}',
'delimiter' => '$self->{delimiter}',
'exit_cond' => sub { &function::tautology; },
'after_process' => '$self->{after_process}'
};";
    }
    $limit::smph=Thread::Semaphore->new(6);
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

#    $limit::smph=Thread::Semaphore->new(6);
#    xcrypt->new($job0)->start;

=cut
