package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_job_ids
cmd_executable exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
rmt_get rmt_put
rmt_qx rmt_exist rmt_mkdir rmt_copy rmt_rename rmt_symlink rmt_unlink
xcr_qx xcr_exist xcr_mkdir xcr_copy xcr_rename xcr_symlink xcr_unlink
wait_and_get_file
get_all_envs
);

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Basename;
#use strict;
use Cwd;
use File::Spec;
use Coro::AnyEvent;
use Net::OpenSSH;

my %ssh_opts = (
    copy_attrs => 1,   # -pと同じ。オリジナルの情報を保持
    recursive => 1,    # -rと同じ。再帰的にコピー
    bwlimit => 40000,  # -lと同じ。転送量のリミットをKbit単位で指定
    glob => 1,         # ファイル名に「*」を使えるようにする。
    quiet => 1,        # 進捗を表示する
    );

our %Host_Ssh_Hash;
our @Env;
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
sub cmd_executable {
    my ($cmd, $self) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if (defined $self->{env}->{host}) {
	if ($self->{env}->{is_local} == 0) {
	    my $ssh = $Host_Hash{$self};
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

sub rmt_qx {
    my ($cmd, $env) = @_;
    my $ssh = $Host_Ssh_Hash{$env->{host}};
    my @ret;
    @ret = $ssh->capture("$cmd") or die "remote command failed: ". $ssh->error;
    return @ret;
}

##
sub xcr_qx {
    my ($cmd, $dir, $env) = @_;
#print "$ssh\n";
    my @ret;
    unless ($env->{is_local} == 1) {
	my $tmp = 'cd ' . $env->{wd} . "; $cmd";
	@ret = &rmt_qx("$tmp", $env);
    } else {
	@ret = qx/cd $dir; $cmd/;
    }
    return @ret;
}

sub rmt_exist {
    my ($type, $file, $env) = @_;
    my @flags;

    my $fullpath = File::Spec->catfile($env->{wd}, $file);
    my $ssh = $Host_Ssh_Hash{$env->{host}};
    @flags = $ssh->capture("test $type $fullpath && echo 1");
    chomp($flags[0]);

    return $flags[0];
}

sub xcr_exist {
    my ($type, $file, $env) = @_;
    my $flag;
    unless ($env->{is_local} == 1) {
	$flag = &rmt_exist($type, $file, $env);
    } else {
	if (-e $file) { $flag = 1; }
    }
    return $flag;
}

sub rmt_mkdir {
    my ($dir, $env) = @_;
    my $flag = &rmt_exist('-d', $dir, $env);
    unless ($flag) {
	unless ($env->{is_local} == 1) {
	    my $rdir = File::Spec->catfile($env->{wd}, $dir);
	    &rmt_qx("mkdir $rdir", $env);
	}
    }
}

sub xcr_mkdir {
    my ($dir, $env) = @_;
    my $flag = &xcr_exist('-d', $dir, $env);
    unless ($flag) {
	unless ($env->{is_local} == 1) {
	    &rmt_mkdir($dir, $env);
	} else {
	    mkdir $dir, 0755;
	}
    }
}

sub rmt_copy {
    my ($copied, $dir, $env) = @_;
    unless ($xcropt::options{shared}) {
	my $fp_copied = File::Spec->catfile($env->{wd}, $copied);
	my $fp_dir = File::Spec->catfile($env->{wd}, $dir);
	&rmt_qx("cp -f $fp_copied $fp_dir", $env);
    }
}

sub xcr_copy {
    my ($copied, $dir, $env) = @_;
    unless ($env->{is_local} == 1) {
	&rmt_copy($copied, $dir, $env);
    } else {
	fcopy($copied, $dir);
    }
}

sub rmt_rename {
    my ($file0, $file1, $env) = @_;
    my $flag = &remoter_exist('-f', $file0, $env);
    if ($flag) {
	my $tmp0 = File::Spec->catfile($env->{wd}, $file0);
	my $tmp1 = File::Spec->catfile($env->{wd}, $file1);
	&rmt_qx("mv -f $tmp0 $tmp1", $env);
    }
}

sub xcr_rename {
    my ($file0, $file1, $env) = @_;
    unless ($env->{is_local} == 1) {
	&rmt_rename($file0, $file1, $env);
    } else {
	rename $file0, $file1;
    }
}

sub rmt_symlink {
    my ($dir, $file, $link, $env) = @_;
    my $ex0 = &rmt_exist('-f', $file, $env);
    my $ex1 = &rmt_exist('-h', File::Spec->catfile($dir, $link), $env);
    if ($ex0 && !$ex1) {
	unless ($ex1) {
	    my $tmp = File::Spec->catfile($env->{wd}, $dir, $link);
	    my $file1 = File::Spec->catfile($env->{wd}, $file);
	    &rmt_qx("ln -s $file1 $tmp", $env);
	}
    } else {
	warn "Can't link to $file";
    }
}

sub xcr_symlink {
    my ($dir, $file, $link, $env) = @_;
    unless ($env->{is_local} == 1) {
	&rmt_symlink($dir, $file, $link, $env);
    } else {
	if (-f $file) {
	    unless (-e $link) {
		symlink(File::Spec->rel2abs($file),
			File::Spec->catfile($dir, $link));
	    }
	} else {
	    warn "Can't link to $file";
	}
    }
}

sub rmt_unlink {
    my ($file, $env) = @_;
    my $flag = &rmt_exist('-f', $file, $env);
    if ($flag) {
	my $tmp = File::Spec->catfile($env->{wd}, $file);
	&rmt_qx("rm -f $tmp", $env);
    }
}

sub xcr_unlink {
    my ($file, $env) = @_;
    unless ($env->{is_local} == 1) {
	&rmt_unlink($file, $env);
    } else {
	unlink $file;
    }
}

sub rmt_get {
    my ($base, $env) = @_;
    unless ($env->{is_local} == 1) {
	unless ($xcropt::options{shared}) {
	    my $file = File::Spec->catfile($env->{wd}, $base);
	    my $ssh = $Host_Ssh_Hash{$env->{host}};
	    $ssh->scp_get(\%ssh_opts, "$file", "$base") or die "get failed: " . $ssh->error;
	}
    }
}

sub rmt_put {
    my ($base, $env) = @_;
    unless ($env->{is_local} == 1) {
	unless ($xcropt::options{shared}) {
	    my $file = File::Spec->catfile($env->{wd}, $base);
	    my $ssh = $Host_Ssh_Hash{$env->{host}};
	    $ssh->scp_put(\%ssh_opts, "$base", "$file") or die "put failed: " . $ssh->error;
	}
    }
}

sub get_all_envs {
    return @Env;
}

##
sub wait_and_get_file {
    my ($path, $interval) = @_;
    my @envs = &get_all_envs();
  LABEL: while (1) {
      foreach my $env (@envs) {
	  if ($env->{is_local} == 1) {
	      last LABEL if (-e $path)
	  } else {
	      my $tmp = &rmt_exist('-e', $path, $env);
	      if ($tmp) {
		  &rmt_rename($path, $path.'.tmp', $env);
		  &rmt_get($path.'.tmp', $env);
		  unless (-e $path) {
		      rename $path.'.tmp', $path;
		      &rmt_unlink($path.'.tmp', $env);
		  }
		  last LABEL;
	      }
	  }
      }
      Coro::AnyEvent::sleep ($interval);
  }
}

1;

