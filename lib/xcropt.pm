# Get Xcrypt command-line options
package xcropt;

use Cwd;
use File::Spec;
use strict;
use Getopt::Long;

my $localhost = qx/hostname/;
chomp $localhost;

our %options =
    (
     'localhost' => $localhost,
     'port' => 9999, # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ
     'scheduler' => undef, # ������$ENV{XCRJOBSCHED}�Ǥ��ä����¹Ի���Ϳ�����ʤ����*�׻�*�ۥ��ȤδĶ��ѿ����ͤ����ꤹ��Ȥ����������ѹ�����
     'abort_check_interval' => 19, # abort�ˤʤä�����֤�����å�����ֳ�(sec)
#     'inventory_path' => File::Spec->catfile(Cwd::getcwd(), 'inv_watch'), # ����֤�����䡤port==0�Ǥ��̿��ѥե������񤭹���ǥ��쥯�ȥ�
     'inventory_path' => 'inv_watch', # ������ȥ�⡼�ȤȤ�Ʊ��̾�����̤Υե�ѥ��ˤ������ä��Τ����Хѥ��ǻ��ꤹ��褦�ˤ���
     'verbose' => 0,               # verbose level
     'stack_size' => 32768,        # Perl����åɤΥ����å�������
     # ��⡼�ȼ¹Ԥ򥳥ޥ�ɥ饤��ǹԤ��뤳�Ȥˤ��뤫��̤��
     'rsh' => 'ssh',
     'rcp' => 'scp',
     'rhost' => undef,
     'rwd' => undef,
     # define other default values...
    );

GetOptions
    (\%options,
     'sandbox',
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

1;
