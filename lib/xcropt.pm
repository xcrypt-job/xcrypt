# Get Xcrypt command-line options
package xcropt;

use Cwd;
use File::Spec;
use strict;
use Getopt::Long;
use builtin;

my $localhost = qx/hostname/;
chomp $localhost;
my $wd = Cwd::getcwd();

our %options =
    (
     'localhost' => $localhost,
     'port' => 9999, # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ
     'wd' => $wd,
     'xd' => $ENV{XCRYPT},
     'scheduler' => $ENV{XCRJOBSCHED},
     'abort_check_interval' => 19, # abort�ˤʤä�����֤�����å�����ֳ�(sec)
     'inventory_path' => 'inv_watch', # ����֤�����䡤port==0�Ǥ��̿��ѥե������񤭹���ǥ��쥯�ȥꡥ������ȥ�⡼�ȤȤ�Ʊ��̾�����̤Υե�ѥ��ˤ������ä��Τ����Хѥ��ǻ��ꤹ��褦�ˤ�����
     'verbose' => 0,               # verbose level
     'stack_size' => 32768,        # Perl����åɤΥ����å�������
     'rsh' => 'ssh',
     'rcp' => 'scp',
#     'rhost' => undef,
#     'rwd' => undef,
     # define other default values...
    );

GetOptions
    (\%options,
     'shared',
     'rsh=s',
     'rcp=s',
#     'rhost=s',
#     'rwd=s',
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
