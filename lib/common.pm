package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_jobids cmd_executable wait_file
exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
xcr_d xcr_e xcr_mkdir xcr_symlink xcr_copy xcr_rcp xcr_rename xcr_unlink xcr_qx xcr_open xcr_close xcr_pull xcr_push);

use File::Copy::Recursive qw(fcopy dircopy rcopy);
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
# used in bin/xcryptgui only
=comment
sub get_jobids {
    my $current_directory=Cwd::getcwd();
    my $inventory_path=File::Spec->catfile($current_directory, 'inv_watch');
    my $idfiles = File::Spec->catfile($inventory_path, 'request_ids');
    open(JOBIDS, "< $idfiles");
    my %reqid_jobids = split(' ', <JOBIDS>);
    my %count;
    my @vals = values(%reqid_jobids);
    @vals = grep(!$count{$_}++, @vals);
    my @jobids = sort @vals;
    close(JOBIDS);

    return @jobids;
}
=cut
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
##
sub write_string_array {
    my $file = shift;
    open (my $out, '>', $file);
    foreach (@_) {
        print $out "$_\n";
    }
    close ($out);
}

##
sub xcr_d {
    my ($dir) = @_;
    my $flag = 0;
    if (defined $xcropt::options{rhost}) {
	my $fullpath = File::Spec->catfile($xcropt::options{rwd}, $dir);
	$flag = qx/rsh $xcropt::options{rhost} test -d $fullpath && echo 1;/;
	chomp($flag);
    } else {
	if (-d $dir) { $flag = 1; }
    }
    return $flag;
}

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
}

sub xcr_rename {
    my ($source, $target) = @_;
    if (defined $xcropt::options{rhost}) {
	my $tmp_source = File::Spec->catfile($xcropt::options{tmp}, $source);
	my $tmp_target = File::Spec->catfile($xcropt::options{rwd}, $target);
	qx/rsh $xcropt::options{rhost} cp -f $tmp_source $tmp_target/;
	unlink $tmp_target;
    } else {
	rename $source, $target;
    }
}

sub xcr_copy {
    my ($copied, $dir) = @_;
    if (defined $xcropt::options{rhost}) {
	my $tmp_copied = File::Spec->catfile($xcropt::options{rwd}, $copied);
	my $tmp_dir = File::Spec->catfile($xcropt::options{rwd}, $dir);
	qx/rsh $xcropt::options{rhost} cp -f $tmp_copied $tmp_dir/;
    } else {
	fcopy($copied, $dir);
    }
}

sub xcr_rcp {
    my ($copied, $dir) = @_;
    if (defined $xcropt::options{rhost}) {
	my $tmp_copied = $copied;
	my $tmp_dir = File::Spec->catfile($xcropt::options{rwd}, $dir);
	my $tmp = $xcropt::options{rhost} .':'. $tmp_dir;
	qx/rcp $tmp_copied $tmp/;
    } else {
	fcopy($copied, $dir);
    }
}

sub xcr_unlink {
    my ($file) = @_;
    if (defined $xcropt::options{rhost}) {
	my $flag = &xcr_e($file);
	if ($flag) {
	    my $rhost = $xcropt::options{rhost};
	    my $tmp = File::Spec->catfile($xcropt::options{rwd}, $file);
	    qx/rsh $rhost rm -f $tmp/;
	}
    } else {
	unlink $file;
    }
}

sub xcr_symlink {
    my ($dir, $file, $link) = @_;
    if (defined $xcropt::options{rhost}) {
	my $tmp = File::Spec->catfile($xcropt::options{rwd}, $dir, $link);
	qx/rsh $xcropt::options{rhost} ln -s $file $tmp/;
    } else {
	symlink($file, File::Spec->catfile($dir, $link));
    }
}

sub xcr_qx {
    my ($cmd, $dir) = @_;
    my @ret;
    if (defined $xcropt::options{rhost}) {
	if ($dir) {
	    my $tmp = "cd " . File::Spec->catfile($xcropt::options{rwd}, $dir) . '; ' . "$cmd";
	    @ret = qx/rsh $xcropt::options{rhost} \"$tmp\"/;
	} else {
	    @ret = qx/rsh $xcropt::options{rhost} $cmd/;
	}
    } else {
	if ($dir) {
	    @ret = qx/cd $dir; $cmd/;
	} else {
	    @ret = qx/$cmd/;
	}
    }
}

sub xcr_open {
    my ($fh, $mode, $file) = @_;
    if (defined $xcropt::options{rhost}) {
	my $rhost = $xcropt::options{rhost};
	my $fullpath = File::Spec->catfile($xcropt::options{rwd}, $file);
	my $tmpdir_file = File::Spec->catfile($xcropt::options{tmp}, $file);
	$file = $tmpdir_file;
	if ($mode eq '<'){
	    qx/rcp $rhost:$fullpath $tmpdir_file/;
	}
    }
    open($fh, $mode, $file);
}

sub xcr_close {
    my ($fh, $mode, $file) = @_;
    if (defined $xcropt::options{rhost}) {
	my $rhost = $xcropt::options{rhost};
	my $fullpath = File::Spec->catfile($xcropt::options{rwd}, $file);
	my $tmpdir_file = File::Spec->catfile($xcropt::options{tmp}, $file);
	if ($mode eq '>') {
	    qx/rcp $tmpdir_file $rhost:$fullpath /;
	}
    }
#    close($fh);
}

sub xcr_pull {
    my ($file) = @_;
    my $rhost = $xcropt::options{rhost};
    my $remote = File::Spec->catfile($xcropt::options{rwd}, $file);
    my $tmp = File::Spec->catfile($xcropt::options{tmp}, $file);
    qx/rcp $rhost:$remote $tmp/;
    qx/rsh $rhost rm -f $remote/;
    rename $tmp, $file;
}

sub xcr_push {
    my ($file) = @_;
    my $rhost = $xcropt::options{rhost};
    my $remote = File::Spec->catfile($xcropt::options{rwd}, $file);
    my $tmp = File::Spec->catfile($xcropt::options{tmp}, $file);
    rename $file, $tmp;
    unlink $file;
    qx/rcp $tmp $rhost:$remote/;
}

1;

