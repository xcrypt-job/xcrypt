# Get XCRYPT command-line options
package xcropt;

use strict;
use Getopt::Long;

our %options =
  (
   'port' => 9999,            # �C���x���g���ʒm�҂��󂯃|�[�g�D0�Ȃ�NFS�o�R(unstable!)
   # define other default values...
  );

GetOptions
  (
   'port=i' => \$options{port}
   # define other command-line options...
  );
