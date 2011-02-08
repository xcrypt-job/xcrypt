package dry;

use strict;
use NEXT;
use builtin;
use core;

&add_key('dry');
&add_prefix_of_key('dry_exe');

our %options = (
    'dry'  => '0',
    'dry_qsub' => 'host',
);

sub initialize {
    my %add_options = @_;
    foreach my $key (keys %add_options) {
        &check_dry_value($key, $add_options{$key});
        $options{$key} = $add_options{$key};
    }
}

sub check_dry_value {
    my ($key, $value) = @_;
    
    if ($key eq 'dry' and $value !~ /[0-3]/) {
        die "error $key";
    } elsif ($key eq 'dry_qsub' and ($value ne 'host' and $value ne 'local')) {
        die "error $key";
    }
}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    return bless $self, $class;
}

sub start {
    my $self = shift;
    if ($self->{dry} >= 1) {
        foreach my $key (keys(%$self)) {
            if ($key =~ /\Aexe([0-9]+)\Z/) {
                my $bkup = 'Bkup_exe'.$1;
                $self->{$bkup} = $self->{$key};
                $self->{$key} = "\#\# dry_run \#\#\n";
                if (defined $self->{"dry_exe$1"} and ($self->{dry} == 1 or $self->{dry} == 2)) {
                    no strict 'refs';
                    if (ref($self->{"dry_exe$1"}) eq 'CODE') {
                        $self->{$key} .= "perl $self->{id}_dry_exe${1}.pl $self->{$bkup}";
                        $self->make_in_job_script($self, "dry_exe{$1}_script", "dry_exe$1");
                        $self->update_script_file ("$self->{id}_dry_exe${1}.pl", @{$self->{"dry_exe{$1}_script"}});
                    } elsif (*{$self->{"dry_exe$1"}}{SCALAR}) {
                        $self->{$key} .= $self->{"dry_exe$1"} . "\n";
                        $self->{$key} .= "\#".$self->{$bkup};
                    } else {
                        die "error dry_exe";
                    }
                } else {
                    $self->{$key} .= "\#".$self->{$bkup};
                }
            }
        }
    }
    $self->NEXT::start();
}

sub initially {
    my $self = shift;
    
    if (exists $self->{dry}) {
        &check_dry_value('dry', $self->{dry});
    } else {
        $self->{dry} = $options{dry};
    }
    if (exists $self->{dry_qsub}) {
        &check_dry_value('dry_qsub', $self->{dry_qsub});
    } else {
        $self->{dry_qsub} = $options{dry_qsub};
    }
    
    if (exists $self->{dry_exe}) {
        $self->{dry_exe0} = $self->{dry_exe};
    }
    
    foreach my $dry_exe (grep {$_ =~ /\Adry_exe[0-9]+\Z/} keys(%options)) {
        unless (exists $self->{$dry_exe}) {
            $self->{$dry_exe} = $options{$dry_exe};
        }
    }
    
    if ($self->{dry_qsub} eq 'local') {
        $ENV{XCRJOBSCHED} = 'sh';
        $xcropt::options{sched} = $ENV{XCRJOBSCHED};
        ${$builtin::env_d}{sched} = $ENV{XCRJOBSCHED};
    }
    
    if ($self->{dry} >= 2) {
        &redefine_sub('before_in_job', 'after_in_job');
        &delete_sub($self, 'before_in_job', 'after_in_job');
    }
    if ($self->{dry} == 3) {
        &redefine_sub('before_in_xcrypt', 'after_in_xcrypt', 'before', 'after');
        &delete_sub($self, 'before', 'after', 'before_in_xcrypt', 'after_in_xcrypt');
    }
}

sub redefine_sub {
    my @redefine_subs = @_;
    
    foreach my $key ('user', @user::ISA) {
        foreach my $redefine_sub (@redefine_subs) {
            my $sub_redefine = "*" . "$key" . "::$redefine_sub = sub {}";
            no warnings 'redefine';
            eval $sub_redefine;
        }
    } 
}

sub delete_sub {
    my $self = shift;
    my @delete_subs = @_;
    
    foreach my $delete_sub (@delete_subs) {
        if (defined ($self->{$delete_sub})) {
            delete $self->{$delete_sub};
        }
    }
}

sub before_in_xcrypt {}
sub after_in_xcrypt {}

1;
