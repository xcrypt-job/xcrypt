# Get Xcrypt command-line options
package xcropt;

use Cwd;
use File::Spec;
use strict;
use Getopt::Long;

my $localhost = qx/hostname/;
chomp $localhost;

my @rhosts = ();

our %options =
    (
     'rsh' => 'ssh',
     'rcp' => 'scp',
     'rhost' => \@rhosts,
     'rwd' => undef,
     'localhost' => $localhost,
     'port' => 9999, # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ
#     'scheduler' => $ENV{XCRJOBSCHED}, # Default job scheduler
     'scheduler' => undef, # �¹Ի���Ϳ�����ʤ����*�׻�*�ۥ��ȤδĶ��ѿ����ͤ����ꤹ��Ȥ����������ѹ�����
     'abort_check_interval' => 19, # abort�ˤʤä�����֤�����å�����ֳ�(sec)
#     'inventory_path' => File::Spec->catfile(Cwd::getcwd(), 'inv_watch'),
     'inventory_path' => 'inv_watch', # ������ȥ�⡼�ȤȤ�Ʊ��̾�����̤Υե�ѥ��ˤ������ä��Τ����Хѥ��ǻ��ꤹ��褦�ˤ���
     # ����֤�����䡤port==0�Ǥ��̿��ѥե������񤭹���ǥ��쥯�ȥ�
     'verbose' => 0,               # verbose level
     'stack_size' => 32768,        # Perl����åɤΥ����å�������
     # define other default values...
    );

GetOptions
    (\%options,
     'shared',
     'rsh=s',
     'rcp=s',
     'rhost=s',
     'rwd=s',
     'localhost=s',
     'port=i',
     'abort_check_interval=i',
     'scheduler=s',
     'inventory_path=s',
     'verbose=i',
     'stack_size=i',
     # define other command-line options...
    );

unless (defined $xcropt::options{scheduler}) {
    unless (@{$xcropt::options{rhost}} == ()) {
	my $rxcrjsch = qx/$xcropt::options{rsh} ${$xcropt::options{rhost}}[0] 'echo \$XCRJOBSCHED'/;
	chomp($rxcrjsch);
	$xcropt::options{scheduler} = $rxcrjsch;
    } else {
	$xcropt::options{scheduler} = $ENV{XCRJOBSCHED};
    }
}

1;
