package common;

use base qw(Exporter);
our @EXPORT = qw(mkarray set_member_if_empty get_job_ids
cmd_executable exec_async
any_to_string any_to_string_nl any_to_string_spc write_string_array
rmt_get rmt_put
rmt_exist rmt_qx rmt_system rmt_mkdir rmt_copy rmt_rename rmt_symlink rmt_unlink
xcr_exist xcr_qx xcr_system xcr_mkdir xcr_copy xcr_rename xcr_symlink xcr_unlink
xcr_chdir_qx
get_all_envs
);

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Basename;
#use strict;
use Cwd;
use File::Spec;
use Coro::AnyEvent;
use Net::OpenSSH;
use xcropt;

my %ssh_opts = (
    copy_attrs => 1,   # -pと同じ。オリジナルの情報を保持
    recursive => 1,    # -rと同じ。再帰的にコピー
    bwlimit => 40000,  # -lと同じ。転送量のリミットをKbit単位で指定
    glob => 1,         # ファイル名に「*」を使えるようにする。
    quiet => 1,        # 進捗を表示する
    );

our %Host_Ssh_Hash;
our $env_d;
$env_d = { 'host'     => $xcropt::options{localhost},
	   'wd'       => $xcropt::options{wd},
	   'sched'    => $xcropt::options{sched},
	   'xd'       => $xcropt::options{xd},
	   'p5l'      => $xcropt::options{p5l},
	   'location' => 'local' };
our @Env = ($env_d);
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
    my ($cmd, $env) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if ($env->{location} eq 'remote') {
	my $ssh = $Host_Ssh_Hash{$env->{host}};
	my $tmp = $ssh->system("which $cmd0[0]") or die "remote command failed: " . $ssh->error;
	if ($tmp == 0) {
	    return 0;
	} else {
	    return 1;
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

sub get_all_envs {
    return @Env;
}

sub rmt_cmd {
    my $cmd = shift;
    my $env = shift;
    my $ssh = $Host_Ssh_Hash{$env->{host}};
    if ($cmd eq 'qx') {
	my ($command, $dir) = @_;
	my $tmp = 'cd ' . File::Spec->catfile($env->{wd}, $dir) . "; $command";
	my @ret = $ssh->capture("$tmp") or die "remote command failed: $ssh->error";
	return @ret;
    } elsif ($cmd eq 'system') {
	my ($command, $dir) = @_;
	my $tmp = 'cd ' . File::Spec->catfile($env->{wd}, $dir) . "; $command";
	my $flag = $ssh->system("$tmp") or die "remote command failed: $ssh->error";
	return $flag;
    } elsif ($cmd eq 'exist') {
	my ($file) = @_;
	my $fullpath = File::Spec->catfile($env->{wd}, $file);
	my @flags = $ssh->capture("test -e $fullpath && echo 1");
	chomp($flags[0]);
	return $flags[0];
    } elsif ($cmd eq 'mkdir') {
	my ($dir) = @_;
	my $fullpath = File::Spec->catfile($env->{wd}, $dir);
	&rmt_cmd('system', $env, "mkdir $fullpath");
    } elsif ($cmd eq 'copy') {
	my ($copied, $dir) = @_;
	my $fp_copied = File::Spec->catfile($env->{wd}, $copied);
	my $fp_dir = File::Spec->catfile($env->{wd}, $dir);
	&rmt_cmd('system', $env, "cp -f $fp_copied $fp_dir");
    } elsif ($cmd eq 'rename') {
	my ($renamed, $file) = @_;
	my $tmp0 = File::Spec->catfile($env->{wd}, $renamed);
	my $tmp1 = File::Spec->catfile($env->{wd}, $file);
	&rmt_cmd('system', $env, "mv -f $tmp0 $tmp1");
    } elsif ($cmd eq 'symlink') {
	my ($dir, $file, $link) = @_;
	my $tmp = File::Spec->catfile($dir, $link);
	&rmt_cmd('system', $env, "ln -s $file $tmp");
    } elsif ($cmd eq 'unlink') {
	my ($file) = @_;
	my $fullpath = File::Spec->catfile($env->{wd}, $file);
	&rmt_cmd('system', $env, "rm -f $fullpath");
    } elsif ($cmd eq 'get') {
	my ($file, $to) = @_;
	unless ($xcropt::options{shared}) {
	    my $fullpath = File::Spec->catfile($env->{wd}, $file);
	    $ssh->scp_get(\%ssh_opts, $fullpath, File::Spec->catfile($to, $file)) or die "get failed: $ssh->error";
	}
    } elsif ($cmd eq 'put') {
	my ($file, $to) = @_;
	unless ($xcropt::options{shared}) {
	    my $fullpath = File::Spec->catfile($env->{wd}, $to, $file);
	    $ssh->scp_put(\%ssh_opts, $file, $fullpath) or die "put failed: $ssh->error";
	}
    } else {
	foreach(%$cmd){print $_, "\n";}
	die "$cmd doesn't match";
    }
}

sub xcr_cmd {
    my $cmd =shift;
    my $env =shift;
    if ($env->{location} eq 'remote') {
	rmt_cmd($cmd, $env, @_);
    } elsif ($env->{location} eq 'local') {
	if ($cmd eq 'exist') {
	    my $flag = 0;
            my ($file) = @_;
	    if (-e $file) {
		$flag = 1;
	    }
	    return $flag;
	} elsif ($cmd eq 'qx') {
	    my ($command, $dir) = @_;
	    my @ret = qx/cd $dir; $command/;
	    return @ret;
	} elsif ($cmd eq 'system') {
	    my ($command, $dir) = @_;
	    my $flag = system("cd $dir; $command");
	    return $flag;
	} elsif ($cmd eq 'mkdir') {
	    my ($dir) = @_;
	    if (-d $dir) {
		mkdir $dir, 0755;
	    }
	} elsif ($cmd eq 'copy') {
	    my ($copied, $dir) = @_;
	    fcopy($copied, $dir);
	} elsif ($cmd eq 'rename') {
	    my ($renamed, $file) = @_;
	    if (-e $renamed) {
		rename $renamed, $file;
	    }
	} elsif ($cmd eq 'symlink') {
	    my ($dir, $file, $link) = @_;
	    symlink($file, File::Spec->catfile($dir, $link));
	} elsif ($cmd eq 'unlink') {
	    my ($file) = @_;
	    unlink $file;
	} else {
	    die ;
	}
    } else {
	die ;
    }
}

sub rmt_exist   { my $flag = rmt_cmd('exist',   @_);  return $flag; }
sub rmt_qx      { my @ret  = rmt_cmd('qx',      @_);  return @ret;  }
sub rmt_system  { my $flag = rmt_cmd('system',  @_);  return $flag; }
sub rmt_mkdir   {            rmt_cmd('mkdir',   @_);                }
sub rmt_copy    {            rmt_cmd('copy',    @_);                }
sub rmt_rename  {            rmt_cmd('rename',  @_);                }
sub rmt_symlink {            rmt_cmd('symlink', @_);                }
sub rmt_unlink  {            rmt_cmd('unlink',  @_);                }
sub rmt_get     {            rmt_cmd('get',     @_);                }
sub rmt_put     {            rmt_cmd('put',     @_);                }

sub xcr_exist   { my $flag = xcr_cmd('exist',   @_);  return $flag; }
sub xcr_qx      { my @ret  = xcr_cmd('qx',      @_);  return @ret;  }
sub xcr_system  { my $flag = xcr_cmd('system',  @_);  return $flag; }
sub xcr_mkdir   {            xcr_cmd('mkdir',   @_);                }
sub xcr_copy    {            xcr_cmd('copy',    @_);                }
sub xcr_rename  {            xcr_cmd('rename',  @_);                }
sub xcr_symlink {            xcr_cmd('symlink', @_);                }
sub xcr_unlink  {            xcr_cmd('unlink',  @_);                }

1;

