use limit;
use function;
use Data_Generation;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempo.pl',
    'arg1' => '100',
    'input_filename' => 'plasma.inp',
    'output_filename' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034'
);

my @jobs = &generate(%xyz, 'range1' => [1..3],
    'after' => 'if ($self->{output} == 3) { killall(\'job100\', 1, 2, 3); }');
my @thrds = &submit(@jobs);
my @outputs  = &sync(@thrds);
print join (" ", @outputs), "\n";
