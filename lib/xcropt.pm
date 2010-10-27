# Get Xcrypt command-line options
package xcropt;

use strict;
use Cwd;
use Getopt::Long;

my @ARGV_ORIG = @ARGV;

my $localhost = qx/hostname/;
chomp $localhost;
my $username = qx/whoami/;
chomp $username;
my $wd = Cwd::getcwd();

our %options = (
#    'localhost' => $localhost,  # Obsolete
    'host' => $username . '@' . $localhost,
    'wd' => $wd,
    'xd' => $ENV{XCRYPT},
    'p5l' => $ENV{PERL5LIB},
    'sched' => $ENV{XCRJOBSCHED},
    #
#    'port' => 0, # インベントリ通知待ち受けポート．0ならNFS経由  # Obsolete
#    'comm_timeout' => 60, # timeout for inventory_write.pl       # Obsolete
    'abort_check_interval' => 19, # abortになったジョブをチェックする間隔(sec)
    'left_message_check_interval' => 2, # inventory_write.pl が残したメッセージをチェックする間隔(sec)
    'inventory_path' => 'inv_watch',
    #
    'verbose' => 0,               # verbose level
    'stack_size' => 32768,        # Perlスレッドのスタックサイズ
    # define other default values...
    );

GetOptions
    (\%options,
     'shared',
     'scratch',
     #
#     'localhost=s',  # Obsolete
     'host=s',
     'wd=s',
     'xd=s',
     'p5l=s',
     'sched=s',
     #
#     'port=i',         # Obsolete
#     'comm_timeout=i', # Obsolete
     'abort_check_interval=i',
     'left_message_check_interval=i',
     'inventory_path=s',
     #
     'verbose=i',
     'stack_size=i',
     # define other command-line options...
    );

@ARGV = @ARGV_ORIG;

1;
