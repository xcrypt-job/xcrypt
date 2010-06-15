#!/usr/bin/perl
use strict;
use Time::HiRes;
use FindBin qw($Bin);
use lib $Bin;
use xcrypt_comm;

if ( @ARGV < 3
     || !(($ARGV[2] eq 'sock' && @ARGV == 6)
          || $ARGV[2] eq 'file' && @ARGV == 7))
{
    print STDERR "usage: $0 [jobname] [status] sock [hostname] [port] [timeout]\n";
    print STDERR "       $0 [jobname] [status] file [lockdir] [sendfile] [ackfile] [timeout]\n";
    exit -1;
}

my $Jobname = shift (@ARGV);
my $Status = shift (@ARGV);
my $Logfile = "${Jobname}_invwrite.log";
my @Comm_Start_Args = @ARGV;

my $RETRY_P = 1;

xcrypt_comm_log_start ($Logfile, "$Jobname\[$Status\]: ");
while ($RETRY_P) {
    my $handler=undef;
    $handler = xcrypt_comm_start (@Comm_Start_Args);
    ###
    my $time_now = time();
    my $ackline = xcrypt_comm_send ($handler,
                                    ":transition $Jobname $Status $time_now\n",
                                    1); # 1 means an ack is necessary.
    xcrypt_comm_finish ($handler)
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
