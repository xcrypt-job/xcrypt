use function;

$limit::smph=Thread::Semaphore->new(100);

%job0 = (
    'id' => 'job0',
    'queue' => 'eh',
#    'exit_cond' => sub { &function::tautology; },
    'successors' => ['job3','job1','job2']
);
%job3 = (
    'id' => 'job3',
    'predecessors' => ['job1','job2'],
    'exe' => './kempo.pl',
    'queue' => 'eh',
    'arg1' => 50,
    'arg2' => 100,
    'input_filename' => 'plasma.inp',
    'output_filename' => 'pbody',
    'output_column' => 1,
#    'exit_cond' => sub { &function::tautology; },
    'delimiter' => ','
);
%job1 = (
    'id' => 'job1',
    'predecessors' => [],
    'exe' => './kempo.pl',
    'arg1' => 20,
    'arg2' => 100,
    'input_filename' => 'plasma.inp',
    'output_filename' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'queue' => 'eh',
    'trace' => [10, 100]
);
%job2 = (
    'id' => 'job2',
    'predecessors' => [],
    'exe' => './kempo.pl',
    'arg1' => 30,
    'arg2' => 100,
    'input_filename' => 'plasma.inp',
    'output_filename' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'queue' => 'eh',
    'trace' => [20, 200]
);

&generate_submit_sync(%job0) , "\n";
