#!/usr/bin/perl
use IO::Socket;
use strict;
use Time::HiRes;

my $retry = 100; # # of connection trial

if ( @ARGV < 4 ) {
    print STDERR "usage: $0 [hostname] [port] [jobname] [status]\n";
    exit -1;
}

my $host = $ARGV[0];
my $port = $ARGV[1];

my $jobname = $ARGV[2];
my $status = $ARGV[3];

if ($status ne 'qsub' ) {
    my $socket = 0;
    my $n_trial = 0;
    until ($socket) {
        if ( $n_trial >= $retry ) {
            die "Failed to connect $host:$port. $!\n";
        }
        $n_trial++;
        $socket = IO::Socket::INET->new (PeerAddr => $host,
                                         PeerPort => $port,
                                         Proto => 'tcp',
        );
        unless ($socket) {
            my $slp = 0.1+rand(1.0);
            print stderr "Failed to connect $host:$port. Retry after $slp seconds.\n";
            Time::HiRes::sleep $slp;
        }
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
    print $socket ":end\n";
    $socket->flush();
    
    while ( <$socket> ) {
        if ( $_ =~ '^:ack' ) { last; }
        else {
            warn "Unexpected ack message: $_";
            last;
        }
    }
    
    $socket->close();
#    print "Successfully written $jobname<=$status.\n";
}
