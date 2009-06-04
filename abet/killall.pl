use limit;
use function;
use Data_Generation;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempo.pl',
    'ifile' => 'plasma.inp',
    'ofile' => 'pbody',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034',
    'arg1' => '100'
);

my @jobs = &prepare(%xyz, 'range' => [1..3],
 'after' => 'if ($self->{output} == 1) { killall(\'job100\', 1, 2, 3); }');
my @thrds = &submit(@jobs);
my @results  = &sync(@thrds);

foreach (@results) {
    print $_->{output} , "\n";
}
