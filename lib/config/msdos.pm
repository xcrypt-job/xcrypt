# Config file for msdos
use config_common;
use File::Spec;
use File::Basename qw(basename);
my $myname = basename(__FILE__, '.pm');
$jsconfig::jobsched_config{$myname} = {
    # commands
    qsub_command => File::Spec->catfile("$ENV{XCRYPT}", 'lib', 'config', 'run-output-pid.bat '),
#    qsub_command => 'perl ' . File::Spec->catfile("$ENV{XCRYPT}", 'lib', 'config', 'run-output-pid.pl') . ' ',
    qdel_command => "taskkill ",
    qstat_command => "tasklist ",
    # standard options
    jobscript_workdir => sub { '.'; },
    qsub_option_stdout => workdir_file_option(' ', 'stdout'),
    qsub_option_stderr => workdir_file_option(' ', 'stderr'),
    extract_req_id_from_qsub_output => sub {
        my (@lines) = @_;
        if ($lines[0] =~ /([0-9]*)/) {
            return $1;
        } else {
            return -1;
        }
    },
    extract_req_ids_from_qstat_output => sub {
        my (@lines) = @_;
        my @ids = ();
        foreach (@lines) {
            if ($_ =~ /^\s*([0-9]+)/) {
                push (@ids, $1);
            }
        }
        return @ids;
    },
};
