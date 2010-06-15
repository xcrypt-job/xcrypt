#!/usr/bin/perl
use strict;
use Error qw(:try);
use Time::HiRes;
use FindBin qw($Bin);
use lib $Bin;
use xcrypt_comm;

if ( @ARGV < 3
     || !(($ARGV[2] eq 'sock' && @ARGV == 6)
          || $ARGV[2] eq 'file' && @ARGV == 7))
{
    print STDERR "usage: $0 [job_id] [status] sock [hostname] [port] [timeout]\n";
    print STDERR "       $0 [job_id] [status] file [lockdir] [sendfile] [ackfile] [timeout]\n";
    exit -1;
}

my $Job_ID = shift (@ARGV);
my $Status = shift (@ARGV);
my $Logfile = "${Job_ID}_invwrite.log";
my $Left_Msg_File = "${Job_ID}_is_$Status";
my @Comm_Start_Args = @ARGV;
my $Handler = undef;

sub message {
    my $tim = time();
    return ":transition $Job_ID $Status $tim\n";
}

my $Retry = 1; my $Retry_Max = 300;
xcrypt_comm_log_start ($Logfile, "$Job_ID\[$Status\]: ");
try {
    while ($Retry) {
        $Handler = xcrypt_comm_start (@Comm_Start_Args);
        unless ($Handler) { throw Error::Simple ("xcrypt_comm_start failed."); }
        ###
        my $ackline = xcrypt_comm_send ($Handler, message(), 1); # 1 means an ack is necessary.
        unless ($ackline) { throw Error::Simple ("xcrypt_comm_send failed."); }
        xcrypt_comm_finish ($Handler);
        $Handler = undef;
        if ( $ackline =~ /^:ack/ ) {
            $Retry = 0;
        } elsif ( $ackline =~ /^:failed/ ) {
            $Retry++;
            if ( $Retry > $Retry_Max ) { throw Error::Simple ("Too many :failed messages.");}
            my $slp = 0.1+rand(1.0);
            Time::HiRes::sleep $slp;
        } else {
            throw Error::Simple ("Unexpected ack message: $ackline");
        }
    }
    xcrypt_comm_log ("successfully done\n");
} catch Error::Simple with {
    my $err = shift;
    xcrypt_comm_log ($err->{-text}."\n");
    # Leave a message when the communication failed
    open (my $left, '>>', $Left_Msg_File);
    print $left message();
    close ($left);
    xcrypt_comm_log ("Message left to $Left_Msg_File\n");
} finally {
    xcrypt_comm_finish ($Handler);
    xcrypt_comm_log_finish ();
};
