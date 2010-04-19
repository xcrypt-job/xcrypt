package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_jobids
cmd_executable wait_file exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
xcr_exist xcr_mkdir xcr_symlink xcr_copy xcr_unlink xcr_qx xcr_pull xcr_push);

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Basename;
use strict;
use Cwd;
use File::Spec;
use Coro::AnyEvent;

my $rsh_command = $xcropt::options{rsh};
my $rcp_command = $xcropt::options{rcp};

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
sub cmd_executable {
    my ($cmd, $host) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if ($host) {
	qx/$rsh_command $host which $cmd0[0]/;
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
sub xcr_exist {
    my ($type, $file, $rhost, $rwd) = @_;
    my $flag = 0;
    unless ($rhost eq 'localhost' || $rhost eq '') {
	my $fullpath = File::Spec->catfile($rwd, $file);
	$flag = qx/$rsh_command $rhost test $type $fullpath && echo 1;/;
	chomp($flag);
    } else {
	if (-e $file) { $flag = 1; }
    }
    return $flag;
}

sub xcr_mkdir {
    my ($dir, $rhost, $rwd) = @_;
    my $flag = &xcr_exist('-d', $dir, $rhost, $rwd);
    unless ($flag) {
	unless ($rhost eq 'localhost' || $rhost eq '') {
	    my $rdir = File::Spec->catfile($rwd, $dir);
	    qx/$rsh_command $rhost mkdir $rdir/;
	}
    }
}

sub xcr_unlink {
    my ($file, $rhost, $rwd) = @_;
    unless ($rhost eq 'localhost' || $rhost eq '') {
	my $flag = &xcr_exist('-f', $file, $rhost, $rwd);
	if ($flag) {
	    my $tmp = File::Spec->catfile($rwd, $file);
	    qx/$rsh_command $rhost rm -f $tmp/;
	}
    } else {
	unlink $file;
    }
}

sub xcr_symlink {
    my ($dir, $file, $link, $rhost, $rwd) = @_;
    my $ex0 = &xcr_exist('-f', $file, $rhost, $rwd);
    my $ex1 = &xcr_exist('-h', $link, $rhost, $rwd);
    unless ($rhost eq 'localhost' || $rhost eq '') {
	if ($ex0 && !$ex1) {
	    unless ($ex1) {
		my $tmp = File::Spec->catfile($rwd, $dir, $link);
		my $file1 = File::Spec->catfile($rwd, $file);
		qx/$rsh_command $rhost ln -s $file1 $tmp/;
	    }
	} else {
	    print "$ex0 $ex1\n";
	    warn "Can't link to $file";
	}
    } else {
	if ($ex0 && !$ex1) {
		symlink(File::Spec->rel2abs($file), File::Spec->catfile($dir, $link));
	} else {
	    warn "Can't link to $file";
	}
    }
}

sub xcr_qx {
    my ($cmd, $dir, $rhost, $rwd) = @_;
    my @ret;
    unless ($rhost eq 'localhost' || $rhost eq '') {
	my $tmp = "cd " . File::Spec->catfile($rwd, $dir) . "; $cmd";
	@ret = qx/$rsh_command $rhost \"$tmp\"/;
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
}

# sub xcr_open {
#     my ($fh, $mode, $file) = @_;
#     if (defined $xcropt::options{rhost}) {
# 	my $rhost = $xcropt::options{rhost};
# 	my $fullpath = File::Spec->catfile($rwds[0], $file);
# 	my $tmpdir_file = File::Spec->catfile($xcropt::options{tmp}, $file);
# 	$file = $tmpdir_file;
# 	if ($mode eq '<'){
# 	    qx/$rcp_command $rhost:$fullpath $tmpdir_file/;
# 	}
#     }
#     open($fh, $mode, $file);
# }
#
# sub xcr_close {
#     my ($fh, $mode, $file) = @_;
#     if (defined $xcropt::options{rhost}) {
# 	my $rhost = $xcropt::options{rhost};
# 	my $fullpath = File::Spec->catfile($rwds[0], $file);
# 	my $tmpdir_file = File::Spec->catfile($xcropt::options{tmp}, $file);
# 	if ($mode eq '>') {
# 	    qx/$rcp_command $tmpdir_file $rhost:$fullpath /;
# 	}
#     }
#     close($fh);
# }

sub xcr_pull {
    my ($file, $rhost, $rwd) = @_;
    unless ($rhost eq 'localhost' || $rhost eq '') {
	unless ($xcropt::options{shared}) {
	    my $remote = File::Spec->catfile($rwd, $file);
	    qx/$rcp_command $rhost:$remote $file/;
	    qx/$rsh_command $rhost rm -f $remote/;
	}
    }
}

sub xcr_copy {
    my ($copied, $dir, $rhost, $rwd) = @_;
    unless ($rhost eq 'localhost' || $rhost eq '') {
	unless ($xcropt::options{shared}) {
	    my $fp_copied = File::Spec->catfile($rwd, $copied);
	    my $fp_dir = File::Spec->catfile($rwd, $dir);
	    qx/$rsh_command $rhost cp -f $fp_copied $fp_dir/;
	}
    } else {
	fcopy($copied, $dir);
    }
}

sub xcr_push {
    my ($file, $rhost, $rwd) = @_;
    unless ($rhost eq 'localhost' || $rhost eq '') {
	unless ($xcropt::options{shared}) {
	    my $remote = File::Spec->catfile($rwd, $file);
	    qx/$rcp_command $file $rhost:$remote/;
	    unlink $file;
	}
    }
}

1;

