package builtin;

use base qw(Exporter);
our @EXPORT = qw(cmd_executable
get_from put_into
rmt_exist rmt_qx rmt_system rmt_mkdir rmt_copy rmt_rename rmt_symlink rmt_unlink
xcr_exist xcr_qx xcr_system xcr_mkdir xcr_copy xcr_rename xcr_symlink xcr_unlink
prepare submit sync prepare_submit submit_sync prepare_submit_sync
get_local_env get_all_envs add_host add_key add_prefix_of_key repeat
set_expander get_expander
set_separator get_separator check_separator nocheck_separator
filter
set_TEMPLATE
spawn _before_ _after_ _before_in_xcrypt_ _after_in_xcrypt_
add_package
add_cmd_before_exe add_cmd_after_exe
);

use strict;
use English;
use NEXT;
use Coro;
use Coro::Signal;
use Coro::AnyEvent;
use Cwd;
use Data::Dumper;
use File::Basename;
use Net::OpenSSH;
use Config::Simple;

# use jobsched;
#use xcropt;
use Cwd;
use common;
use jsconfig;

use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::Spec;

# Permitted job template member names.
my @allkeys = ('id', 'exe', 'initially', 'finally', 'env', 'transfer_variable', 'transfer_reference_level', 'not_transfer_info',
'before', 'before_to_job', 'before_return', 'before_bkup', 'before_in_job', 'before_in_xcrypt', 'before_in_xcrypt_return',
'after',  'after_to_job',  'after_return',  'after_bkup',  'after_in_job',  'after_in_xcrypt',  'after_in_xcrypt_return',
'cmd_before_exe', 'cmd_after_exe',
'header'
);
my @allprefixes = ('JS_');
my $nil = 'nil';

my %ssh_opts = (
    copy_attrs => 1,      # -p preserver file attributes
    recursive => 1,       # -r recursive copy
    bwlimit => 10000000,  # -l the max size of a copied file
    glob => 1,            # enable globs (e.g. '*' for all files)
    quiet => 1,           # Quiet. Does not show progress
    );

my %Host_Ssh_Hash;
our $env_d;
$env_d = { 'host'     => $xcropt::options{host},
           'wd'       => $xcropt::options{wd},
           'sched'    => $xcropt::options{sched},
           'xd'       => $xcropt::options{xd},
           'location' => 'local',
};
my @Env;
sub get_local_env { return $env_d; }
sub get_all_envs { return @Env; }
##
my $expander = '@';
my $separator = '_';
my $separator_check = 1;
sub set_expander { $expander = $_[0]; }
sub get_expander { return $expander; }
sub set_separator { $separator = $_[0]; }
sub get_separator { return $separator; }
sub check_separator { $separator_check = 1; }
sub nocheck_separator { $separator_check = 0; }
#
sub cmd_executable {
    my ($cmd, $env) = @_;
    my @cmd0 = split(/\s+/,$cmd);
    if ($env->{location} eq 'local') {
        qx/which $cmd0[0]/;
    } else {
        my $ssh = $Host_Ssh_Hash{$env->{host}};
        my @flags = &ssh_command($env, $ssh, 'system', "which $cmd0[0]");
        my $tmp = $flags[0];
        if ($tmp == 0) {
            return 0;
        } else {
            return 1;
        }
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
	unless (defined $to) { $to = '.'; }
        unless ($xcropt::options{shared}) {
            my $fullpath = File::Spec->catfile($env->{wd}, $file);
            &ssh_command($env, $ssh, 'get', $fullpath, File::Spec->catfile($to, $file));
        }
    } elsif ($cmd eq 'put') {
        my ($file, $to) = @_;
	unless (defined $to) { $to = '.'; }
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
    } else {
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

sub get_from    {            rmt_cmd('get',     @_);                }
sub put_into    {            rmt_cmd('put',     @_);                }

sub xcr_exist   { my $flag = xcr_cmd('exist',   @_);  return $flag; }
sub xcr_qx      { my @ret  = xcr_cmd('qx',      @_);  return @ret;  }
sub xcr_system  { my $flag = xcr_cmd('system',  @_);  return $flag; }
sub xcr_mkdir   {            xcr_cmd('mkdir',   @_);                }
sub xcr_copy    {            xcr_cmd('copy',    @_);                }
sub xcr_rename  {            xcr_cmd('rename',  @_);                }
sub xcr_symlink {            xcr_cmd('symlink', @_);                }
sub xcr_unlink  {            xcr_cmd('unlink',  @_);                }

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
    my $localhost = qx/hostname/;
    chomp $localhost;
    my $username = qx/whoami/;
    chomp $username;
    if ($env->{host} eq $username . '@' . $localhost) {
	$env->{location} = 'local';
    } else {
	$env->{location} = 'remote';
    }
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
        unless ($wd[0] eq '') {
            $env->{wd} = $wd[0];
        } else {
            die "Set the key wd at $env->{host}\n";
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
    if ( $xcropt::options{verbose} >= 3 ) {
	foreach my $key (keys(%$env)) {
	    print $key . ': ' . $env->{$key} . "\n";
	}
    }
    push(@Env, $env);
    return $env;
}

sub expand {
    my %job = @_;
    my $max_of_range = &get_max_index_of_range(%job);
    my @value;
    if (defined $job{'RANGES'}) {
        @value = &times(@{$job{'RANGES'}});
    } elsif ( $max_of_range != -1 ) { # for compatibility only
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
        @value = &times(@ranges);
    # } elsif (&MAX(\%job)) { # when parameters except RANGE* exist
    #     my @params = (0..(&MIN(\%job)-1));
    #     foreach (@params) {
    # 	    my $self = &do_initialized(\%job, $_);
    # 	    push(@objs, $self);
    #     }
    } else {
        @value = ([]);
    }
    return @value;
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

# for compatibility only
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
        $pat0 = '\Aarg[0-9]+'.$separator.'[0-9]+';
        $pat1 = '[0-9]+';
    } elsif ($arg eq 'second') {
        $pat0 = '\Aarg[0-9]+'.$separator.'[0-9]+';
        $pat1 = '[0-9]+'.$separator;
    }
    foreach my $key (keys(%job)) {
        if ($key =~ /$pat0/) {
            if ($key =~ /$pat1/) {
                if ($arg eq 'second') {
                    push(@ret, $POSTMATCH);
                } else {
                    push(@ret, $MATCH);
		}
	    }
        }
    }
    my $max = &max(@ret);
    return $max;
}

# for compatibility only
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

our $count = 0;
sub do_initialized {
    my %template = %{$_[0]};
    shift;
    my @value = @_;
    $template{'VALUE'} = \@value;
    my $tmp = 0;
    # foreach (@value) {
    # 	$template{"VALUE$tmp"} = $_;
    # 	$tmp++;
    # }
        if ($separator_check) {
            unless ( $separator =~ /\A[!#+,-.@\^_~a-zA-Z0-9]\Z/ ) {
                die "Can't support $separator as \$separator.\n";
            }
    }

    # generate job objects
    unless (defined $template{"id$expander"}) {
        $template{id} = join($separator, ($template{id}, @_));
    }
#    foreach my $k (@allkeys) {
    foreach my $tmp_k (keys(%template)) {
        my ($k , $after_k) = split(/$expander/, $tmp_k);
        my $members = "$k" . $expander;

        if ( exists($template{"$members"}) ) {
            local $user::self = \%template;
            local @user::VALUE = @value;
            unless ( ref($template{"$members"}) ) {
                warn "Can't dereference $members.  Instead evaluate $members";
                @_ = (\%template, @value);
                $template{"$k"} = eval($template{$members});
            } elsif ( ref($template{"$members"}) eq 'CODE' ) {
#foreach my $i (0..$#value) { my $tmp = "user::RANGE$i"; eval "\$$tmp = \$value[$i];"; };
                $template{"$k"} = &{$template{"$members"}}(\%template, @value);
            } elsif ( ref($template{"$members"}) eq 'ARRAY' ) {
                my @tmp = @{$template{"$members"}};
                $template{"$k"} = $tmp[$count];
            } elsif ( ref($template{"$members"}) eq 'SCALAR' ) {
                $template{"$k"} = ${$template{"$members"}};
            } else {
                die "Can't interpret $members\n";
            }
        }
    }
    my $self = user->new(\%template);

    # aliases
    # if (defined $self->{exe0}) {
    #     $self->{exe} = $self->{exe0};
    # }
    # my $max_of_arg = &get_max_index_of_arg(%template);
    # foreach my $i (0..$max_of_arg) {
    #     if (defined $self->{"arg0_$i"}) {
    #         $self->{"arg$i"} = $self->{"arg0_$i"};
    #     }
    # }

    &jobsched::entry_job_id ($self);
#    &jobsched::set_job_initialized($self); # -> core.pm
    return $self;
}

sub set_TEMPLATE {
    my $cfg_obj = new Config::Simple($xcropt::options{config});
    my %cfg = $cfg_obj->vars();
    foreach my $key (keys %cfg) {
	my @for_getting_real_key = split(/\./, $key);
	if ($for_getting_real_key[0] eq 'template') {
	    my $real_key = $for_getting_real_key[1];
	    $user::TEMPLATE{"$key"} = $cfg{"$key"};
	}
    }
}

sub unalias {
    my %template = @_;

    foreach my $key (keys %user::TEMPLATE) {
	my @for_getting_real_key = split(/\./, $key);
	if ($for_getting_real_key[0] eq 'template') {
	    unless (defined $template{$for_getting_real_key[1]}) {
		$template{$for_getting_real_key[1]} = $user::TEMPLATE{$key};
	    }
	}
    }

    # if ($template{exe}) {
    #     $template{exe0} = $template{exe};
    #     delete($template{exe});
    # }
    # if ($template{"exe$expander"}) {
    #     $template{"exe0$expander"} = $template{"exe$expander"};
    #     delete($template{"exe$expander"});
    # }
    # my $max_of_arg = &get_max_index_of_arg(%template);
    # foreach my $i (0..$max_of_arg) {
    #     if ($template{"arg$i"}) {
    #         $template{"arg0_$i"} = $template{"arg$i"};
    #         delete($template{"arg$i"});
    #     }
    # }
    # foreach my $i (0..$max_of_arg) {
    #     if ($template{"arg$i$expander"}) {
    #         $template{"arg0_$i$expander"} = $template{"arg$i$expander"};
    #         delete($template{"arg$i$expander"});
    #     }
    # }
    return %template;
}

sub disble_keys_without_by_add_key {
    my %job = @_;
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
	    # if ($key =~ /^JS_/) {
	    # 	my ($before_exp_char , $after_exp_char) = split(/@/, $key);
	    # 	push(@allkeys, $before_exp_char);
	    # }
        }
        $exist = 0;
    }
    return %job;
}

sub add_exes_args_colon { # w.r.t. exes and args for compatibility only
    my %job = @_;
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
    return %job;
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
    my $stat = jobsched::get_job_status($self);
    if ($sig) {
        jobsched::set_job_status_according_to_signal ($self);
        return 0;
    } elsif (jobsched::job_proceeded_last_time ($self, 'finished')) {
        print "$self->{id}: the after() methods invocation.\n";
        return 0;
    } elsif ( $stat eq 'done' ) {
        return 1;
    } else {
        return 0;
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

sub job_info {
    my $self = shift;
    my $job_info = '';
    #id
    $job_info .= "$self->{id}\n";
    #qsub_command
    &core::make_qsub_options($self);
    my $sched = $self->{env}->{sched};
    my %cfg = %{$jsconfig::jobsched_config{$sched}};
    my $qsub_command = $cfg{qsub_command};
    if ($xcropt::options{xqsub}) {
        $qsub_command = "xqsub --to $sched";
    }
    #$job_info .= "\tqsub = $qsub_command @{$self->{qsub_options}}\n";
    $job_info .= "\tqsub = $qsub_command @{$self->{qsub_options}} $self->{jobscript_file}\n";

    #exe_args
    my $max_of_exe = &get_max_index_of_exe(%$self);
    my $max_of_second = &get_max_index_of_second_arg_of_arg(%$self);
    foreach my $j (0..$max_of_exe) {
        if ($self->{"exe$j"}) {
            my @args = ();
            for ( my $i = 0; $i <= $max_of_second; $i++ ) {
                if ($self->{"arg$j".'_'."$i"}) {
                    push(@args, $self->{"arg$j".'_'."$i"});
                }
            }
            my $cmd = $self->{"exe$j"} . ' ' . join(' ', @args);
            $job_info .= "\texe = $cmd\n";
        }
    }
    foreach my $key (keys %{$self}) {
        if ($key =~ /JS_/) {
            $job_info .= "\t$key = $self->{$key}\n";
        }
    }

    print "$job_info";
}

##################################################
# Keys are refs to job objects spawned in the inner-most join{} scope.
our %Spawned=();

sub submit {
    my @array = @_;
    my $slp = 0;
    # my @coros = ();

    foreach my $self (@array) {
        # Take a snapshot of the Perl(Xcrypt) environment for *_in_job_scripts
        $self->make_dumped_environment();
        # Create a job thread.
        my $job_coro = Coro::async {
            my $self = $_[0];
            # Output message on entering/leaving the Coro thread.
            if ( $xcropt::options{verbose} >= 3 ) {
                Coro::on_enter {
                    print "enter ". $self->{id} .": nready=". Coro::nready ."\n";
                };
                Coro::on_leave {
                    print "leave ". $self->{id} .": nready=". Coro::nready ."\n";
                };
            }
            ## Manually handle a signal message once.
            jobsched::left_signal_message_check ($self);
            ## Invoke initially()
            unless (check_status_for_initially ($self)) {
                Coro::terminate();
            }
            $self->EVERY::initially(@{$self->{VALUE}});
            ## Invoke before_in_xcrypt()
	    if (defined $self->{before_in_xcrypt}) {
                my $before_in_xcrypt_return = $self->before_in_xcrypt(@{$self->{VALUE}});
		$self->{before_in_xcrypt_return} = $before_in_xcrypt_return;
		$self->return_write("before_in_xcrypt", $self->{workdir}, $before_in_xcrypt_return);
	    }
            ## Invoke before() (except user's before() if before_to_job is 1)
            if (check_status_for_before ($self)) {
                if ($self->{before_to_job} == 1 and (exists $self->{before})) {
                    # Eliminate user's before() temporarily.
                    $self->{before_bkup} = $self->{before};
                    delete $self->{before};
                }
                my $before_return = $self->EVERY::before(@{$self->{VALUE}});
                foreach my $key (keys %{$before_return}) {
                    if ($key eq 'user::before' and $self->{before} ne '') {
			$self->{before_return} = ${$before_return}{$key};
                        $self->return_write("before", $self->{workdir}, ${$before_return}{$key});
                    }
                }
                if (exists $self->{before_bkup}) {
                    # Restore user's before() from before_bkup
                    $self->{before} = $self->{before_bkup};
                    delete $self->{before_bkup};
                }
            }
            ## Print job information by employing job_info()
            if (defined $xcropt::options{jobinfo}) {
                &job_info($self);
            }
            ## Invoke start() (job submission)
            if (check_status_for_start ($self)) {
                $self->start();
            }
	    ## set_job_queued()
	    if (check_status_for_set_job_queued ($self)) {
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
	    # my $flag0 = 0;
            # my $flag1 = 0;
            # until ($flag0 && $flag1) {
            # Coro::AnyEvent::sleep 1;
            # $flag0 = &xcr_exist($self->{env},
            # File::Spec->catfile($self->{workdir},
            # $self->{JS_stdout})
            #     );
            # $flag1 = &xcr_exist($self->{env},
            # File::Spec->catfile($self->{workdir},
            # $self->{JS_stderr})
            #     );
            # }

	    ## NFS が書き込んでくれる*経験的*待ち時間
	    sleep 3;
            ## Invoke after()
            if (check_status_for_after ($self)) {
                if ($self->{after_to_job} == 1 and (exists $self->{after})) {
                    # Eliminate user's after() temporarily.
                    $self->{after_bkup} = $self->{after};
                    delete $self->{after};
                }
                my $after_return = $self->EVERY::LAST::after(@{$self->{VALUE}});
                foreach my $key (keys %{$after_return}) {
                    if ($key eq 'user::after' and $self->{after} ne '') {
			$self->{after_return} = ${$after_return}{$key};
                        $self->return_write("after", $self->{workdir}, ${$after_return}{$key});
                    }
                }
                if (exists $self->{after_bkup}) {
                    # Restore user's after() from after_bkup
                    $self->{after} = $self->{after_bkup};
                    delete $self->{after_bkup};
                }
            }
            ## Invoke after_in_xcrypt()
	    if (defined $self->{after_in_xcrypt}) {
                my $after_in_xcrypt_return = $self->after_in_xcrypt(@{$self->{VALUE}});
		$self->{after_in_xcrypt_return} = $after_in_xcrypt_return;
		$self->return_write("after_in_xcrypt", $self->{workdir}, $after_in_xcrypt_return);
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
    # If any jobs are not specified, all the jobs submitted in this lexical scope.
    if ($#jobs  < 0) { @jobs = map {jobsched::find_job_by_id($_)} (keys %Spawned); }
    foreach (@jobs) {
        if ( $xcropt::options{verbose} >= 2 ) {
            print "Waiting for $_->{id}($_->{thread}) finished.\n";
        }
        $_->{thread}->join;
        if ( $xcropt::options{verbose} >= 2 ) {
            print "$_->{id} finished.\n";
        }
        delete ($Spawned{$_->{id}});
    }
    foreach (@jobs) {
        &jobsched::exit_job_id($_);
    }
    return @_;
}

sub prepare{
    $count = 0;
    my %template = &unalias(@_);
    %template = &add_exes_args_colon(%template); # for compatibility
    %template = &disble_keys_without_by_add_key(%template);
    my @value = &expand(%template);
    my @jobs;
    foreach my $v (@value) {
        my $self = &do_initialized(\%template, @{$v});
        $count++;
        push(@jobs, $self);
    }
    
    ## job_info()
    if (defined $xcropt::options{jobinfo}) {
        foreach my $self (@jobs) {
             &job_info($self);
        }
    }
    
    return @jobs;
}

sub prepare_submit {
    $count = 0;
    my %template = &unalias(@_);
    %template = &add_exes_args_colon(%template); # for compatibility
    %template = &disble_keys_without_by_add_key(%template);
    my @value = &expand(%template);
    my @jobs;
    foreach my $v (@value) {
        my $self = &do_initialized(\%template, @{$v});
        $count++;
        &submit($self);
        push(@jobs, $self);
    }
    return @jobs;
}

sub submit_sync {
    my @objs = &submit(@_);
    return &sync(@objs);
}

sub prepare_submit_sync {
    my @objs = &prepare_submit(@_);
    return &sync(@objs);
}

sub filter {
    my $fun = shift;
    my @ret;
    foreach (@_) {
        if (&$fun($_)) {
            push(@ret, $_);
        }
    }
    return @ret;
}

sub add_package {
    my $self = shift;
    foreach my $pack (@_) {
	push(@{$self->{'header'}}, $pack);
    }
}

sub add_cmd_before_exe{
    my $self = shift;
    foreach my $cmd (@_) {
	push(@{$self->{'cmd_before_exe'}}, $cmd);
    }
}
sub add_cmd_after_exe{
    my $self = shift;
    foreach my $cmd (@_) {
	push(@{$self->{'cmd_after_exe'}}, $cmd);
    }
}

## Constructs for executing perl code as a job.
my $n_spawned_job=0;
sub generate_new_job_id {
    my $prefix = 'spawned_job_';
    local $jobsched::Warn_job_not_found_by_id=0;
    while (1) {
        my $candidate = $prefix.sprintf("%03d", $n_spawned_job++);
        unless (jobsched::find_job_by_id($candidate)
                || jobsched::get_last_job_state ($candidate)) {
            return $candidate;
        }
    }
}
## spawn {} [spawn_before {}] [spawn_after {}] [spawn_before_in_xcrypt {}] [spawn_after_in_xcrypt {}]
sub spawn(&@) {
    my $code = shift;
    my %template = ('exe' => $code, @_);
    unless (defined $template{id}) {
        $template{id} = generate_new_job_id();
    }
    my @jobs = prepare_submit (%template);
    foreach my $job (@jobs) {
        $Spawned{$job->{id}}=1;
    }
    return @jobs;
}
sub _before_(&@) {
    my $code = shift;
    return ('before', $code, @_);
}
sub _after_(&@) {
    my $code = shift;
    return ('after', $code, @_);
}
sub _before_in_xcrypt_(&@) {
    my $code = shift;
    return ('before_in_xcrypt', $code, @_);
}
sub _after_in_xcrypt_(&@) {
    my $code = shift;
    return ('after_in_xcrypt', $code, @_);
}

sub join(&) {
    my $code = shift;
    my $joined_code = sub {
        local %Spawned=();
        $code->();
        sync;
    };
    $joined_code->();
}    

1;
