use limit;
use function;
use Data_Generation;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempo',
    'arg1' => 'plasma.inp',
    'arg2' => '100',
    'ifile' => 'plasma.inp',
    'ofile' => 'pbody',
    'ocolumn' => 1,
    'odelimiter' => ',',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034'
);

#my @jobs = &prepare(%xyz, 'range' => [1..3]);
my @jobs = &prepare(%xyz, 'range' => [1..3],
		    'arg1s' => sub { $_[0]; },
		    'arg2s' => sub { $_[0]; });
my @thrds = &submit(@jobs);
my @outputs  = &sync(@thrds);
print join (" ", @outputs), "\n";


