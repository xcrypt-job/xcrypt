package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_jobids cmd_executable wait_file exec_async
                 any_to_string any_to_string_nl any_to_string_spc xcr_e xcr_mkdir xcr_symlink xcr_qx);

use strict;
use Cwd;
use File::Spec;
use Coro::AnyEvent;

##
sub mkarray ($) {
    my $x = shift;
    if ( ref($x) eq 'ARRAY' ) {
        return $x;
    } elsif ( $x ) {
        return [$x];
    } else {
        return [];   
    }
}

##
sub set_member_if_empty ($$$) {
    my ($refobj, $member, $newval) = @_;
    unless ($refobj->{$member}) { $refobj->{$member} = $newval; }
}

##
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

##
sub cmd_executable ($) {
    my ($cmd) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if (defined $xcropt::options{rhost}) {
	qx/rsh $xcropt::options{rhost} which $cmd0[0]/;
    } else {
	qx/which $cmd0[0]/;
    }
    my $ex_code = $? >> 8;
    # print "$? $ex_code ";
    return ($ex_code==0)? 1 : 0;
}

##
sub wait_file {
    my ($path, $interval) = @_;
    until ( -e $path ) { Coro::AnyEvent::sleep ($interval); }
}

##
sub exec_async ($@) {
    my @args = @_;
    my $pid = fork();
    if ($pid == 0) {
        exec @args
            or die "Failed to exec @args: $!";
    } else {
        return $pid;
    }
}

##
# (separator, any_obj, optional_args...) -> String
sub any_to_string ($@) {
    my ($arraysep, $x, @args) = @_;
    my $r = ref ($x);
    if ( $r eq '' ) {             # $x is a scalar
        return $x . join(' ', @args);
    } elsif ( $r eq 'ARRAY' ) {   # $arraysep works only here
        return join ($arraysep, @$x) . $arraysep . join($arraysep, @args);
    } elsif ( $r eq 'CODE' ) {
        return &$x(@args);
    } elsif ( $r eq 'SCALAR' ) {  # $x is *a reference to* a scalar
        return $$x . join(' ', @args);
    } else {
        die "any_to_string: Unexpected reference $r";
    }
}
sub any_to_string_nl  (@) { any_to_string ("\n", @_); }
sub any_to_string_spc (@) { any_to_string (" ", @_); }

sub xcr_e {
    my ($file) = @_;
    my $flag = 0;
    if (defined $xcropt::options{rhost}) {
	my $fullpath = File::Spec->catfile($xcropt::options{rwd}, $file);
	$flag = qx/rsh $xcropt::options{rhost} test -f $fullpath && echo 1;/;
	chomp($flag);
    } else {
	if (-e $file) { $flag = 1; }
    }
    return $flag;
}

sub xcr_mkdir {
    my ($dir) = @_;
    if (defined $xcropt::options{rhost}) {
	my $rdir = File::Spec->catfile($xcropt::options{rwd}, $dir);
	qx/rsh $xcropt::options{rhost} mkdir $rdir/;
    }
    mkdir $dir, 0755;
}

sub xcr_symlink {
    my ($file, $link) = @_;
    if (defined $xcropt::options{rhost}) {
	qx/rsh $xcropt::options{rhost} ln -s $file $link/;
    } else {
	symlink($file, $link);
    }
}

sub xcr_qx {
    my ($cmd, $dir) = @_;
    my @ret;
    if (defined $xcropt::options{rhost}) {
	if ($dir) {
	    my $tmp = "cd " . File::Spec->catfile($xcropt::options{rwd}, $dir) . '; ' . "$cmd";
	    @ret = qx/rsh $xcropt::options{rhost} \"$tmp\"/;
	}
    } else {
	if ($dir) {
	    @ret = qx/cd $dir; $cmd/;
	} else {
	    @ret = qx/$cmd/;
	}
    }
}

1;

