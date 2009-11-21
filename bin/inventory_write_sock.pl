#!/usr/bin/perl
use IO::Socket;
use strict;
use Time::HiRes;

$|=1;
select(STDERR); $|=1; select(STDOUT);

my $log;
open ($log, ">> invwrite-sock.log");
select($log); $|=1; select(STDOUT);

if ( @ARGV < 4 ) {
    print $log "usage: $0 [hostname] [port] [jobname] [status]\n";
    exit -1;
}

my $host = $ARGV[0];
my $port = $ARGV[1];

my $jobname = $ARGV[2];
my $status = $ARGV[3];

my $retry = 1;

while ($retry) {
    my $socket = 0;
    my $n_trial = 0;
    until ($socket) {
        if ( 0 ) {
            die "Failed to connect $host:$port. $!\n";
        }
        $n_trial++;
        $socket = IO::Socket::INET->new (PeerAddr => $host,
                                         PeerPort => $port,
                                         Proto => 'tcp',
        );
        unless ($socket) {
            my $slp = 0.1+rand(1.0);
            print $log "Failed to connect $host:$port. Retry after $slp seconds.\n";
            Time::HiRes::sleep $slp;
        }
    }
    select($socket); $|=1; select(STDOUT);
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
    
    print $log "$jobname\[$status\]: waiting ack\n";
    my $ackline =  <$socket>;
    chomp $ackline;
    if ( $ackline =~ /^:ack/ ) {
        $retry = 0;
    } elsif ( $ackline =~ /^:failed/ ) {
        my $slp = 0.1+rand(1.0);
        Time::HiRes::sleep $slp;
    } else {
        die "Unexpected ack message: $ackline";
    }
    print $log "$jobname\[$status\]: received $ackline\n";
    $socket->close();
}

print $log "$jobname\[$status\]: successfully done\n";
close($log);
