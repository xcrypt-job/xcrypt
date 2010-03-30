package config_common;

use base qw(Exporter);
our @EXPORT = qw(workdir_file_option rworkdir_file_option boolean_option);
use strict;

sub workdir_file_option {
    my $prefix = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $file = $self->{$mb_name} || $default;
        return $file?($prefix . $self->workdir_file($file)):();
    }
}

sub rworkdir_file_option {
    my $prefix = shift;
    my $default = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        my $file = $self->{$mb_name} || $default;
        return $file?($prefix . $self->rworkdir_file($file)):();
    }
}

sub boolean_option {
    my $opt_string = shift;
    sub {
        my $self = shift;
        my $mb_name = shift;
        return $self->{$mb_name} ? ($opt_string) : ();
    }
}

1;
