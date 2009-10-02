# Get XCRYPT command-line options
package xcropt;

use strict;
use Getopt::Long;

our %options =
  (
   'port' => 9999,            # インベントリ通知待ち受けポート．0ならNFS経由(unstable!)
   'stack_size' => 32768,     # Perlスレッドのスタックサイズ
   # define other default values...
  );

GetOptions
  (
   'port=i' => \$options{port},
   'stack_size=i' => \$options{stack_size},
   # define other command-line options...
  );
