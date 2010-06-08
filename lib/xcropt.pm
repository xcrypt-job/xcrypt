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
     'port' => 9999, # インベントリ通知待ち受けポート．0ならNFS経由
     'wd' => $wd,
     'xd' => $ENV{XCRYPT},
     'scheduler' => $ENV{XCRJOBSCHED},
     'abort_check_interval' => 19, # abortになったジョブをチェックする間隔(sec)
     'inventory_path' => 'inv_watch', # ジョブの履歴や，port==0では通信用ファイルを書き込むディレクトリ．ローカルとリモートとで同じ名前で別のフルパスにしたかったので相対パスで指定するようにした．
     'verbose' => 0,               # verbose level
     'stack_size' => 32768,        # Perlスレッドのスタックサイズ
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
