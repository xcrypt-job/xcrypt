package timekeeper;

use File::Spec;
use threads;
use threads::shared;

sub getjobids {
    open( JOBIDS, "< $_[0]" );
    my %reqid_jobids = split(' ', <JOBIDS>);
    my %count;
    my @vals = values(%reqid_jobids);
    @vals = grep(!$count{$_}++, @vals);
    my @jobids = sort @vals;
    close( JOBIDS );
    return @jobids;
}

sub invoke_watch {
    $watch = threads->new( sub {
while (1) {
    sleep 9;
    &alert();
}
			   });
}

sub alert {
    my $reqidfile = File::Spec->catfile ('inv_watch', '.request_ids');
    my @jobids = &getjobids($reqidfile);

    my $sum = 0;
    my %elapseds = ();
    foreach $i (@jobids) {
	my $time_done_now = time();
	my $inventoryfile = File::Spec->catfile ('inv_watch', "$i");
	my $time_running;
	open( INV, "$inventoryfile" );
	while (<INV>) {
	    if ($_ =~ /^time_running\:\s*([0-9]*)/) {
		$time_running = $1;
	    }
	    if ($_ =~ /^time_done\:\s*([0-9]*)/) {
		$time_done_now = $1;
	    }
	}
	close( INV );
	my $elapsed = $time_done_now - $time_running;
	$sum = $sum + $elapsed;
	$elapseds{"$i"} = $elapsed;
    }
    my $length =  @jobids;
    my $average = $sum / $length;
    foreach (@jobids) {
	if ( $elapseds{$_} - $average > 10 ) {
	    print "$_ takes much time.\n";
	}
    }
}

1;
