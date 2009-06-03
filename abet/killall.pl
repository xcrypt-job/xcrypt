use limit;
use function;
use Data_Generation;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempo.pl',
    'ifile' => 'plasma.inp',
    'ofile' => 'pbody',
    'ocolumn' => 1,
    'odelimiter' => ',',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034',
    'arg1' => '100'
);

my @jobs = &prepare(%xyz, 'param' => [1..3],
 'after' => 'if ($self->{output} == 1) { killall(\'job100\', 1, 2, 3); }');
my @thrds = &submit(@jobs);
my @outputs  = &sync(@thrds);
print join (" ", @outputs), "\n";
