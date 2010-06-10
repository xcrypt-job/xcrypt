package xcrypt_comm;

use base qw(Exporter);
our @EXPORT = qw(
xcrypt_comm_log_start xcrypt_comm_log xcrypt_comm_log_finish
xcrypt_comm_start xcrypt_comm_send xcrypt_comm_finish
);

use strict;
use Cwd;
use File::Basename;
use File::Spec;
use FileHandle; 
use IO::Socket;
use Time::HiRes;
use common;

my $Log=undef;
my $Log_Header='';

# for comm_file
my $Try_Lock_Interval = 0.1;
my $Try_Lock_Interval_Max = 3;
my $Lock_Retry = 0;      # number of retry. 0 for unlimited.
my $Ack_Interval = 0.1;
    
##################################################
### Utils for comm_file
sub get_lockdir {
    my ($lockdir, $interval, $interval_max, $retry) = @_;
    while (!mkdir($lockdir, 0755)) {
        # no limit if $retry = 0
        if (--$retry == 0) {
            xcrypt_comm_log ("Failed to get lockdir.\n");
            return 0;
        }
        xcrypt_comm_log ("Failed to get lockdir. Retry after $interval seconds.\n");
        Time::HiRes::sleep ($interval);
        if (($interval*=2) > $interval_max) { $interval = $interval_max*(1-rand(0.5)); }
    }
    xcrypt_comm_log ("Successfully got lockdir $lockdir.\n");
    return 1;
}
sub release_lockdir {
    my $lockdir = shift; # arg1: lock directory name
    my $succ = 0;
    unless (-e $lockdir) {
        xcrypt_comm_log ("release_lockdir called, but $lockdir does not exist.\n");
    } else {
        until ($succ) {
	    $succ = rmdir ($lockdir);
        }
        xcrypt_comm_log ("Successfully released lockdir $lockdir.\n");
    }
}
sub wait_file {
    my ($path, $interval) = @_;
    until ( -e $path ) { Time::HiRes::sleep ($interval); }
}

##################################################
### Logging
sub xcrypt_comm_log_start {
    my $file = shift;       # arg1: log file name
    my $log_header = shift; # arg2: header string for each message (optional)
    if ($Log) { close ($Log); }
    open ($Log, ">> $file");
    select($Log); $|=1; select(STDOUT);
    if ($log_header) { $Log_Header = $log_header; }
    return $Log;
}

sub xcrypt_comm_log {
    if ($Log) {
        print $Log "${Log_Header}$_[0]";
    }
}

sub xcrypt_comm_log_finish {
    if ($Log) {
        close ($Log);
        $Log=undef;
        $Log_Header='';
    }
    return 1;
}

##################################################
### start
sub xcrypt_comm_start
{
    my $meth = shift; # arg1: communication method. One of 'sock', 'file'
    my @rest = @_;    # rest_args: required information to communicate with Xcrypt
                      #  'sock' => (host, port)
                      #  'file' => (lockdir, sendfile, ackfile)
    if ( $meth =~ /^sock/ ) {
        return (xcrypt_comm_start_sock (@rest));
    } elsif ( $meth =~ /^file/ ) {
        return (xcrypt_comm_start_file (@rest));
    } else {
        die "Unexpected communication method: $meth";
    }
}

sub xcrypt_comm_start_sock
{
    my $host = shift; # arg1: hostname where Xcrypt is running
    my $port = shift; # arg2: TCP port number which Xcypt accepts
    my $socket = 0;
    until ($socket) {
        $socket = IO::Socket::INET->new (PeerAddr => $host,
                                         PeerPort => $port,
                                         Proto => 'tcp',
        );
        unless ($socket) {
            my $slp = 0.1+rand(1.0);
            xcrypt_comm_log ("Failed to connect $host:$port. Retry after $slp seconds.\n");
            Time::HiRes::sleep $slp;
        }
    }
    xcrypt_comm_log ("Connection to Xcrypt process succeeded.\n");
    ## Returns comm handler
    return { 'method' => 'sock', 'sock' => $socket };
}

sub xcrypt_comm_start_file
{
    my $lockdir = shift;  # arg1: Common lock directory name to resolve contention
    my $sendfile = shift; # arg2: File name to write send message
    my $ackfile = shift;  # arg3: File name to receive ack message
    unless (get_lockdir ($lockdir, $Try_Lock_Interval, $Try_Lock_Interval_Max, $Lock_Retry)) {
        return 0; # failed
    }
    ## Returns comm handler
    return { 'method' => 'file',
             'lockdir' => $lockdir,
             'sendfile' => $sendfile, 'sendfile_tmp' => "$sendfile.tmp",
             'ackfile' => $ackfile
    };
}

##################################################
### Finish
sub xcrypt_comm_finish {
    my $handler = shift; # arg1: comm handler
    xcrypt_comm_log ("communication done.\n");
    if ( $handler->{method} eq 'sock' ) {
        return xcrypt_comm_finish_sock ($handler);
    } elsif ( $handler->{method} eq 'file' ) {
        return xcrypt_comm_finish_file ($handler);
    } else {
        die "Unexpected handler method: $handler->{method}";
    }
}

sub xcrypt_comm_finish_sock {
    my $handler = shift; # arg1: comm handler
    $handler->{sock}->close();
    return 1;
}

sub xcrypt_comm_finish_file {
    my $handler = shift; # arg1: comm handler
    unlink $handler->{sendfile_tmp}, $handler->{sendfile}, $handler->{ackfile};
    release_lockdir ($handler->{lockdir});
}

##################################################
### Send
sub xcrypt_comm_send {
    my $handler = shift;  # arg1: comm handler
    my $str = shift;      # arg2: string to send
    my $need_ack = shift; # arg3: whether ack is required
    if ( $handler->{method} eq 'sock' ) {
        return xcrypt_comm_send_sock ($handler, $str, $need_ack);
    } elsif ( $handler->{method} eq 'file' ) {
        return xcrypt_comm_send_file ($handler, $str, $need_ack);
    } else {
        die "Unexpected handler method: $handler->{method}";
    }
}

sub xcrypt_comm_send_sock {
    my $handler = shift;  # arg1: comm handler
    my $str = shift;      # arg2: string to send
    my $need_ack = shift; # arg3: whether ack is required
    $handler->{sock}->print ($str);
    $handler->{sock}->print ($need_ack?":end\n":":end_noack\n");
    if ( $need_ack ) {
        xcrypt_comm_log ("waiting ack.\n");
        my $ackline = $handler->{sock}->getline();
        chomp $ackline;
        xcrypt_comm_log ("received $ackline.\n");
        return $ackline;
    } else {
        return 1;
    }
}

sub xcrypt_comm_send_file {
    my $handler = shift ; # arg1: comm handler
    my $str = shift;      # arg2: string to send
    my $need_ack = shift; # arg3: whether ack is required
    my $fp_tmp = new FileHandle "> $handler->{sendfile_tmp}";
    unless (defined $fp_tmp) {
        xcrypt_comm_log ("Failed to open requestfile $handler->{sendfile_tmp}\n");
        return 0; # failed
    }
    $fp_tmp->print($str);
    $fp_tmp->print($need_ack?":end\n":":end_noack\n");
    $fp_tmp->close();
    rename $handler->{sendfile_tmp}, $handler->{sendfile};
    if ( $need_ack ) {
        xcrypt_comm_log ("waiting ack.\n");
        wait_file ($handler->{ackfile}, $Ack_Interval);
        open (my $ack, '<', $handler->{ackfile});
        unless ($ack) {
            my $err = $!;
            xcrypt_comm_log ("Failed to open ackfile $handler->{ackfile}\n");
            return 0;
        }
        my $ackline = <$ack>;
        close ($ack);
        chomp $ackline;
        xcrypt_comm_log ("received $ackline\n");
        return $ackline;
    } else {
        return 1;
    }
}

1;
