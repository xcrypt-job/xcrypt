use limit;
use function;
use Data_Generation;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempoG.pl',
    'arg1' => '100',
    'ofile' => 'pbody',
    'ocolumn' => 1,
    'odelimiter' => ',',
    'queue' => 'gh10034',
#    'before' => '$self->{input}->KR("param", "%$self->{arg1} + 50%");',
#    'after' => '$self->{output} = 100 + $self->{output};',
    'option' => '# @$-g gh10034'
);

my @jobs = &prepare(%xyz, 'range' => [1..3], 'arg1s' => sub { $_[0]; });
foreach (@jobs) {
    $_->{input}->KR("param", "%$_->{arg1} + 50%");
    # 以下，入力ファイルデータの整形ルール（LRとか）が続く
}
my @thrds = &submit(@jobs);
my @outputs  = &sync(@thrds);
print join (" ", @outputs), "\n";

#$xyz{'ifile'} = 'job100_8/plasma.inp';
#print &prepare_submit_sync(%xyz) , "\n";


