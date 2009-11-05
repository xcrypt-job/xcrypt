#!/usr/bin/env perl

open(IN, "< template.dat");
foreach my $item (<IN>) {
    my $str = $item;
    if ($str =~ m/^(param)/) {
	if ($str =~ m/(\d+)/) {
	    my $num = $1;
	    print $num;
	    open(OUT, "> out" );
	    print OUT (2 * $num);
	    close(OUT);
	}
    }
}
close(IN);
