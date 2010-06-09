package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_job_ids
cmd_executable wait_and_get_file exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
remote_unlink remote_qx remote_system remote_mkdir remote_xcr
xcr_get_all xcr_get xcr_put xcr_exist xcr_mkdir xcr_symlink xcr_copy xcr_unlink
xcr_qx xcr_system xcr_rename);

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Basename;
#use strict;
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
    my ($cmd, $env) = @_;
    my $ssh = $builtin::Host_Ssh_Hash{$env->{host}};
    my @ret;
    @ret = $ssh->capture("$cmd") or die "remote command failed: " . $ssh->error;
    return @ret;
}

sub remote_system {
    my ($cmd, $host) = @_;
    my $ssh = $builtin::Host_Ssh_Hash{$env->{host}};
    my @ret;
    @ret = $ssh->system("$cmd") or die "remote command failed: " . $ssh->error;
    return @ret;
}

##
sub cmd_executable {
    my ($cmd, $self) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if (defined $self->{env}->{host}) {
	if ($self->{env}->{is_local} == 0) {
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
sub wait_and_get_file {
    my ($path, $interval) = @_;
    my @envs = &builtin::get_all_envs();
  LABEL: while (1) {
      foreach my $env (@envs) {
	  my $tmp = &xcr_exist('-e', $path, $env);
	  if ($tmp) {
	      &xcr_rename($path, $path.'.tmp', $env);
	      &xcr_get($path.'.tmp', $env);
	      unless (-e $path) {
		  rename $path.'.tmp', $path;
		  &remote_unlink($path.'.tmp', $env);
	      }
	      last LABEL if ($tmp);
	  }
      }
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
    my ($cmd, $dir, $env) = @_;
#print "$ssh\n";
    my @ret;
    unless ($env->{is_local} == 1) {
	my $tmp = 'cd ' . $env->{wd} . "; $cmd";
	@ret = &remote_qx("$tmp", $env->{host});
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
    return @ret;
}

sub xcr_system {
    my ($cmd, $dir, $env) = @_;
    my @ret;
    unless ($env->{is_local} == 1) {
	my $tmp = 'cd ' . File::Spec->catfile($env->{wd}, $env->{host}, $env->{wd}) . "; $cmd";
	@ret = &remote_system("$tmp", $env->{host});
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
    return @ret;
}

sub xcr_exist {
    my ($type, $file, $env) = @_;
    my @flags;
    unless ($env->{is_local} == 1) {
	my $fullpath = File::Spec->catfile($env->{wd}, $file);
	my $ssh = $builtin::Host_Ssh_Hash{$env->{host}};
	@flags = $ssh->capture("test $type $fullpath && echo 1");
	chomp($flags[0]);
    } else {
	if (-e $file) { $flags[0] = 1; }
    }
    return $flags[0];
}

sub remote_exist {
    my ($type, $file, $env) = @_;
    my @flags;

    my $fullpath = File::Spec->catfile($env->{wd}, $file);
    my $ssh = $builtin::Host_Ssh_Hash{$env->{host}};
    @flags = $ssh->capture("test $type $fullpath && echo 1");

    chomp($flags[0]);

    return $flags[0];
}

sub remote_mkdir {
    my ($dir, $env) = @_;
    my $flag = &remote_exist('-d', $dir, $env);
    unless ($flag) {
	unless ($env->{is_local} == 1) {
	    my $rdir = File::Spec->catfile($env->{wd}, $dir);
	    &remote_qx("mkdir $rdir", $env);
	}
    }
}

sub xcr_mkdir {
    my ($dir, $env) = @_;
    my $flag = &xcr_exist('-d', $dir, $env);
    unless ($flag) {
	unless ($env->{is_local} == 1) {
	    my $rdir = File::Spec->catfile($env->{wd}, $dir);
	    &remote_qx("mkdir $rdir", $env);
	} else {
	    mkdir $dir, 0755;
	}
    }
}

sub xcr_copy {
    my ($copied, $dir, $env) = @_;
    unless ($env->{is_local} == 1) {
	unless ($xcropt::options{shared}) {
	    my $fp_copied = File::Spec->catfile($env->{wd}, $copied);
	    my $fp_dir = File::Spec->catfile($env->{wd}, $dir);
	    &remote_qx("cp -f $fp_copied $fp_dir", $env);
	}
    } else {
	fcopy($copied, $dir);
    }
}

sub xcr_rename {
    my ($file0, $file1, $env) = @_;
    unless ($env->{is_local} == 1) {
	my $flag = &xcr_exist('-f', $file0, $env);
	if ($flag) {
	    my $tmp0 = File::Spec->catfile($env->{wd}, $file0);
	    my $tmp1 = File::Spec->catfile($env->{wd}, $file1);
	    &remote_qx("mv -f $tmp0 $tmp1", $env);
	}
    } else {
	rename $file0, $file1;
    }
}

sub xcr_symlink {
    my ($dir, $file, $link, $env) = @_;
    my $ex0 = &xcr_exist('-f', $file, $env);
    my $ex1 = &xcr_exist('-h', File::Spec->catfile($dir, $link), $env);
    unless ($env->{is_local} == 1) {
	if ($ex0 && !$ex1) {
	    unless ($ex1) {
		my $tmp = File::Spec->catfile($env->{wd}, $dir, $link);
		my $file1 = File::Spec->catfile($env->{wd}, $file);
		&remote_qx("ln -s $file1 $tmp", $env);
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
    my ($file, $env) = @_;
    unless ($env->{is_local} == 1) {
	my $flag = &xcr_exist('-f', $file, $env);
	if ($flag) {
	    my $tmp = File::Spec->catfile($env->{wd}, $file);
	    &remote_qx("rm -f $tmp", $env);
	}
    } else {
	unlink $file;
    }
}

sub remote_unlink {
    my ($file, $env) = @_;
    unless ($env->{is_local} == 1) {
	my $flag = &xcr_exist('-f', $file, $env);
	if ($flag) {
	    my $tmp = File::Spec->catfile($env->{wd}, $file);
	    &remote_qx("rm -f $tmp", $env);
	}
    }
}

sub xcr_get {
    my ($base, $env) = @_;
    unless ($env->{is_local} == 1) {
	unless ($xcropt::options{shared}) {
	    my $file = File::Spec->catfile($env->{wd}, $base);
	    my $ssh = $builtin::Host_Ssh_Hash{$env->{host}};
	    $ssh->scp_get(\%ssh_opts, "$file", "$base") or die "get failed: " . $ssh->error;
	}
    }
}

sub xcr_put {
    my ($base, $env) = @_;
    unless ($env->{is_local} == 1) {
	unless ($xcropt::options{shared}) {
	    my $file = File::Spec->catfile($env->{wd}, $base);
	    my $ssh = $builtin::Host_Ssh_Hash{$env->{host}};
	    $ssh->scp_put(\%ssh_opts, "$base", "$file") or die "put failed: " . $ssh->error;
	    unlink $base;
	}
    }
}

1;

