use limit;

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

my @jobs = &prepare(%xyz, 'dir' => 'hoge',
		    'ifiles' => sub {$_[0];},
		    'arg1s' => sub {$_[0];});
my @thrds = &submit(@jobs);
my @outputs  = &sync(@thrds);
print join (" ", @outputs), "\n";

