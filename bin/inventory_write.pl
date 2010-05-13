#!/usr/bin/perl
use strict;
use Time::HiRes;
use xcrypt_comm;

my $Logfile = 'invwrite-sock.log';

if ( @ARGV < 3
     || !(($ARGV[2] eq 'sock' && @ARGV == 5)
          || $ARGV[2] eq 'file' && @ARGV == 6))
{
    print STDERR "usage: $0 [jobname] [status] sock [hostname] [port]\n";
    print STDERR "       $0 [jobname] [status] file [lockdir] [requestfile] [ackfile]\n";
    exit -1;
}

my $Jobname = shift (@ARGV);
my $Status = shift (@ARGV);
my @Comm_Start_Args = @ARGV;

my $RETRY_P = 1;

while ($RETRY_P) {
    xcrypt_comm_log_start ($Logfile, "$Jobname\[$Status\]: ");
    my $handler=undef;
    $handler = xcrypt_comm_start (@Comm_Start_Args);
    ###
    my $time_now = time();
    my @times = localtime($time_now);
    my ($year, $mon, $mday, $hour, $min, $sec, $wday) = ($times[5] + 1900, $times[4] + 1, $times[3], $times[2], $times[1], $times[0], $times[6]);
    my $timestring = sprintf("%04d%02d%02d_%02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
    my $ackline = xcrypt_comm_send ($handler,
                                    "spec: $Jobname\n".
                                    "status: $Status\n".
                                    "date_$Status: $timestring\n".
                                    "time_$Status: $time_now\n",
                                    1);
    xcrypt_comm_finish ($handler);
    if ( $ackline =~ /^:ack/ ) {
        $RETRY_P = 0;
    } elsif ( $ackline =~ /^:failed/ ) {
        my $slp = 0.1+rand(1.0);
        Time::HiRes::sleep $slp;
    } else {
        die "Unexpected ack message: $ackline";
    }
}

xcrypt_comm_log ("successfully done\n");
xcrypt_comm_log_finish ();
