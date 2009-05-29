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
#    'before' => '$self->{input}->KR("param", "%$self->{arg1} + 50%");',
#    'after' => '$self->{output} = 100 + $self->{output};',
    'option' => '# @$-g gh10034'
);

my @jobs = &generate(%xyz, 'range1' => [1..10]);
foreach (@jobs) {
    $_->{input}->KR("param", "%$_->{arg1} + 50%");
    # 以下，入力ファイルデータの整形ルール（LRとか）が続く
}
my @thrds = &submit(@jobs);
my @outputs  = &sync(@thrds);
print join (" ", @outputs), "\n";

$xyz{'input_filename'} = 'job100_8/plasma.inp';
print &generate_submit_sync(%xyz) , "\n";


