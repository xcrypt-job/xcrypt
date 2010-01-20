package common;

use strict;
use Cwd;
use File::Spec;
use Time::HiRes;

sub get_jobids {
    my $current_directory=Cwd::getcwd();
    my $inventory_path=File::Spec->catfile($current_directory, 'inv_watch');
    my $idfiles = File::Spec->catfile($inventory_path, '.request_ids');
    open(JOBIDS, "< $idfiles");
    my %reqid_jobids = split(' ', <JOBIDS>);
    my %count;
    my @vals = values(%reqid_jobids);
    @vals = grep(!$count{$_}++, @vals);
    my @jobids = sort @vals;
    close(JOBIDS);

    return @jobids;
}

sub cmd_executable {
    my ($cmd) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    qx/which $cmd0[0]/;
    my $ex_code = $? >> 8;
    # print "$? $ex_code ";
    return ($ex_code==0)? 1 : 0;
}

sub wait_file {
    my ($path, $interval) = @_;
    until ( -e $path ) { Time::HiRes::sleep ($interval); }
}

sub exec_async {
    my @args = @_;
    my $pid = fork();
    if ($pid == 0) {
        exec @args
            or die "Failed to exec @args: $!";
    } else {
        return $pid;
    }
}

1;
