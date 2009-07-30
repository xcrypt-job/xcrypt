#!/usr/bin/perl

sub body {
    if ($_[0] <= 1) {
	return 1;
    } else {
	return &body($_[0] - 1) + &body($_[0] - 2);
    }
}
my $a = &body($ARGV[0]);

print "fib($ARGV[0])=$a\n";
