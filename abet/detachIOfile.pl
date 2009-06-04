use limit;
use function;
use Data_Generation;
use Data_Extraction;

$limit::smph=Thread::Semaphore->new(100);

%xyz = (
    'id' => 'job100',
    'exe' => './kempo',
    'arg1' => 'plasma.inp',
    'arg2' => '100',
    'ifile' => 'plasma.inp',
    'ofile' => 'pbody',
    'queue' => 'gh10034',
#    'before' => '$self->{input}->KR("param", "%$self->{arg1} + 50%");',
#    'after' => '$self->{output} = 100 + $self->{output};',
    'option' => '# @$-g gh10034'
);

my @jobs = &prepare(%xyz, 'range' => [1..3], 'arg2s' => sub { $_[0]; });
foreach (@jobs) {
    $_->{input}->KR("param", "%$_->{arg2} + 50%");
    # 以下，入力ファイルデータの整形ルール（LRとか）が続く
}
my @thrds = &submit(@jobs);
my @results  = &sync(@thrds);

mkdir 'job100_1/hoge', 0755;
$After1 = EF('/home/abet/e-science/abet/job100_1/pbody',
	     '/home/abet/e-science/abet/job100_1/hoge');
$After1->LE("1");
$After1->do();

my @list = &pickup('job100_1/hoge/pbody', ',');
print $list[1];

