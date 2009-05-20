$jobset1 = {
    'exe' => './kempo1.pl',
    'arg1s' => [1..9],
    'amplifier1' => sub { $_[0] + 1; },
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'exit_cond' => 'pbody',
    'after_process' => ''
};
$jobset2 = {
    'exe' => './kempo2.pl',
    'arg1s' => [5..13],
    'amplifier1' => sub { $_[0] + 2; },
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'after_process' => 'push (@xcrypt::outputs2and3, $self->{output});'
};
$jobset3 = {
    'exe' => './kempo3.pl',
    'arg1s' => [8..20],
    'amplifier1' => sub { $_[0] + 3; },
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'after_process' => 'push (@xcrypt::outputs2and3, $self->{output});'
};

sub parexec {
    my $thrd;
    my $thrd_card : shared = 0;
    foreach my $id (@_) {
	my @aaa = &generate($id);
	foreach $bbb (@aaa) {
	    eval "\$ccc = \$$bbb;";
	    my $obj = xcrypt->new($ccc);
	    $thrd[$thrd_card] = threads->new(\&constructor::start, $obj);
	    $thrd_card++;
	}
    }
    for (my $k = 0; $k < $thrd_card; $k++) {
	$thrd[$k]->join;
    }
    foreach my $id (@_) {
	&pickup_outputs($id);
    }
}

sub generate {
    my $jobset_id = shift;
    my $self = $$jobset_id;
    my @arg1s = @{$self->{arg1s}};
    my @job_ids;
    foreach $arg1 (@arg1s) {
	unless ($self->{amplifier1} eq '') {
	    $arg1 = &{$self->{amplifier1}}($arg1);
	}
	my $job_id = $jobset_id . '_' . $arg1;
	push (@job_ids , $job_id);
	eval "\$$job_id = {
'id' => '$job_id',
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
    return @job_ids;
}

sub parexecnew {
    my $thrd;
    my $thrd_card : shared = 0;
    foreach my $id (@_) {
	&generate($id);
	my $foo = $id . '_init';
	eval "\$bar = \$$foo;";
	my $obj = xcrypt->new($bar);
	$thrd[$thrd_card] = threads->new(\&constructor::start, $obj);
	$thrd_card++;
    }
    for (my $k = 0; $k < $thrd_card; $k++) {
	$thrd[$k]->join;
    }
}

sub parexecnewnew {
    $job0 = {
	'id' => 'job0',
	'option' => '# @$-q eh',
	'exit_cond' => sub { &function::tautology; },
	'successors' => []
    };
    foreach my $id (@_) {
	&generate($id);
	my $init_id = $id . '_init';
	push (@{$job0->{successors}} , $init_id);
    }
    xcrypt->new($job0)->start;
}

sub generatenew {
    my $id = $_[0];
    my $final_id = $id . '_final';
    eval "\$$final_id = {
'id' => '$final_id',
'predecessors' => [],
'option' => '# @$-q eh',
'exit_cond' => sub { &function::tautology; },
'successors' => []
};";
    my $init_id = $id . '_init';
    eval "\$$init_id = {
'id' => '$init_id',
'option' => '# @$-q eh',
'exit_cond' => sub { &function::tautology; },
'successors' => ['$final_id']
};";
    my $jobset = $$id;
    my @params = @{$jobset->{param}};
    foreach $param (@params) {
	unless ($jobset->{amplifier} eq '') {
	    $param = &{$jobset->{amplifier}}($param);
	}
	my $job_id = $id . '_' . $param;
	push (@{$$init_id->{successors}} , $job_id);
	push (@{$$final_id->{predecessors}} , $job_id);
	eval "\$$job_id = {
'id' => '$job_id',
'exe' => '$jobset->{exe}',
'args' => [$param],
'option' => '# @$-q eh',
'input_file' => '$jobset->{input_file}',
'output_file' => '$jobset->{output_file}',
'output_column' => 1,
'delimiter' => ',',
'exit_cond' => sub { &function::tautology; },
};";
    }
    $limit::smph=Thread::Semaphore->new(6);
}
