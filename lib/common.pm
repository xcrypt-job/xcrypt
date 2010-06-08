package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_jobids
cmd_executable wait_file exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
xcr_get_all xcr_get xcr_put xcr_exist xcr_mkdir xcr_symlink xcr_copy xcr_unlink
xcr_qx xcr_system xcr_rename);

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Basename;
use strict;
use Cwd;
use File::Spec;
use Coro::AnyEvent;
use Net::OpenSSH;
use builtin;

my %ssh_opts = (
    copy_attrs => 1,   # -pと同じ。オリジナルの情報を保持
    recursive => 1,    # -rと同じ。再帰的にコピー
    bwlimit => 40000,  # -lと同じ。転送量のリミットをKbit単位で指定
    glob => 1,         # ファイル名に「*」を使えるようにする。
    quiet => 1,        # 進捗を表示する
    );

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

sub remote_qx {
    my ($cmd, $host) = @_;
    my $ssh = &builtin::get_ssh_object_by_host($host);
    my @ret;
    print $cmd, "\n";
    print $host, "\n";
    @ret = $ssh->capture("$cmd") or die "remote command failed: " . $ssh->error;
    return @ret;
}

sub remote_system {
    my ($cmd, $host) = @_;
    my $ssh = &builtin::get_ssh_object_by_host($host);
    my @ret;
    @ret = $ssh->system("$cmd") or die "remote command failed: " . $ssh->error;
    return @ret;
}

##
sub cmd_executable {
    my ($cmd, $self) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if (defined $self->{host}) {
	unless ($self->{host} eq 'localhost') {
	    my $ssh = $builtin::Host_Hash{$self};
	    $ssh->system("$cmd0[0]") or die "remote command failed: " . $ssh->error;
	}
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
    until (-e $path) {
	Coro::AnyEvent::sleep ($interval);
    }
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
sub xcr_qx {
    my ($cmd, $dir, $host, $wd) = @_;
    my @ret;
    unless ($host eq 'localhost') {
	my $tmp = 'cd ' . File::Spec->catfile($wd, $host, $wd) . "; $cmd";
	@ret = &remote_qx("$tmp", $host);
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
    return @ret;
}

sub xcr_system {
    my ($cmd, $dir, $host, $wd) = @_;
    my @ret;
    unless ($host eq 'localhost') {
	my $tmp = 'cd ' . File::Spec->catfile($wd, $host, $wd) . "; $cmd";
	@ret = &remote_system("$tmp", $host);
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
    return @ret;
}

sub xcr_exist {
    my ($type, $file, $host, $wd) = @_;
    my @flags;
    unless ($host eq 'localhost') {
	my $fullpath = File::Spec->catfile($wd, $file);
	my $ssh = &builtin::get_ssh_object_by_host($host);
	@flags = $ssh->capture("test $type $fullpath && echo 1");
	chomp($flags[0]);
    } else {
	if (-e $file) { $flags[0] = 1; }
    }
    return $flags[0];
}

sub xcr_mkdir {
    my ($dir, $host, $wd) = @_;
    my $flag = &xcr_exist('-d', $dir, $host, $wd);
    unless ($flag) {
	unless ($host eq 'localhost') {
	    my $rdir = File::Spec->catfile($wd, $dir);
	    &remote_qx("mkdir $rdir", $host);
	}
    }
}

sub xcr_copy {
    my ($copied, $dir, $host, $wd) = @_;
    unless ($host eq 'localhost') {
	unless ($xcropt::options{shared}) {
	    my $fp_copied = File::Spec->catfile($wd, $copied);
	    my $fp_dir = File::Spec->catfile($wd, $dir);
	    &remote_qx("cp -f $fp_copied $fp_dir", $host);
	}
    } else {
	fcopy($copied, $dir);
    }
}

sub xcr_rename {
    my ($file0, $file1, $host, $wd) = @_;
    unless ($host eq 'localhost') {
	my $flag = &xcr_exist('-f', $file0, $host, $wd);
	if ($flag) {
	    my $tmp0 = File::Spec->catfile($wd, $file0);
	    my $tmp1 = File::Spec->catfile($wd, $file1);
	    &remote_qx("mv -f $tmp0 $tmp1", $host);
	}
    } else {
	rename $file0, $file1;
    }
}

sub xcr_symlink {
    my ($dir, $file, $link, $host, $wd) = @_;
    my $ex0 = &xcr_exist('-f', $file, $host, $wd);
    my $ex1 = &xcr_exist('-h', File::Spec->catfile($dir, $link), $host, $wd);
    unless ($host eq 'localhost') {
	if ($ex0 && !$ex1) {
	    unless ($ex1) {
		my $tmp = File::Spec->catfile($wd, $dir, $link);
		my $file1 = File::Spec->catfile($wd, $file);
		&remote_qx("ln -s $file1 $tmp", $host);
	    }
	} else {
	    warn "Can't link to $file";
	}
    } else {
	if ($ex0 && !$ex1) {
	    symlink(File::Spec->rel2abs($file),
		    File::Spec->catfile($dir, $link));
	} else {
	    warn "Can't link to $file";
	}
    }
}

sub xcr_unlink {
    my ($file, $host, $wd) = @_;
    unless ($host, $wd->{rhost} eq 'localhost') {
	my $flag = &xcr_exist('-f', $file, $host, $wd);
	if ($flag) {
	    my $tmp = File::Spec->catfile($wd, $file);
	    &remote_qx("rm -f $tmp", $host);
	}
    } else {
	unlink $file;
    }
}

sub xcr_get {
    my ($base, $host, $wd) = @_;
    unless ($host eq 'localhost') {
	unless ($xcropt::options{shared}) {
	    my $file = File::Spec->catfile($wd, $base);
	    my $ssh = &builtin::get_ssh_object_by_host($host);
	    $ssh->scp_get(\%ssh_opts, "$file", "$base") or die "get failed: " . $ssh->error;
	    &xcr_unlink($file, $host, $wd);
	}
    }
}

sub xcr_put {
    my ($base, $host, $wd) = @_;
    unless ($host eq 'localhost') {
	unless ($xcropt::options{shared}) {
	    my $file = File::Spec->catfile($wd, $base);
	    my $ssh = &builtin::get_ssh_object_by_host($host);
	    $ssh->scp_put(\%ssh_opts, "$base", "$file") or die "put failed: " . $ssh->error;
	    unlink $base;
	}
    }
}


1;

