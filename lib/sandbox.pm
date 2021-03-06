package sandbox;

use strict;
use builtin;
use common;
use File::Basename;
use core;

#my $max_of_added_key = 63;
#foreach (0..$max_of_added_key) {
&add_prefix_of_key("linkedfile", "copiedfile");
#}

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);

    $self->{workdir} = $self->{id};
    # If the working directory already exists, delete it
    # my $ex = &xcr_exist($self->{env}, $self->{id});
    # if ($ex) {
    # 	print "Delete directory $self->{id}\n";
    # 	&xcr_rmtree($self->{id}, $self->{env});
    # }

    mkdir $self->{workdir}, 0755;
    &xcr_mkdir($self->{env}, $self->{workdir});

#    for ( my $i = 0; $i <= $max_of_added_key; $i++ ) {
    foreach my $k (keys(%{$self})) {
	if ($k =~ /\Acopiedfile[0-9]+/) {
#	if ($self->{"copiedfile$i"}) {
#	    my $copied = $self->{"copiedfile$i"};
	    my $copied = $self->{"$k"};
	    &xcr_copy($self->{env}, $copied, File::Spec->catfile($self->{workdir}, File::Spec->catfile(basename($copied))));
	}

	if ($k =~ /\Alinkedfile[0-9]+/) {
#	if ($self->{"linkedfile$i"}) {
#	    my $file = $self->{"linkedfile$i"};
	    my $file = $self->{"$k"};
	    &xcr_symlink($self->{env}, $self->{workdir},
			 File::Spec->catfile('..', $file),
			 File::Spec->catfile(basename($file)));
	}
    }

    return bless $self, $class;
}

sub start {
    my $self = shift;
    $self->NEXT::start()
}

1;
