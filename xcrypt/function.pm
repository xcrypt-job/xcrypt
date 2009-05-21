package function;

sub silent { return ""; }
sub identity { return $_[0]; }
#sub backward_difference { abs($_[1] - $_[2]) < 0.0001; }
sub forward_difference { abs($_[0] - $_[1]) < 0.01; }
#sub central_difference { abs(($_[0] - $_[2]) / 2) < 0.0001; }
#sub second_central_difference { abs($_[0] - (2 * $_[1]) + $_[2]) < 0.0001; }
sub tautology { return 1; }
sub contradiction { return 0; }
sub hello { return "Hello, world.\n"; }

sub plus1 { return $_[0] + 1; }
sub plus10 { return $_[0] + 10; }

sub eq1 { return $_[0] == 1; }
sub eq2 { return $_[0] == 2; }
sub eq3 { return $_[0] == 3; }
sub eq4 { return $_[0] == 4; }
sub eq5 { return $_[0] == 5; }

sub map {
    my @result;
    foreach (@{$_[1]}) {
	push (@result , &{$_[0]}($_));
    }
    return @result;
}

1;
