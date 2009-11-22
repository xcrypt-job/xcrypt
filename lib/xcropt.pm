# Get Xcrypt command-line options
package xcropt;

use strict;
use Getopt::Long;

our %options =
  (
   'port' => 9999,               # インベントリ通知待ち受けポート．0ならNFS経由(unstable!)
   'abort_check_interval' => 19, # abortになったジョブをチェックする間隔(sec)
   'stack_size' => 32768,        # Perlスレッドのスタックサイズ
   # define other default values...
  );

GetOptions
  (\%options,
   'port=i',
   'abort_check_interval=i',
   'stack_size=i',
   # define other command-line options...
  );
