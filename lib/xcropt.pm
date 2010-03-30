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
     'rhost' => undef,
     'rwd' => undef,
     'localhost' => $localhost,
     'port' => 9999, # インベントリ通知待ち受けポート．0ならNFS経由
#     'scheduler' => $ENV{'XCRJOBSCHED'}, # Default job scheduler
     'scheduler' => undef, # 実行時に与えられなければデフォルト値を設定するという実装に変更した
     'abort_check_interval' => 19, # abortになったジョブをチェックする間隔(sec)
#     'inventory_path' => File::Spec->catfile(Cwd::getcwd(), 'inv_watch'),
     'inventory_path' => 'inv_watch', # ローカルとリモートとで同じ名前で別のフルパスにしたかったので相対パスで指定するようにした
     # ジョブの履歴や，port==0では通信用ファイルを書き込むディレクトリ
     'verbose' => 0,               # verbose level
     'stack_size' => 32768,        # Perlスレッドのスタックサイズ
     # define other default values...
    );

GetOptions
    (\%options,
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

unless (defined $xcropt::options{'scheduler'}) {
    if (defined $xcropt::options{'rhost'}) {
	my $rxcrjsch = qx/rsh $xcropt::options{'rhost'} 'echo \$XCRJOBSCHED'/;
	chomp($rxcrjsch);
	$xcropt::options{'scheduler'} = $rxcrjsch;
    } else {
	$xcropt::options{'scheduler'} = $ENV{'XCRJOBSCHED'};
    }
}

1;
