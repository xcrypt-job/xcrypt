package config_common;

use base qw(Exporter);
our @EXPORT = qw(workdir_file_option boolean_option time_hhmmss_option  time_hhmm_option);
use strict;
use File::Spec;
use POSIX qw (floor);
use Scalar::Util qw(looks_like_number);

sub workdir_file_option {
    my $prefix = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $file = $self->{$mb_name} || $default;
	return $file?($prefix . $file):();
    }
}

sub boolean_option {
    my $opt_string = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $val = (defined $self->{$mb_name})?($self->{$mb_name}):$default;
        return $val ? ($opt_string) : ();
    }
}

sub sec_to_hms {
    my $num = shift;
    my $sec = $num % 60;
    my $min = ($num / 60) % 60; 
    my $hrs = floor ($num / 3600);
    return ($hrs,$min,$sec);
}

sub num_to_hhmmss {
    my $arg = shift;
    unless (looks_like_number ($arg)) {
	return $arg;
    } else {
	my ($hrs,$min,$sec) = sec_to_hms ($arg);
	return sprintf ("%d:%02d:%02d", $hrs, $min, $sec);
    }
}

sub num_to_hhmm {
    my $arg = shift;
    unless (looks_like_number ($arg)) {
	return $arg;
    } else {
	my ($hrs,$min,$sec) = sec_to_hms ($arg);
	return sprintf ("%d:%02d", $hrs, $min);
    }
}

sub time_hhmmss_option {
    my $prefix = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $val = (defined $self->{$mb_name})?($self->{$mb_name}):$default;
        return $val ? ($prefix . num_to_hhmmss ($val)) : ();
    }
}

sub time_hhmm_option {
    my $prefix = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $val = (defined $self->{$mb_name})?($self->{$mb_name}):$default;
        return $val ? ($prefix . num_to_hhmm ($val)) : ();
    }
}

1;
