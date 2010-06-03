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
     'port' => 9999, # インベントリ通知待ち受けポート．0ならNFS経由
     'scheduler' => undef, # 以前は$ENV{XCRJOBSCHED}であったが実行時に与えられなければ*計算*ホストの環境変数の値を設定するという実装に変更した
     'abort_check_interval' => 19, # abortになったジョブをチェックする間隔(sec)
#     'inventory_path' => File::Spec->catfile(Cwd::getcwd(), 'inv_watch'), # ジョブの履歴や，port==0では通信用ファイルを書き込むディレクトリ
     'inventory_path' => 'inv_watch', # ローカルとリモートとで同じ名前で別のフルパスにしたかったので相対パスで指定するようにした
     'verbose' => 0,               # verbose level
     'stack_size' => 32768,        # Perlスレッドのスタックサイズ
     # リモート実行をコマンドラインで行えることにするかは未定
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
