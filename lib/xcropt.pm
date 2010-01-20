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
   'port' => 9999,               # インベントリ通知待ち受けポート．0ならNFS経由
   'abort_check_interval' => 19, # abortになったジョブをチェックする間隔(sec)
   'inventory_path' => File::Spec->catfile(Cwd::getcwd(), 'inv_watch'),
                                 # ジョブの履歴や，port==0では通信用ファイルを書き込むディレクトリ
   'stack_size' => 32768,        # Perlスレッドのスタックサイズ
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
