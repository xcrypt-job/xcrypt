use limit;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempo',
    'arg1' => 'plasma.inp',
    'arg2' => '100',
    'ifile' => 'plasma.inp',
    'ofile' => 'pbody',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034'
);

#my @jobs = &prepare(%xyz, 'range' => [1..3]);
my @jobs = &prepare(%xyz, 'range' => [1..3], 'arg2s' => sub { $_[0]; });
my @thrds = &submit(@jobs);
my @results  = &sync(@thrds);

foreach (@results) {
    print $_->{stdout} , "\n";
}
