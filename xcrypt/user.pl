use function;

$limit::smph=Thread::Semaphore->new(10);

our @outputs1 : shared = ();
%xyz = (
    'id' => 'job100',
    'exe' => './kempo.pl',
    'arg1' => '100',
    'input_file' => 'plasma.inp',
    'output_file' => 'pbody',
    'output_column' => 1,
    'delimiter' => ',',
    'queue' => 'gh10034',
    'option' => '# @$-g gh10034',
    'after_processing' => 'push (@user::outputs1, $self->{output});'
);


my @outputs2 = &submit_sync(%xyz, 'range1' => [1..10], 'amp1' => \&plus1);
print join (" ", @outputs1), "\n";
print join (" ", @outputs2), "\n";


my @thrd_ids5 = &submit(%xyz, 'range1' => [41..50]);
my @thrd_ids3 = &submit(%xyz, 'range1' => [21..30]);
my @thrd_ids4 = &submit(%xyz, 'range1' => [31..40]);

my @outputs3 = &sync(@thrd_ids3);
my @outputs5 = &sync(@thrd_ids5);

print join (" ", @outputs3), "\n";

my @outputs4 = &sync(@thrd_ids4);

print join (" ", @outputs4), "\n";
print join (" ", @outputs5), "\n";

=comment
=cut


=comment
#my @outputs3 = &kaishu(%xyz, 'range1' => [11..20], 'amp1' => \&plus1);

&submit_sync('id' => 'job33', 'exe' => './hello');
&submit_sync(%xyz);
my @outputs2 = &submit_sync(%xyz, 'range1' => [1..10]);

$foo = 0;
$bar = 1;

until ($foo) {
    my @kkk = ($bar..($bar+9));
    my @iii = &submit_sync(%xyz, 'range1' => \@kkk);
    foreach (@iii) {
	if ($_ < 0.5) {
	    print $_ , "\n";
	$foo = 1;
	}
    }
    $bar = $bar + 10;
}
=cut
