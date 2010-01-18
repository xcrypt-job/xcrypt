package bulk;

use strict;
use builtin;
use jobsched;
use Cwd;
use File::Basename;
use File::Spec;
use jsconfig;

&addkeys('bulkedjobs');

sub bulk {
    my $id = shift;
    my @jobs = @_;
    my %frame = $jobs[0];
    $frame{'id'} = "$id";
    $frame{'exe'} = '';
    $frame{'bulkedjobs'} = \@jobs;
    my $bulk = user->new(\%frame);
    return ($bulk);
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    my $dir = $self->{id};

    # 前回done, finishedになったジョブならとばす．
    my $stat = &jobsched::get_job_status($self->{id});
    if ( $stat eq 'done' ) {
        print "Skipping " . $self->{id} . " because already $stat.\n";
    } else {
        $self->{request_id} = &qsub($self);
#	&jobsched::wait_job_done($self->{id});
    }
}





# 以下はjobsched.pmのコピーを改変したもの．
# TODO: モジュール化してコードの重複をなくす．
sub qsub {
    my $self = shift;

    my $job_name = $self->{id};
    my $dir = $self->{id};

my $current_directory=Cwd::getcwd();
my $jobsched = $ENV{'XCRJOBSCHED'};

### Inventory
my $inventory_host = qx/hostname/;
chomp $inventory_host;
my $inventory_port = $xcropt::options{port};           # インベントリ通知待ち受けポート．0ならNFS経由(unstable!)
my $inventory_path=$xcropt::options{inventory_path};
my $reqids_file=File::Spec->catfile($inventory_path, '.request_ids');

my $write_command = undef;
if ($inventory_port > 0) {
    $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'bin', 'inventory_write_sock.pl');
} else {
    $write_command=File::Spec->catfile($ENV{'XCRYPT'}, 'bin', 'inventory_write_file.pl');
}
# for inventory_write_file
my $LOCKDIR = File::Spec->rel2abs(File::Spec->catfile($inventory_path, 'inventory_lock'));
my $REQUESTFILE = File::Spec->rel2abs(File::Spec->catfile($inventory_path, 'inventory_req'));
my $ACKFILE = File::Spec->rel2abs(File::Spec->catfile($inventory_path, 'inventory_ack'));
my $REQUEST_TMPFILE = $REQUESTFILE . '.tmp';
my $ACK_TMPFILE = $ACKFILE . '.tmp';
rmdir $LOCKDIR;
unlink $REQUEST_TMPFILE, $REQUESTFILE, $ACK_TMPFILE, $ACKFILE;


    ### <-- Create job script file <--
    ## Preamble
    my $scriptfile = File::Spec->catfile($dir, $jobsched . '.sh');
    open (SCRIPT, ">$scriptfile");
    print SCRIPT "#!/bin/sh\n";
    # NQS も SGE も，オプション中の環境変数を展開しないので注意！
    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_preamble} ) {
        foreach (@{$jsconfig::jobsched_config{$jobsched}{jobscript_preamble}}) {
            print SCRIPT $_ . "\n";
        }
    }

    ## Options
    # queue
    my $queue = $self->{queue};
        print SCRIPT $queue . "\n";
#    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_queue} ) {
#        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_queue}, $queue) . "\n";
#    }
    # stderr & stdout
    my $stdofile;
    $stdofile = File::Spec->catfile($dir, $self->{stdofile} ? $self->{stdofile} : 'stdout');
    if ( -e $stdofile) { unlink $stdofile; }
    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_stdout} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_stdout}, $ENV{'PWD'}.'/'.$stdofile) . "\n";
    }
    my $stdefile;
    $stdefile = File::Spec->catfile($dir, $self->{stdefile} ? $self->{stdefile} : 'stderr');
    if ( -e $stdefile) { unlink $stdefile; }
    if ( defined $jsconfig::jobsched_config{$jobsched}{jobscript_stderr} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_stderr}, $ENV{'PWD'}.'/'.$stdefile) . "\n";
    }
    # computing resources
    my $proc = $self->{proc};
    if ( $proc ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_proc} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_proc}, $proc) . "\n";
    }
    my $cpu = $self->{cpu};
    if ( $cpu ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_cpu} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_cpu}, $cpu) . "\n";
    }
    my $memory = $self->{memory};
    if ( $memory ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_memory} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_memory}, $memory) . "\n";
    }
    my $stack = $self->{stack};
    if ( $stack ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_stack} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_stack}, $stack) . "\n";
    }
    # verbosity
    my $verbose = $self->{verbose};
    if ( $verbose ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_verbose} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_verbose}) . "\n";
    }
    my $verbose_node = $self->{verbose_node};
    if ( $verbose_node ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_verbose_node} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_verbose_node}) . "\n";
    }
    # other options
    # computing resources
    my $group = $self->{group};
    if ( $group ne '' && defined $jsconfig::jobsched_config{$jobsched}{jobscript_group} ) {
        print SCRIPT any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_group}, $group) . "\n";
    }
    my $option = $self->{option};
    print SCRIPT "$option\n";

    ## Commands
    # print SCRIPT "PATH=$ENV{'PATH'}\n";
    # print SCRIPT "set -x\n";
    # Move to the job directory
print SCRIPT inventory_write_cmdline($job_name, "running") . " || exit 1\n";
foreach my $subself (@{$self->{'bulkedjobs'}}) {
my $dir = $subself->{id};
    my $wkdir_str = defined ($jsconfig::jobsched_config{$jobsched}{jobscript_workdir})
        ? any_to_string_nl ($jsconfig::jobsched_config{$jobsched}{jobscript_workdir})
        : $ENV{'PWD'};
    print SCRIPT "cd " . File::Spec->catfile ($wkdir_str, $dir) . "\n";

    # Set job's status "running"
#    print SCRIPT inventory_write_cmdline($job_name, "running") . " || exit 1\n";

    # Execute a program
    my @args = ();
    for ( my $i = 0; $i <= $user::maxargetc; $i++ ) { push(@args, $subself->{"arg$i"}); }
    my $cmd = $subself->{exe} . ' ' . join(' ', @args);
    print SCRIPT "$cmd\n";
    # 正常終了でなければ "aborted" を書き込むべき？

    # Set job's status "done"
#    print SCRIPT inventory_write_cmdline($job_name, "done") . " || exit 1\n";
}
print SCRIPT inventory_write_cmdline($job_name, "done") . " || exit 1\n";
    close (SCRIPT);
    ### --> Create job script file -->

    ### <-- Create qsub options <--
    my $qsub_options = '';
    # stderr & stdout
    if ( defined $jsconfig::jobsched_config{$jobsched}{qsub_stdout_option} ) {
        $qsub_options .= " ". any_to_string_spc ($jsconfig::jobsched_config{$jobsched}{qsub_stdout_option}, $stdofile);
    }
    if ( defined $jsconfig::jobsched_config{$jobsched}{qsub_stderr_option} ) {
        $qsub_options .= " ". any_to_string_spc ($jsconfig::jobsched_config{$jobsched}{qsub_stderr_option}, $stdefile);
    }
    ### --> Create qsub options -->

    # Set job's status "submitted"
    inventory_write ($job_name, "submitted");

    my $qsub_command = $jsconfig::jobsched_config{$jobsched}{qsub_command};
    unless ( defined $qsub_command ) {
        die "qsub_command is not defined in $jobsched.pm";
    }
    if (common::cmd_executable ($qsub_command)) {
        # ここでqsubコマンド実行
        # print STDERR "$qsub_command $qsub_options $scriptfile\n";
        my @qsub_output = qx/$qsub_command $qsub_options $scriptfile/;
        my $req_id;
        # Get request ID from qsub's output
        if ( defined ($jsconfig::jobsched_config{$jobsched}{extract_req_id_from_qsub_output}) ) {
            unless ( ref $jsconfig::jobsched_config{$jobsched}{extract_req_id_from_qsub_output} eq 'CODE' ) {
                die "Error in $jobsched.pm: extract_req_id_from_qsub_output must be a function";
            }
            $req_id = &{$jsconfig::jobsched_config{$jobsched}{extract_req_id_from_qsub_output}} (@qsub_output);
        } else { # default extractor
            $req_id = ($qsub_output[0] =~ /([0-9]+)/) ? $1 : -1;
        }
        if ( $req_id < 0 ) { die "Can't extract request ID from qsub output." }
        # Remember request ID
        my $idfile = File::Spec->catfile($dir, 'request_id');
        open (REQUESTID, ">> $idfile");
        print REQUESTID $req_id;
        close (REQUESTID);
        open (REQUESTIDS, ">> $reqids_file");
        print REQUESTIDS $req_id . ' ' . $dir . ' ';
        close (REQUESTIDS);
        set_job_request_id ($self->{id}, $req_id);
        # Set job's status "queued"
        inventory_write ($job_name, "queued");
        return $req_id;
    } else {
        die "$qsub_command is not executable";
    }
}

sub before {}

sub after {}

1;
