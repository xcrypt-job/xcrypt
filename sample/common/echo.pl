#!/usr/bin/perl

my $value;
my @tmp;
open(IN, "< $ARGV[0]");
my $line = <IN>;
@tmp = split(' ', $line);
$value = 100 * $tmp[2];
open(OUT, "> output.dat");
print OUT $value;
close(OUT);
close(IN);
