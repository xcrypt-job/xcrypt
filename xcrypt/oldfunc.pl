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

sub pickup_outputs {
    my $jobgraph = shift;
    my $id = $jobgraph->{id};
    my $self = $$id;
    foreach my $arg1 (@{$jobgraph->{arg1s}}) {
    }
    return @{$jobgraph->{outputs}};
}

sub generate {
    my $jobgraph = shift;
    my $id = $jobgraph->{id};
    my $self = $$id;
    my @jgs;
    foreach my $arg1 (@{$jobgraph->{arg1s}}) {
	$arg1 = &{$jobgraph->{amplifier1}}($arg1);
	my $real_id = $id . '_' . $arg1;
	my $jg = {};
	$jg->{id} = $real_id;
	$jg->{exe} = $self->{exe};
	$jg->{arg1} = $arg1;
	$jg->{input_file} = $self->{input_file};
	$jg->{successors} = $self->{successors};
	$jg->{predecessors} = $self->{predecessors};
	$jg->{output_file} = $self->{output_file};
	$jg->{output_column} = $self->{output_column};
	$jg->{delimiter} = $self->{delimiter};
	$jg->{queue} = $self->{queue};
	$jg->{after_processing} = $self->{after_processing};
	$jg->{option} = $self->{option};
	push (@jgs , $jg);
    }
    return @jgs;
}

sub parexec {
    my $foo = $_[0] . 's1';
	eval "\$$foo = { 'id' => '$_[0]' };";
    my $bar = $$foo;
    $bar->{arg1s} = $_[2];
    $bar->{amplifier} = $_[1];
    return &parexec_custom($bar);
}

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

sub parexec {
    my $foo = $_[0] . 's1';
	eval "\$$foo = { 'id' => '$_[0]' };";
    my $bar = $$foo;
    $bar->{arg1s} = $_[2];
    $bar->{amplifier} = $_[1];
    return &parexec_custom($bar);
}

sub parexec_custom {
    my $thrd;
    my $thrd_card : shared = 0;
    foreach my $jobgraph (@_) {
	my @jobgraph_ids = &generate($jobgraph);
	foreach (@jobgraph_ids) {
	    eval "\$hoge = \$$_;";
	    my $obj = xcrypt->new($hoge);
	    $thrd[$thrd_card] = threads->new(\&constructor::start, $obj);
	    $thrd_card++;
	}
	foreach (@jobgraph_ids) {
	    print "hoge\n";
	    &jobsched::wait_job_done($_);
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
