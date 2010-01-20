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
   'port' => 9999,               # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ
   'abort_check_interval' => 19, # abort�ˤʤä�����֤�����å�����ֳ�(sec)
   'inventory_path' => File::Spec->catfile(Cwd::getcwd(), 'inv_watch'),
                                 # ����֤�����䡤port==0�Ǥ��̿��ѥե������񤭹���ǥ��쥯�ȥ�
   'stack_size' => 32768,        # Perl����åɤΥ����å�������
   # define other default values...
  );

GetOptions
  (\%options,
   'localhost=s',
   'port=i',
   'abort_check_interval=i',
   'inventory_path=s',
   'stack_size=i',
   # define other command-line options...
  );
