# Get XCRYPT command-line options
package xcropt;

use strict;
use Getopt::Long;

our %options =
  (
   'port' => 9999,            # �C���x���g���ʒm�҂��󂯃|�[�g�D0�Ȃ�NFS�o�R(unstable!)
   'stack_size' => 32768,     # Perl�X���b�h�̃X�^�b�N�T�C�Y
   # define other default values...
  );

GetOptions
  (
   'port=i' => \$options{port},
   'stack_size=i' => \$options{stack_size},
   # define other command-line options...
  );
