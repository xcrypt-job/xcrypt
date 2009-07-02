#!/usr/bin/perl
use IO::Socket;
use strict;

if ( @ARGV < 4 ) {
    print STDERR "usage: $0 [hostname] [port] [jobname] [status]\n";
    exit -1;
}

my $host = $ARGV[0];
my $port = $ARGV[1];

my $jobname = $ARGV[2];
my $status = $ARGV[3];

if ($status ne 'qsub' ) {
    my $socket = IO::Socket::INET->new (PeerAddr => $host,
                                        PeerPort => $port,
                                        Proto => 'tcp',
                                        );
    if ( ! $socket ) {
        die "Failed to connect $host:$port. $!\n";
    }
    
    ###
    my $time_now = time();
    my @times = localtime($time_now);
    my ($year, $mon, $mday, $hour, $min, $sec, $wday) = ($times[5] + 1900, $times[4] + 1, $times[3], $times[2], $times[1], $times[0], $times[6]);
    my $timestring = sprintf("%04d%02d%02d_%02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
    
    ###
    print $socket "spec: $jobname\n";
    print $socket "status: $status\n";
    print $socket "date_$status: $timestring\n";
    print $socket "time_$status: $time_now\n";

    $socket->flush();
    $socket->close();
#    print "Successfully written $jobname<=$status.\n";
}
