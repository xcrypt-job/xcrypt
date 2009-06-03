use limit;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempo.pl',
    'arg1' => 'plasma.inp',
    'ifile' => 'plasma.inp',
    'ofile' => 'pbody',
    'ocolumn' => 1,
    'odelimiter' => ',',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034'
);

my @jobs = &prepare_directory(%xyz, 'arg1idir' => 'hoge');
my @thrds = &submit(@jobs);
my @outputs  = &sync(@thrds);
print join (" ", @outputs), "\n";

