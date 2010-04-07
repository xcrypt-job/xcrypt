package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_jobids
cmd_executable wait_file exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
xcr_d xcr_e xcr_mkdir xcr_symlink xcr_copy xcr_unlink xcr_qx xcr_pull xcr_push);

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
sub cmd_executable ($) {
    my ($cmd) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    unless (@{$xcropt::options{rhost}} == ()) {
	qx/$rsh_command ${$xcropt::options{rhost}}[0] which $cmd0[0]/;
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
    unless (@{$xcropt::options{rhost}} == ()) {
	my $fullpath = File::Spec->catfile($xcropt::options{rwd}, $dir);
	$flag = qx/$rsh_command ${$xcropt::options{rhost}}[0] test -d $fullpath && echo 1;/;
	chomp($flag);
    } else {
	if (-d $dir) { $flag = 1; }
    }
    return $flag;
}

sub xcr_e {
    my ($file) = @_;
    my $flag = 0;
    unless (@{$xcropt::options{rhost}} == ()) {
	my $fullpath = File::Spec->catfile($xcropt::options{rwd}, $file);
	$flag = qx/$rsh_command ${$xcropt::options{rhost}}[0] test -f $fullpath && echo 1;/;
	chomp($flag);
    } else {
	if (-e $file) { $flag = 1; }
    }
    return $flag;
}

sub xcr_mkdir {
    my ($dir) = @_;
    unless (@{$xcropt::options{rhost}} == ()) {
	my $rdir = File::Spec->catfile($xcropt::options{rwd}, $dir);
	qx/$rsh_command ${$xcropt::options{rhost}}[0] mkdir $rdir/;
    }
}

sub xcr_unlink {
    my ($file) = @_;
    unless (@{$xcropt::options{rhost}} == ()) {
	my $flag = &xcr_e($file);
	if ($flag) {
	    my $tmp = File::Spec->catfile($xcropt::options{rwd}, $file);
	    qx/$rsh_command ${$xcropt::options{rhost}}[0] rm -f $tmp/;
	}
    } else {
	unlink $file;
    }
}

sub xcr_symlink {
    my ($dir, $file, $link) = @_;
    unless (@{$xcropt::options{rhost}} == ()) {
	my $tmp = File::Spec->catfile($xcropt::options{rwd}, $dir, $link);
	qx/$rsh_command ${$xcropt::options{rhost}}[0] ln -s $file $tmp/;
    } else {
	symlink($file, File::Spec->catfile($dir, $link));
    }
}

sub xcr_qx {
    my ($cmd, $dir) = @_;
    my @ret;
    unless (@{$xcropt::options{rhost}} == ()) {
	if ($dir) {
	    my $tmp = "cd " . File::Spec->catfile($xcropt::options{rwd}, $dir) . "; $cmd";
	    @ret = qx/$rsh_command ${$xcropt::options{rhost}}[0] \"$tmp\"/;
	} else {
	    @ret = qx/$rsh_command ${$xcropt::options{rhost}}[0] $cmd/;
	}
    } else {
	if ($dir) {
	    @ret = qx/cd $dir; $cmd/;
	} else {
	    @ret = qx/$cmd/;
	}
    }
}

=comment
sub xcr_open {
    my ($fh, $mode, $file) = @_;
    if (defined $xcropt::options{rhost}) {
	my $rhost = $xcropt::options{rhost};
	my $fullpath = File::Spec->catfile($xcropt::options{rwd}, $file);
	my $tmpdir_file = File::Spec->catfile($xcropt::options{tmp}, $file);
	$file = $tmpdir_file;
	if ($mode eq '<'){
	    qx/$rcp_command $rhost:$fullpath $tmpdir_file/;
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
	    qx/$rcp_command $tmpdir_file $rhost:$fullpath /;
	}
    }
#    close($fh);
}
=cut

sub xcr_pull {
    my ($file) = @_;
    unless ($xcropt::options{shared}) {
	my $remote = File::Spec->catfile($xcropt::options{rwd}, $file);
	qx/$rcp_command ${$xcropt::options{rhost}}[0]:$remote $file/;
	qx/$rsh_command ${$xcropt::options{rhost}}[0] rm -f $remote/;
    }
}

sub xcr_copy {
    my ($copied, $dir) = @_;
    unless (@{$xcropt::options{rhost}} == ()) {
	unless ($xcropt::options{shared}) {
	    my $fp_copied = File::Spec->catfile($xcropt::options{rwd}, $copied);
	    my $fp_dir = File::Spec->catfile($xcropt::options{rwd}, $dir);
	    qx/$rsh_command ${$xcropt::options{rhost}}[0] cp -f $fp_copied $fp_dir/;
	}
    } else {
	fcopy($copied, $dir);
    }
}

sub xcr_push {
    my ($file) = @_;
    unless ($xcropt::options{shared}) {
	my $remote = File::Spec->catfile($xcropt::options{rwd}, $file);
	qx/$rcp_command $file ${$xcropt::options{rhost}}[0]:$remote/;
	unlink $file;
    }
}

1;

