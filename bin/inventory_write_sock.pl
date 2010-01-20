#!/usr/bin/perl
use strict;
use IO::Socket;
use Time::HiRes;

$|=1;
select(STDERR); $|=1; select(STDOUT);

my $LOG;
open ($LOG, ">> invwrite-sock.log");
select($LOG); $|=1; select(STDOUT);

if ( @ARGV < 4 ) {
    print STDERR "usage: $0 [hostname] [port] [jobname] [status]\n";
    exit -1;
}

my $HOST = $ARGV[0];
my $PORT = $ARGV[1];
my $JOBNAME = $ARGV[2];
my $STATUS = $ARGV[3];

my $RETRY_P = 1;

my $trial_limit = 10;
while ($RETRY_P) {
    my $socket = 0;
    my $n_trial = 0;
    until ($socket) {
        if ( 0 ) {
#        if ( $n_trial > $trial_limit ) {
            die "Failed to connect $HOST:$PORT. $!\n";
        }
        $n_trial++;
        $socket = IO::Socket::INET->new (PeerAddr => $HOST,
                                         PeerPort => $PORT,
                                         Proto => 'tcp',
        );
        unless ($socket) {
            my $slp = 0.1+rand(1.0);
            print $LOG "$JOBNAME\[$STATUS\]: Failed to connect $HOST:$PORT. Retry after $slp seconds.\n";
            Time::HiRes::sleep $slp;
        }
    }
    print $LOG "$JOBNAME\[$STATUS\]: Connection to Xcrypt process succeeded.\n";
    select($socket); $|=1; select(STDOUT);
    ###
    my $time_now = time();
    my @times = localtime($time_now);
    my ($year, $mon, $mday, $hour, $min, $sec, $wday) = ($times[5] + 1900, $times[4] + 1, $times[3], $times[2], $times[1], $times[0], $times[6]);
    my $timestring = sprintf("%04d%02d%02d_%02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
    print $socket "spec: $JOBNAME\n";
    print $socket "status: $STATUS\n";
    print $socket "date_$STATUS: $timestring\n";
    print $socket "time_$STATUS: $time_now\n";
    print $socket ":end\n";
    ###
    print $LOG "$JOBNAME\[$STATUS\]: waiting ack\n";
    my $ackline =  <$socket>;
    chomp $ackline;
    print $LOG "$JOBNAME\[$STATUS\]: received $ackline\n";
    if ( $ackline =~ /^:ack/ ) {
        $RETRY_P = 0;
    } elsif ( $ackline =~ /^:failed/ ) {
        my $slp = 0.1+rand(1.0);
        Time::HiRes::sleep $slp;
    } else {
        die "Unexpected ack message: $ackline";
    }
    $socket->close();
}

print $LOG "$JOBNAME\[$STATUS\]: successfully done\n";
close($LOG);
