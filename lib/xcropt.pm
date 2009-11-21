# Get Xcrypt command-line options
package xcropt;

use strict;
use Getopt::Long;

our %options =
  (
   'port' => 9999,               # ����٥�ȥ������Ԥ������ݡ��ȡ�0�ʤ�NFS��ͳ(unstable!)
   'abort_check_interval' => 19, # abort�ˤʤä�����֤�����å�����ֳ�(sec)
   'stack_size' => 32768,        # Perl����åɤΥ����å�������
   # define other default values...
  );

GetOptions
  (\%options,
   'port=i',
   'abort_check_interval=i',
   'stack_size=i',
   # define other command-line options...
  );
