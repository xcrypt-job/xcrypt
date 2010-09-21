package builtin;

use base qw(Exporter);
our @EXPORT = qw(cmd_executable
get_from put_into
rmt_exist rmt_qx rmt_system rmt_mkdir rmt_copy rmt_rename rmt_symlink rmt_unlink
xcr_exist xcr_qx xcr_system xcr_mkdir xcr_copy xcr_rename xcr_symlink xcr_unlink
unalias_expand_make do_initialized do_prepared
prepare submit sync prepare_submit submit_sync prepare_submit_sync
get_local_env get_all_envs add_host add_key add_prefix_of_key repeat
set_expander set_separator check_separator nocheck_separator
);

#use strict;
use NEXT;
use Coro;
use Coro::Signal;
use Coro::AnyEvent;
use Cwd;
use Data::Dumper;
use File::Basename;
use Net::OpenSSH;

#use jobsched;
use xcropt;
use Cwd;
use common;

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Spec;

# id, exe$i and arg$i_$j are built-in.
my @allkeys = ('id', 'before', 'before_in_job', 'after_in_job', 'after', 'env');
my @allprefixes = ('JS_');
my $expander = '@';
my $separator = '_';
my $separator_check = 1;
my $nil = 'nil';

my %ssh_opts = (
    copy_attrs => 1,   # -pと同じ。オリジナルの情報を保持
    recursive => 1,    # -rと同じ。再帰的にコピー
    bwlimit => 40000,  # -lと同じ。転送量のリミットをKbit単位で指定
    glob => 1,         # ファイル名に「*」を使えるようにする。
    quiet => 1,        # 進捗を表示する
    );

my %Host_Ssh_Hash;
our $env_d;
$env_d = { 'host'     => $xcropt::options{localhost},
	   'wd'       => $xcropt::options{wd},
	   'sched'    => $xcropt::options{sched},
	   'xd'       => $xcropt::options{xd},
	   'p5l'      => $xcropt::options{p5l},
	   'location' => 'local' };
my @Env = ($env_d);
sub get_local_env { return $env_d; }
sub get_all_envs { return @Env; }
##
sub set_expander {
    $expander = $_[0];
}
sub set_separator {
    $separator = $_[0];
}
sub check_separator {
    $separator_check = 1;
}
sub nocheck_separator {
    $separator_check = 0;
}
#
sub cmd_executable {
    my ($cmd, $env) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if ($env->{location} eq 'remote') {
	my $ssh = $Host_Ssh_Hash{$env->{host}};
	my @flags = &ssh_command($env, $ssh, 'system', "which $cmd0[0]");
	my $tmp = $flags[0];
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

sub ssh_command {
    my ($env, $ssh, $command, $str0, $str1)= @_;

    $ssh->system("true");
    while ($ssh->error) {
	sleep(60);
	my ($user, $host) = split(/@/, $env->{host});
	$ssh = Net::OpenSSH->new($host, (user => $user));
	$ssh->error and warn $ssh->error;
	$Host_Ssh_Hash{$env->{host}} = $ssh;
    }

    my @flags;
    if ($command eq 'capture') {
	@flags = $ssh->capture("$str0"); # or warn $ssh->error;
    } elsif ($command eq 'system') {
	my $flag = $ssh->system("$str0") or warn $ssh->error;
	@flags = ($flag);
    } elsif ($command eq 'get') {
	$ssh->scp_get(\%ssh_opts, $str0, $str1) or warn $ssh->error;
    } elsif ($command eq 'put') {
	$ssh->scp_put(\%ssh_opts, $str0, $str1) or warn $ssh->error;
    }
    return @flags;
}

sub rmt_cmd {
    my $cmd = shift;
    my $env = shift;
    my $ssh = $Host_Ssh_Hash{$env->{host}};
    if ($cmd eq 'qx') {
	my ($command, $dir) = @_;
	my $tmp = 'cd ' . File::Spec->catfile($env->{wd}, $dir) . "; $command";
	my @flags = &ssh_command($env, $ssh,'capture', "$tmp");
	return @flags;
    } elsif ($cmd eq 'system') {
	my ($command, $dir) = @_;
	my $tmp = 'cd ' . File::Spec->catfile($env->{wd}, $dir) . "; $command";
	my @flags = &ssh_command($env, $ssh, 'system', "$tmp");
	return $flags[0];
    } elsif ($cmd eq 'exist') {
	my ($file) = @_;
	my $fullpath = File::Spec->catfile($env->{wd}, $file);
	my @flags = &ssh_command($env, $ssh, 'capture', "test -e $fullpath && echo 1");
	chomp($flags[0]);
	return $flags[0];
    } elsif ($cmd eq 'mkdir') {
	my ($dir) = @_;
	my $fullpath = File::Spec->catfile($env->{wd}, $dir);
	&rmt_cmd('system', $env, "test -e $fullpath || mkdir $fullpath");
    } elsif ($cmd eq 'copy') {
	my ($copied, $dir) = @_;
	my $fp_copied = File::Spec->catfile($env->{wd}, $copied);
	my $fp_dir = File::Spec->catfile($env->{wd}, $dir);
	&rmt_cmd('system', $env, "test -d $fp_copied && cp -r $fp_copied $fp_dir");
	&rmt_cmd('system', $env, "test -d $fp_copied || cp -f $fp_copied $fp_dir");
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
	    &ssh_command($env, $ssh, 'get', $fullpath, File::Spec->catfile($to, $file));
	}
    } elsif ($cmd eq 'put') {
	my ($file, $to) = @_;
	unless ($xcropt::options{shared}) {
	    my $fullpath = File::Spec->catfile($env->{wd}, $to, $file);
	    &ssh_command($env, $ssh, 'put', $file, $fullpath);
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
	    mkdir $dir, 0755;
	} elsif ($cmd eq 'copy') {
	    my ($copied, $dir) = @_;
	    rcopy($copied, $dir);
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

sub get_from     {            rmt_cmd('get',     @_);                }
sub put_into     {            rmt_cmd('put',     @_);                }

sub xcr_exist   { my $flag = xcr_cmd('exist',   @_);  return $flag; }
sub xcr_qx      { my @ret  = xcr_cmd('qx',      @_);  return @ret;  }
sub xcr_system  { my $flag = xcr_cmd('system',  @_);  return $flag; }
sub xcr_mkdir   {            xcr_cmd('mkdir',   @_);                }
sub xcr_copy    {            xcr_cmd('copy',    @_);                }
sub xcr_rename  {            xcr_cmd('rename',  @_);                }
sub xcr_symlink {            xcr_cmd('symlink', @_);                }
sub xcr_unlink  {            xcr_cmd('unlink',  @_);                }

=comment
sub check_and_alert_elapsed {
    my @job_ids = &jobsched::get_all_job_ids();

    my $sum = 0;
    my %elapseds = ();
    my $length = 0;
    foreach my $i (@job_ids) {
        $elapseds{"$i"} = undef;
        my $inventoryfile = File::Spec->catfile ($inventory_path, "$i");
        $time_done_now = time();
        &update_running_and_done_now($inventoryfile);
        if (defined $time_running) {
            my $elapsed = $time_done_now - $time_running;
            $sum = $sum + $elapsed;
            $elapseds{"$i"} = $elapsed;
            $length = $length + 1;
        }
        $time_running = undef;
    }
    my $average = 0;
    unless ($length == 0) {
        $average = $sum / $length;
    }
    foreach (@job_ids) {
        if (defined $elapseds{$_}) {
            if ( $elapseds{$_} - $average > 300 ) {
                print "Warning: $_ takes more time than the other jobs.\n";
            }
        }
    }
}

=cut

my $default_period = 10;
my @periodic_threads = ();
sub repeat {
    my $new_coro = undef;
    my $sub_or_str = $_[0];
    my $slp = $_[1];
    unless ($slp) { $slp = $default_period; }
    if ( ref($_[0]) eq 'CODE' ) {
        $new_coro = Coro::async_pool {
            while (1) {
                Coro::AnyEvent::sleep $slp;
                &{$sub_or_str};
            }
        };
    } elsif (!(ref $_[0])) {
        $new_coro = Coro::async_pool {
            while (1) {
                Coro::AnyEvent::sleep $slp;
                eval $sub_or_str;
            }
        };
    } else {
        warn '&repeat accepts code or eval-string.';
    }
    if ($new_coro) {
        push (@periodic_threads, $new_coro);
    }
    if ( $xcropt::options{verbose} >= 2 ) {
        print "periodic = (";
        foreach (@periodic_threads) {
            print "$_ "
        }
        print ")\n";
    }
    return $new_coro;
}

sub add_host {
    my ($env) = @_;
    unless (defined $env->{location}) {	$env->{location} = 'remote'; }
    if ($env->{location} eq 'remote') {
	unless (exists $Host_Ssh_Hash{$env->{host}}) {
	    my ($user, $host) = split(/@/, $env->{host});
	    my $ssh = Net::OpenSSH->new($host, (user => $user));
	    $ssh->error and die "Unable to establish SSH connection: " . $ssh->error;
	    $Host_Ssh_Hash{$env->{host}} = $ssh;
	}
    }
    unless (defined $env->{wd}) {
	my @wd = &xcr_qx($env, 'echo $HOME');
	chomp($wd[0]);
	print $wd[0], "\n";
	unless ($wd[0] eq '') {
	    $env->{wd} = $wd[0];
	} else {
	    die "Set the key wd at $env->{host}\n";
	}
    }
    if ($env->{location} eq 'remote') {
	unless ($xcropt::options{shared}) {
	    &rmt_mkdir($env, $xcropt::options{inventory_path});
	}
    }
    unless (defined $env->{p5l}) {
	my @p5l = &xcr_qx($env, 'echo $PERL5LIB');
	chomp($p5l[0]);
	unless ($p5l[0] eq '') {
	    $env->{p5l} = $p5l[0];
	} else {
	    die "Set the environment varialble \$PERL5LIB at $env->{host}\n";
	}
    }
    unless (defined $env->{sched}) {
	my @sched = &xcr_qx($env, 'echo $XCRJOBSCHED');
	chomp($sched[0]);
	unless ($sched[0] eq '') {
	    $env->{sched} = $sched[0];
	} else {
	    die "Set the environment varialble \$XCRJOBSCHED at $env->{host}\n";
	}
    }
    unless (defined $env->{xd}) {
	    my @xd = &xcr_qx($env, 'echo $XCRYPT');
	    chomp($xd[0]);
	    unless ($xd[0] eq '') {
		$env->{xd} = $xd[0];
	    } else {
		die "Set the environment varialble \$XCRYPT at $env->{host}\n";
	    }
    }
    push(@Env, $env);
    return $env;
}

sub expand {
    my %job = @_;
    my $max_of_range = &get_max_index_of_range(%job);
    my @range;
    if (defined $job{'RANGES'}) {
	@range = &times(@{$job{'RANGES'}});
    } elsif ( $max_of_range != -1 ) {
        my @ranges = ();
        for ( my $i = 0; $i <= $max_of_range; $i++ ) {
            if ( exists($job{"RANGE$i"}) ) {
                if ( ref($job{"RANGE$i"}) eq 'ARRAY' ) {
                    push(@ranges, $job{"RANGE$i"});
                } else {
                    warn "The value of RANGE$i must be an ARRAY reference";
                }
            } else {
		my @temp = ($nil);
		$job{"RANGE$i"} = \@temp;
		push(@ranges, $job{"RANGE$i"});
	    }
        }
        @range = &times(@ranges);
=comment
    } elsif (&MAX(\%job)) { # when parameters except RANGE* exist
        my @params = (0..(&MIN(\%job)-1));
        foreach (@params) {
            my $self = &do_initialized(\%job, $_);
            push(@objs, $self);
        }
=cut
    } else {
        @range = ([]);
    }
    return @range;
}

sub add_key           { foreach my $i (@_) { push(@allkeys,     $i); } }
sub add_prefix_of_key { foreach my $i (@_) { push(@allprefixes, $i); } }

sub max {
    my @array = @_;
    my $max = -1;
    until (@array == ()) {
	my $tmp = shift(@array);
	if ($tmp > $max) {
	    $max = $tmp;
	}
    }
    return $max;
}
sub get_max_index {
    my $arg = shift;
    my %job = @_;
    my @ret;
    my $pat0;
    my $pat1;
    my $pat2;
    if ($arg eq 'range') {
	$pat0 = '\ARANGE[0-9]+\Z';
	$pat1 = '[0-9]+\Z';
    } elsif ($arg eq 'exe') {
	$pat0 = '\Aexe[0-9]+';
	$pat1 = '[0-9]+';
    } elsif ($arg eq 'arg') {
	$pat0 = '\Aarg[0-9]+';
	$pat1 = '[0-9]+';
    } elsif ($arg eq 'first') {
	$pat0 = '\Aarg[0-9]+_[0-9]+';
	$pat1 = '[0-9]+';
    } elsif ($arg eq 'second') {
	$pat0 = '\Aarg[0-9]+_[0-9]+';
	$pat1 = '[0-9]+_';
    }
    foreach my $key (keys(%job)) {
	if ($key =~ /$pat0/) {
	    if ($key =~ /$pat1/) {
		if ($arg eq 'second') {
		    push(@ret, $'); #'
		} else {
		    push(@ret, $&);
		}
	    }
	}
    }
    my $max = &max(@ret);
    return $max;
}
sub get_max_index_of_range             { return &get_max_index('range',  @_); }
sub get_max_index_of_exe               { return &get_max_index('exe',    @_); }
sub get_max_index_of_arg               { return &get_max_index('arg',    @_); }
sub get_max_index_of_first_arg_of_arg  { return &get_max_index('first',  @_); }
sub get_max_index_of_second_arg_of_arg { return &get_max_index('second', @_); }

sub times_loop {
    if (@_ == ()) { return (); }
    my @arg = @_;
    my @ret;
    until (@arg == ()) {
	my $head = shift(@arg);
	if (@ret == ()) {
	    foreach my $k (@$head) {
		push(@ret, [$k]);
	    }
	} else {
	    my @tmp;
	    foreach my $i (@ret) {
		foreach my $j (@$head) {
		    my @foo = @$i;
		    push(@foo, $j);
		    push(@tmp, \@foo);
		}
	    }
	    @ret = @tmp;
	}
    }
    return @ret;
}

sub times {
    if (@_ == ()) { return (); }
    my $head = shift;
    my @tail = &times(@_);
    my @result;
    foreach my $i (@{$head}) {
        if (@tail == ()) {
            push(@result, [$i]);
        } else {
            foreach my $j (@tail) {
                push(@result, [$i, @{$j}]);
            }
        }
    }
    return @result;
}

=comment
sub MAX {
    my %job = @_;
    my $num = 0;

    foreach (@allkeys) {
        my $members = "$_" . $expander;
        if ( exists($_[0]{"$members"}) ) {
            if (ref($_[0]{"$members"}) eq 'ARRAY') {
                my $tmp = @{$_[0]{"$members"}};
                $num = $tmp + $num;
            }
        }
    }
    return $num;
}

sub MIN {
    my %job = @_;
    my $num = 0;

    foreach (@allkeys) {
        my $members = "$_" . $expander;
        if ( exists($_[0]{"$members"}) ) {
            if ( ref($_[0]{"$members"} ) eq 'ARRAY') {
                my $tmp = @{$_[0]{"$members"}};
                if ($tmp <= $num) { $num = $tmp; }
                elsif ($num == 0) { $num = $tmp; }
                else {}
            }
        }
    }
    return $num;
}
=cut

my $count = 0;
sub do_initialized {
    my %job = %{$_[0]};
    shift;
    my @range = @_;
    $job{'VALUE'} = \@range;
    my $tmp = 0;
=comment
    foreach (@range) {
	$job{"VALUE$tmp"} = $_;
	$tmp++;
    }
=cut
    if ($separator_check) {
        unless ( $separator =~ /\A[!#+,-.@\^_~a-zA-Z0-9]\Z/ ) {
            die "Can't support $separator as \$separator.\n";
        }
    }

    # generate job objects
    unless (defined $job{"id$expander"}) {
	$job{id} = join($separator, ($job{id}, @_));
    }
#    foreach my $k (@allkeys) {
    foreach my $tmp_k (keys(%job)) {
	my ($k , $after_k) = split(/$expander/, $tmp_k);
        my $members = "$k" . $expander;

        if ( exists($job{"$members"}) ) {
	    local $user::self = \%job;
	    local @user::VALUE = @range;
            unless ( ref($job{"$members"}) ) {
		warn "Can't dereference $members.  Instead evaluate $members";
		@_ = (\%job, @range);
		$job{"$k"} = eval($job{$members});
            } elsif ( ref($job{"$members"}) eq 'CODE' ) {
#foreach my $i (0..$#range) { my $tmp = "user::RANGE$i"; eval "\$$tmp = \$range[$i];"; };
                $job{"$k"} = &{$job{"$members"}}(\%job, @range);
            } elsif ( ref($job{"$members"}) eq 'ARRAY' ) {
                my @tmp = @{$job{"$members"}};
                $job{"$k"} = $tmp[$count];
            } elsif ( ref($job{"$members"}) eq 'SCALAR' ) {
		$job{"$k"} = ${$job{"$members"}};
            } else {
                die "Can't interpret $members\n";
            }
        }


    }
    my $self = user->new(\%job);

    # aliases
    if (defined $self->{exe0}) {
	$self->{exe} = $self->{exe0};
    }
    my $max_of_arg = &get_max_index_of_arg(%job);
    foreach my $i (0..$max_of_arg) {
	if (defined $self->{"arg0_$i"}) {
	    $self->{"arg$i"} = $self->{"arg0_$i"};
	}
    }

    &jobsched::entry_job_id ($self);
    &jobsched::set_job_initialized($self);
    # &jobsched::load_inventory ($self->{id});
    return $self;
}

sub unalias_expand_make {
    my %job = @_;

    # aliases
    if ($job{exe}) {
	$job{exe0} = $job{exe};
	delete($job{exe});
    }
    if ($job{"exe$expander"}) {
	$job{"exe0$expander"} = $job{"exe$expander"};
	delete($job{"exe$expander"});
    }
    my $max_of_arg = &get_max_index_of_arg(%job);
    foreach my $i (0..$max_of_arg) {
	if ($job{"arg$i"}) {
	    $job{"arg0_$i"} = $job{"arg$i"};
	    delete($job{"arg$i"});
	}
    }
    foreach my $i (0..$max_of_arg) {
	if ($job{"arg$i$expander"}) {
	    $job{"arg0_$i$expander"} = $job{"arg$i$expander"};
	    delete($job{"arg$i$expander"});
	}
    }

    # add_key for built-in keys "exe*", "arg*" and ":*"
    my $max_of_exe    = &get_max_index_of_exe(%job);
    my $max_of_first  = &get_max_index_of_first_arg_of_arg(%job);
    my $max_of_second = &get_max_index_of_second_arg_of_arg(%job);
    for ( my $i = 0; $i <= $max_of_exe; $i++ )   { push(@allkeys, "exe$i"); }
    for ( my $i = 0; $i <= $max_of_first; $i++ ) {
	push(@allkeys, "arg$i");
	for ( my $j = 0; $j <= $max_of_second; $j++ ) {
            push(@allkeys, "arg$i".'_'."$j");
	}
    }
    foreach my $key (keys(%job)) {
        if ($key =~ /\A:/) {
            if ($key =~ /"$expander"\Z/) {
                $/ = $expander;
                chomp $key;
            }
	    push(@allkeys, $key);
        }
    }

    # disble keys without by add_key
    foreach my $key (keys(%job)) {
        my $exist = 0;
        foreach my $ukey (@allkeys) {
            if (($key eq $ukey) || ($key eq ($ukey . "$expander"))) {
                $exist = 1;
            }
        }
        foreach my $ukey (@allprefixes) {
            if ($key =~ $ukey) {
                $exist = 1;
            }
        }
        if ($exist == 0) {
            unless (($key =~ /\ARANGE[0-9]+\Z/)
#		    || ($key =~ /\ARANGE[0-9]+:[a-zA-Z_0-9]+\Z/)
                    || ($key =~ /\ARANGES\Z/)
                    || ($key =~ /\AVALUE\Z/))
            {
		print $key, "\n";
                warn "$key doesn't work.  Use :$key or &add_key(\'$key\').\n";
                delete $job{"$key"};
            }
=comment
            if ($key =~ /^JS_/) {
		my ($before_exp_char , $after_exp_char) = split(/@/, $key);
		push(@allkeys, $before_exp_char);
	    }
=cut
        }
        $exist = 0;
    }

    # expand
    my @range = &expand(%job);
    my @objs;
    my $self;
    foreach (@range) {
	$self = &do_initialized(\%job, @{$_});
	$count++;
	push(@objs, $self);
    }
    return @objs;
}

sub do_prepared {
    my @jobs = @_;
    foreach my $self (@jobs) {
        &jobsched::set_job_prepared($self);
    }
}

sub prepare{
    my @objs = &unalias_expand_make(@_);
    $count = 0;
    &do_prepared(@objs);
    return @objs;
}

sub check_status_for_initially {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    unless ($sig) {
        if (jobsched::job_proceeded_last_time ($self, 'finished')) {
            local $jobsched::Warn_illegal_transition = undef;
            &jobsched::set_job_finished($self);
            return 0;
        } else {
            return 1;
        }
    } elsif ( $sig eq 'sig_abort'
              && jobsched::job_proceeded_last_time ($self, 'finished')) {
        jobsched::unset_signal($self);
        local $jobsched::Warn_illegal_transition = undef;
        &jobsched::set_job_finished($self);
        return 0;
    } elsif ( $sig eq 'sig_abort' || $sig eq 'sig_cancel' ) {
        jobsched::delete_record_last_time($self);
        jobsched::unset_signal($self);
        return 1;
    } elsif ($sig eq 'sig_invalidate') {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    }
    warn "Unexpected program path in check_status_for_initially($self->{id}).";
    return 1;
}

sub check_status_for_before {    
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif ( jobsched::job_proceeded_last_time ($self, 'submitted') ) {
        print "$self->{id}: skip the before() method invocation\n";
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_start {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif ( jobsched::job_proceeded_last_time ($self, 'queued')
              && jobsched::request_id_last_time ($self) ) {
        print "$self->{id}: skip the start() method invocation\n";
        &jobsched::set_job_submitted($self);
        $self->{request_id} = jobsched::request_id_last_time ($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_set_job_queued {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_set_job_running {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::job_proceeded_last_time ($self, 'running')) {
        &jobsched::set_job_running($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_wait_job_done {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::job_proceeded_last_time ($self, 'done')) {
        print "$self->{id}: skip the wait_job_done()\n";
        &jobsched::set_job_done($self);
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_after {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::job_proceeded_last_time ($self, 'finished')) {
        print "$self->{id}: the after() methods invocation.\n";
        return 0;
    } else {
        return 1;
    }
}

sub check_status_for_set_job_finished {
    my $self = shift;
    my $sig = jobsched::get_signal_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::get_job_status ($self) eq 'aborted') {
        return 0;
    } else {
        return 1;
    }
}

sub submit {
    my @array = @_;
    my $slp = 0;
    # my @coros = ();

    foreach my $self (@array) {
        # Create a job thread.
        my $job_coro = Coro::async {
            my $self = $_[0];
            # Output message on entering/leaving the Coro thread.
            if ( $xcropt::options{verbose} >= 2 ) {
                Coro::on_enter {
                    print "enter ". $self->{id} .": nready=". Coro::nready ."\n";
                };
                Coro::on_leave {
                    print "leave ". $self->{id} .": nready=". Coro::nready ."\n";
                };
              }
            ## Resume signal
            jobsched::resume_signal_last_time ($self);
            ## initially()
            unless (check_status_for_initially ($self)) {
                Coro::terminate();
            }
            $self->EVERY::initially(@{$self->{VALUE}});
            ## before()
            if (check_status_for_before ($self)) {
                $self->EVERY::before(@{$self->{VALUE}});
            }
            ## start()
            if (check_status_for_start ($self)) {
                $self->{request_id} = $self->start();
            }
            ## set_job_queued()
            if (check_status_for_set_job_queued ($self)) {
                &jobsched::write_log (":reqID $self->{id} $self->{request_id}\n");
                &jobsched::set_job_queued($self);
            }
            ## If the job was 'running' in the last execution, set it's status to 'running'.
            check_status_for_set_job_running ($self);
            ## Waiting for the job "done"
            if (check_status_for_wait_job_done ($self)) {
                &jobsched::wait_job_done ($self);
            }

	    ## ジョブスクリプトの最終行の処理を終えたからといって
	    ## after()をしてよいとは限らないが……
	    my $flag0 = 0;
	    my $flag1 = 0;
	    until ($flag0 && $flag1) {
		Coro::AnyEvent::sleep 1;
		    $flag0 = &xcr_exist($self->{env},
					File::Spec->catfile($self->{workdir},
							    $self->{JS_stdout})
			);
		    $flag1 = &xcr_exist($self->{env},
					File::Spec->catfile($self->{workdir},
							    $self->{JS_stderr})
			);
	    }

	    ## NFS が書き込んでくれる*経験的*待ち時間
	    sleep 3;

            ## after()
            if (check_status_for_after ($self)) {
                $self->EVERY::LAST::after(@{$self->{VALUE}});
            }
            $self->EVERY::LAST::finally(@{$self->{VALUE}});
            if (check_status_for_set_job_finished ($self)) {
                &jobsched::set_job_finished($self);
            }
	} $self;
        # push (@coros, $job_coro);
        $self->{thread} = $job_coro;
	Coro::AnyEvent::sleep $slp;
    }
    return @array;
}

sub sync {
    my @jobs = @_;
    foreach (@jobs) {
        if ( $xcropt::options{verbose} >= 1 ) {
            print "Waiting for $_->{id}($_->{thread}) finished.\n";
        }
        $_->{thread}->join;
        if ( $xcropt::options{verbose} >= 1 ) {
            print "$_->{id} finished.\n";
        }
    }
    foreach (@jobs) {
	&jobsched::exit_job_id($_);
    }
    return @_;
=comment
    my %ret;
    foreach (@jobs) {
	$ret{$_->{id}} = $_;
    }
    return %ret;
=cut
}

sub prepare_submit {
    my @objs = &unalias_expand_make(@_);
    foreach (@objs) {
        &do_prepared ($_);
	&submit($_);
    }
    return @objs;
}

sub submit_sync {
    my @objs = &submit(@_);
    return &sync(@objs);
}

sub prepare_submit_sync {
    my @objs = &prepare_submit(@_);
    return &sync(@objs);
}

1;
