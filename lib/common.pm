package common;

use strict;
use Cwd;
use File::Spec;

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

1;
