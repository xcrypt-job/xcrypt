package return_transmission;

use base qw(Exporter);
our @EXPORT = qw(
get_before_in_job_return get_before_return
get_after_in_job_return  get_after_return
return_write
data_dumper
);
use strict;
use builtin;
use File::Spec;
use File::Path;
use Data::Dumper;
$Data::Dumper::Deparse  = 1;
$Data::Dumper::Deepcopy = 1;
$Data::Dumper::Maxdepth = 5;

sub get_before_in_job_return {
    my $self = shift;
    my $get_id = shift;
    if ($get_id eq "") {$get_id = $self->{id}};
    return &get_xxx_return($self, $get_id, 'before_in_job');
}
sub get_before_return {
    my $self = shift;
    my $get_id = shift;
    if ($get_id eq "") {$get_id = $self->{id}};
    return &get_xxx_return($self, $get_id, 'before');
}
sub get_after_in_job_return {
    my $self   = shift;
    my $get_id = shift;
    if ($get_id eq "") {$get_id = $self->{id}};
    return &get_xxx_return($self, $get_id, 'after_in_job');
}
sub get_after_return {
    my $self   = shift;
    my $get_id = shift;
    if ($get_id eq "") {$get_id = $self->{id}};
    return &get_xxx_return($self, $get_id, 'after');
}
sub get_xxx_return {
    my $self   = shift;
    my $get_id = shift;
    if ($get_id eq "") {$get_id = $self->{id}};
    my $return_file;
    my $return_dir =  File::Spec->catfile($self->{env}->{wd}, "${get_id}");
    if (-d $return_dir) {
        $return_file =  File::Spec->catfile($self->{env}->{wd}, "${get_id}", "${get_id}_return");
    } else {
        $return_file =  File::Spec->catfile($self->{env}->{wd}, "${get_id}_return");
    }
    my $get_nm = shift;
    sleep 1;
    open (RETURN_R, "+< $return_file") or warn "Cannot open $return_file";
    my $return_datas = '';
    while (my $rec_data = <RETURN_R>){
        $return_datas .= $rec_data;
    }
    close(RETURN_R);
    my @return_datas = split /\n\r\n/, $return_datas;
    for (my $i = 0; $i <= $#return_datas; $i++) {
        if ($return_datas[$i] =~ /${get_nm} =/) {
            my $get_retuen_data = eval("my $return_datas[$i]");
            my $get_retuen_type = ref($get_retuen_data);
            if ($get_retuen_type eq "ARRAY") {
                return @{$get_retuen_data};
            } elsif ($get_retuen_type eq "HASH") {
                return %{$get_retuen_data};
            } elsif ($get_retuen_type eq "CODE") {
                return &{$get_retuen_data};
            } else {
                return $get_retuen_data;
            }
        }
    }
    warn "There was not the return value of the target.(id=${get_id} sub=${get_nm})\n";
}

sub return_write {
    my $self    = shift;
    my $summons = shift;
    my $return_file =  File::Spec->catfile($self->{env}->{wd}, "$self->{workdir}", "$self->{id}_return");
    open (RETURN_W, "+>> $return_file") or warn "Cannot open $return_file";
    flock RETURN_W, 2;
    if (exists $self->{"transfer_reference_level"}) {
        $Data::Dumper::Maxdepth = $self->{"transfer_reference_level"};
    }
    my $dumper = Data::Dumper->Dump([@_],["${summons}"]);
    $dumper =~ s/([\[\{])\n\s+(\')/$1$2/g;
    $dumper =~ s/([\',]{1})\n\s+(\')/$1$2/g;
    $dumper =~ s/(\')\n\s+([\]\}])/$1$2/g;
    $dumper .= "\n\r\n";
    print RETURN_W "$dumper";
    close(RETURN_W);
}

sub data_dumper {
    my $self = shift;
    my @body = ();
    # Data_Dumper(Object)
    my %dump_self = ();
    foreach my $k (keys %{$self}) {
        if ((grep {"$_" =~ /^$k$/} @{$self->{not_transfer_info}}) == 0) {
            $dump_self{$k} = $self->{$k};
        }
    }
    if (exists $self->{transfer_reference_level}) {
        $Data::Dumper::Maxdepth = $self->{transfer_reference_level};
    }
    my $dumper = Data::Dumper->Dump([\%dump_self],['self']);
    my @dmps = split /\n/, $dumper;
    foreach my $dmp (@dmps) {
        if ($dmp !~ /package\s+user/) {
            push (@body, $dmp);
        }
    }
    push (@body, 'bless $self;');
    push (@body, 'sub before {if ($self->{before}) {&{$self->{before}}($self, @{$self->{VALUE}})};}');
    push (@body, 'sub after  {if ($self->{after} ) {&{$self->{after}}($self, @{$self->{VALUE}})};}');
    # Data_Dumper(User Script)
    while (my ($k,$v) = each %user::) {
        if ($k =~ /^[a-zA-Z]+/ and $k !~ /\:$/) {
            my $dumper = '';
            if (*{$v}{ARRAY} ne "") {
                if ((grep {"$_" =~ /^\@$k$/} @{$self->{transfer_variable}}) > 0) {
                    $dumper .= &dump_array($k, $v);
                }
            }
            if (*{$v}{HASH} ne "") {
                if ((grep {"$_" =~ /^\%$k$/} @{$self->{transfer_variable}}) > 0) {
                    $dumper .= &dump_hash($k, $v);
                }
            }
            if (*{$v}{CODE} ne "") {
                if ((grep {"$_" =~ /^\&$k$/} @{$self->{transfer_variable}}) > 0 or
                    (grep {"$_" =~ /^$k$/} @{$self->{transfer_variable}}) > 0) {
                    $dumper .= &dump_code($k, $v);
                }
            }
            if (*{$v}{SCALAR} =~ /^SCALAR/ and $v =~ /^\*user\:\:[a-zA-Z]/) {
                if ((eval "\$user::$k") ne "") {
                    $dumper .= &dump_scalar($k, $v);
                }
            }
            if (*{$v}{SCALAR} =~ /^REF/ and $v =~ /^\*user\:\:[a-zA-Z]/) {
                if ((grep {"$_" =~ /^\$$k$/} @{$self->{transfer_variable}}) > 0) {
                    $dumper .= &dump_ref($k, $v);
                }
            }
            if ($dumper ne '') {
                push (@body, $dumper);
            }
        }
    }
    return @body;
}

sub dump_array {
    my ($k, $v) = @_;
    $v =~ s/\*/\@/;
    my @array_datas = eval $v;
    my $dumper = Data::Dumper->Dump([\@array_datas], ["$k"]);
    $dumper =~ tr/\$/\@/;
    $dumper =~ s/= \[/= (/;
    $dumper =~ s/\];/);/;
    return $dumper;
}

sub dump_hash {
    my ($k, $v) = @_;
    $v =~ s/\*/\%/;
    my %hash_datas = eval $v;
    my $dumper = Data::Dumper->Dump([\%hash_datas], ["$k"]);
    $dumper =~ tr/\$/\%/;
    $dumper =~ s/= \{/= (/;
    $dumper =~ s/\n\s+package\s+user;\n/\n/;
    $dumper =~ s/\};/);/;
    return  $dumper;
}

sub dump_code {
    my ($k, $v) = @_;
    my $code_name = "user::$k";
    my $dumper = Data::Dumper->Dump([\&$code_name]);
    if ($dumper =~ /package\s+user/) {
        $dumper =~ s/\$.+sub/sub $k/;
        $dumper =~ s/\n\s+package\s+user;\n/\n/;
        return $dumper;
    }
}

sub dump_scalar {
    my ($k, $v) = @_;
    $v =~ s/\*/\$/;
    if ($k ne 'self') {
        my $v2 = eval $v;
        return  "\$$k = '$v2'".';';
    }
}

sub dump_ref {
    my ($k, $v) = @_;
    $v =~ s/\*/\$/;
    my $evaledVal = eval $v;
    if ($evaledVal =~ /^ARRAY/ or $evaledVal =~ /^HASH/) {
        my $dumper = Data::Dumper->Dump([$evaledVal], ["$k"]);
        return $dumper;
    } elsif (ref (\&$v) eq 'CODE') {
        my $dumper = Data::Dumper->Dump([\&$evaledVal], ["$k"]);
        if ($dumper =~ /package\s+user/) {
            $dumper =~ s/\n\s+package\s+user;\n/\n/;
            return $dumper;
        }
    }
}

1;
