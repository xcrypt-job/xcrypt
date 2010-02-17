package autodel;

sub del {
    my $cond = shift;
    my $after = shift;
    my @jobs = @_;
    foreach my $l (@jobs) {
	my $lid = $l->{'id'};
	if (&{$cond}($l)) {
	    if ($lid) {
		system("xcryptdel $lid");
		&{$after}($l);
	    }
	}
    }
}

1;

