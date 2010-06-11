# Get Xcrypt command-line options
package xcropt;

use strict;
use Cwd;
use Getopt::Long;

my $localhost = qx/hostname/;
chomp $localhost;
my $wd = Cwd::getcwd();

our %options = (
    'localhost' => $localhost,
    'wd' => $wd,
    'xd' => $ENV{XCRYPT},
    'sched' => $ENV{XCRJOBSCHED},
    #
    'port' => 9999, # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ
    'abort_check_interval' => 19, # abort�ˤʤä�����֤�����å�����ֳ�(sec)
    'inventory_path' => 'inv_watch',
    #
    'verbose' => 0,               # verbose level
    'stack_size' => 32768,        # Perl����åɤΥ����å�������
    #
    'rsh' => 'ssh',
    'rcp' => 'scp',
    'rhost' => undef,
    'rwd' => undef,
    # define other default values...
    );

GetOptions
    (\%options,
     'shared',
     #
     'localhost=s',
     'wd=s',
     'xd=s',
     'sched=s',
     #
     'inventory_path=s',
     'port=i',
     'abort_check_interval=i',
     #
     'verbose=i',
     'stack_size=i',
     #
     'rsh=s',
     'rcp=s',
     'rhost=s',
     'rwd=s',
     # define other command-line options...
    );

1;
