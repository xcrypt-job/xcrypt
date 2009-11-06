#!/usr/bin/env perl

open(IN, "< template.dat");
foreach my $item (<IN>) {
    my $str = $item;
    if ($str =~ m/(param)/) {
	if ($str =~ m/(\d+)$/) {
	    my $num = $1;
	    open(OUT, "> out" );
	    print OUT ($num / 2);
	    close(OUT);
	}
    }
}
close(IN);
