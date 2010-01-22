#!/usr/bin/perl
use IO::Socket;
use strict;
use Time::HiRes;

$|=1;
select(STDERR); $|=1; select(STDOUT);

my $LOG = undef;
open ($LOG, '>>', 'invwrite-file.log');
select($LOG); $|=1; select(STDOUT);

if ( @ARGV < 4 ) {
    print STDERR "usage: $0 [lockdir] [requestfile] [ackfile] [jobname] [status]\n";
    exit -1;
}
my $LOCKDIR = $ARGV[0];
my $REQUESTFILE = $ARGV[1];
my $ACKFILE = $ARGV[2];
my $JOBNAME = $ARGV[3];
my $STATUS = $ARGV[4];

my $REQUEST_TMPFILE = $REQUESTFILE . '.tmp';
my $ACK_TMPFILE = $ACKFILE . '.tmp';

my $LOCK_INTERVAL = 0.1; my $LOCK_INTERVAL_MAX = 3;
my $LOCK_RETRY = 0;   # no limit if 0
my $FAIL_RETRY_INTERVAL = 0.1; my $FAIL_RETRY_INTERVAL_MAX = 5;
my $ACK_INTERVAL = 0.1;

my $RETRY_P = 1;

##################################################
sub get_lockdir {
    my ($lockdir, $interval, $interval_max, $retry) = @_;
    while (!mkdir($lockdir, 0755)) {
        # no limit if $retry = 0
        if (--$retry == 0) {
            print $LOG "$JOBNAME\[$STATUS\]: Failed to get lockdir.\n";
            cleanup();
            exit -1;
        }
        print $LOG "$JOBNAME\[$STATUS\]: Failed to get lockdir. Retry after $interval seconds.\n";
        Time::HiRes::sleep ($interval);
        if (($interval*=2) > $interval_max) { $interval = $interval_max*(1-rand(0.5)); }
    }
    print $LOG "$JOBNAME\[$STATUS\]: Successfully got lockdir.\n";
}
sub release_lockdir {
    my $succ = 0;
    unless (-e $_[0]) {
        print $LOG "$JOBNAME\[$STATUS\]: release_lockdir called, but $_[0] not exists.\n";
    } else {
        until ($succ) {
            $succ = rmdir ($_[0]);
        }
        print $LOG "$JOBNAME\[$STATUS\]: Successfully released lockdir.\n";
    }
}
sub wait_file {
    my ($path, $interval) = @_;
    until ( -e $path ) { Time::HiRes::sleep ($interval); }
}
sub cleanup {
    unlink $REQUEST_TMPFILE, $REQUESTFILE, $ACK_TMPFILE, $ACKFILE;
    release_lockdir ($LOCKDIR);
}
##################################################

while ($RETRY_P) {
    get_lockdir ($LOCKDIR, $LOCK_INTERVAL, $LOCK_INTERVAL_MAX, $LOCK_RETRY);
    open (my $req, '>', $REQUEST_TMPFILE);
    unless ($req) {
        my $err = $!;
        print $LOG "$JOBNAME\[$STATUS\]: Failed to open requestfile $REQUEST_TMPFILE\n";
        cleanup();
        die $err;
    }
    select($req); $|=1; select(STDOUT);
    ###
    my $time_now = time();
    my @times = localtime($time_now);
    my ($year, $mon, $mday, $hour, $min, $sec, $wday) = ($times[5] + 1900, $times[4] + 1, $times[3], $times[2], $times[1], $times[0], $times[6]);
    my $timestring = sprintf("%04d%02d%02d_%02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
    print $req "spec: $JOBNAME\n";
    print $req "status: $STATUS\n";
    print $req "date_$STATUS: $timestring\n";
    print $req "time_$STATUS: $time_now\n";
    print $req ":end\n";
    close ($req);
    rename $REQUEST_TMPFILE, $REQUESTFILE;
    ###
    print $LOG "$JOBNAME\[$STATUS\]: waiting ack\n";
    wait_file ($ACKFILE, $ACK_INTERVAL);
    open (my $ack, '<', $ACKFILE);
    unless ($ack) {
        my $err = $!;
        print $LOG "$JOBNAME\[$STATUS\]: Failed to open ackfile $ACKFILE\n";
        cleanup();
        die $err;
    }
    my $ackline =  <$ack>;
    close ($ack);
    chomp $ackline;
    print $LOG "$JOBNAME\[$STATUS\]: received $ackline\n";
    cleanup();
    if ( $ackline =~ /^:ack/ ) {
        $RETRY_P = 0;
    } elsif ( $ackline =~ /^:failed/ ) {
        print $LOG "$JOBNAME\[$STATUS\]: retry after $FAIL_RETRY_INTERVAL seconds.\n";
        Time::HiRes::sleep $FAIL_RETRY_INTERVAL;
        if (($FAIL_RETRY_INTERVAL*=2) > $FAIL_RETRY_INTERVAL_MAX)
        { $FAIL_RETRY_INTERVAL = $FAIL_RETRY_INTERVAL_MAX*(1-rand(0.5)); }
        next;
    } else {
        die "Unexpected ack message: $ackline";
    }
}

print $LOG "$JOBNAME\[$STATUS\]: successfully done\n";
close($LOG);
