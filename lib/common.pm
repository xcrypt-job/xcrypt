package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_jobids
cmd_executable wait_file exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
xcr_get xcr_put xcr_exist xcr_mkdir xcr_symlink xcr_copy xcr_unlink xcr_qx xcr_system xcr_rename);

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Basename;
use strict;
use Cwd;
use File::Spec;
use Coro::AnyEvent;
use Net::OpenSSH;
use builtin;

my %sftp_opts = (
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

sub remote_qx {
    my ($cmd, $self) = @_;
    my $ssh = $builtin::host_and_object{$self};
    my @ret;
    @ret = $ssh->capture("$cmd") or die "remote command failed: " . $ssh->error;
    return @ret;
}

sub remote_system {
    my ($cmd, $self) = @_;
    my $ssh = $builtin::host_and_object{$self};
    my @ret;
    @ret = $ssh->system("$cmd") or die "remote command failed: " . $ssh->error;
    return @ret;
}

##
sub cmd_executable {
    my ($cmd, $self) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if (defined $self->{rhost}) {
	unless ($self->{rhost} eq 'localhost') {
	    my $ssh = $builtin::host_and_object{$self};
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
sub xcr_qx {
    my ($cmd, $dir, $self) = @_;
    my @ret;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	my $tmp = "cd " . File::Spec->catfile($self->{rwd}, $self) . "; $cmd";
	@ret = &remote_qx("$tmp", $self);
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
    return @ret;
}

sub xcr_system {
    my ($cmd, $dir, $self) = @_;
    my @ret;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	my $tmp = "cd " . File::Spec->catfile($self->{rwd}, $self) . "; $cmd";
	@ret = &remote_system("$tmp", $self);
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
    return @ret;
}

sub xcr_exist {
    my ($type, $file, $self) = @_;
    my @flags;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	my $fullpath = File::Spec->catfile($self->{rwd}, $file);
	my $ssh = $builtin::host_and_object{$self};
	@flags = $ssh->capture("test $type $fullpath && echo 1");
#	chomp($flag);
    } else {
	if (-e $file) { $flags[0] = 1; }
    }
    return $flags[0];
}

sub xcr_mkdir {
    my ($dir, $self) = @_;
    my $flag = &xcr_exist('-d', $dir, $self->{rhost}, $self->{rwd});
    unless ($flag) {
	unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	    my $rdir = File::Spec->catfile($self->{rwd}, $dir);
	    &remote_qx("mkdir $rdir", $self);
	}
    }
}

sub xcr_copy {
    my ($copied, $dir, $self) = @_;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	unless ($xcropt::options{shared}) {
	    my $fp_copied = File::Spec->catfile($self->{rwd}, $copied);
	    my $fp_dir = File::Spec->catfile($self->{rwd}, $dir);
	    &remote_qx("cp -f $fp_copied $fp_dir", $self);
	}
    } else {
	fcopy($copied, $dir);
    }
}

sub xcr_rename {
    my ($file0, $file1, $self) = @_;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	my $flag = &xcr_exist('-f', $file0, $self->{rhost}, $self->{rwd});
	if ($flag) {
	    my $tmp0 = File::Spec->catfile($self->{rwd}, $file0);
	    my $tmp1 = File::Spec->catfile($self->{rwd}, $file1);
	    &remote_qx("mv -f $tmp0 $tmp1", $self);
	}
    } else {
	rename $file0, $file1;
    }
}

sub xcr_symlink {
    my ($dir, $file, $link, $self) = @_;
    my $ex0 = &xcr_exist('-f', $file, $self->{rhost}, $self->{rwd});
    my $ex1 = &xcr_exist('-h', File::Spec->catfile($dir, $link), $self->{rhost}, $self->{rwd});
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	if ($ex0 && !$ex1) {
	    unless ($ex1) {
		my $tmp = File::Spec->catfile($self->{rwd}, $dir, $link);
		my $file1 = File::Spec->catfile($self->{rwd}, $file);
		&remote_qx("ln -s $file1 $tmp", $self);
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
    my ($file, $self) = @_;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	my $flag = &xcr_exist('-f', $file, $self->{rhost}, $self->{rwd});
	if ($flag) {
	    my $tmp = File::Spec->catfile($self->{rwd}, $file);
	    &remote_qx("rm -f $tmp", $self);
	}
    } else {
	unlink $file;
    }
}

sub xcr_get {
    my ($file, $self) = @_;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	unless ($xcropt::options{shared}) {
	    my $remote = File::Spec->catfile($self->{rwd}, $file);
	    if (exists $builtin::host_and_object{$self->{rhost}}) {
		my $tmp = $builtin::host_and_object{$self->{rhost}};
		$tmp->scp_get(\%sftp_opts, "$remote", "$file") or die "get failed: " . $tmp->error;
	    } else {
		die "Add hostname by &add_host";
	    }
	    &xcr_unlink($remote, $self->{rhost}, $self->{rwd});
	}
    }
}

sub xcr_put {
    my ($file, $self) = @_;
    unless ($self->{rhost} eq 'localhost' || $self->{rhost} eq '') {
	unless ($xcropt::options{shared}) {
	    my $remote = File::Spec->catfile($self->{rwd}, $file);
	    if (exists $builtin::host_and_object{$self->{rhost}}) {
		my $tmp = $builtin::host_and_object{$self->{rhost}};
		$tmp->scp_put(\%sftp_opts, "$file", "$remote") or die "put failed: " . $tmp->error;
		unlink $file;
	    } else {
		die "Add hostname by &add_host";
	    }
	}
    }
}


1;

