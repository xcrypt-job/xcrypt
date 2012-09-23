sub unbless {
    my $obj = shift;
    my $unblessed_obj = {};
    foeach my $k (keys $obj) {
	$unblessed_obj->{$k} = $obj->{$k};
    }
    return $unblessed_obj;
}

# Currently, only supports dumping a job object    
sub make_dumped_environment {
    my ($self) = @_;
    my $self_in_lisp = xcrypt_call ('SERIALIZE', unbless ($self));
    my @body = ();
    ## serialized self in Lisp
    push (@body, "(defconstant +self+ '$self_in_lisp)");
    $self->{dumped_environment} = \@body;
}

# set a script to {before_in_job_script} by employing make_in_job_script()
sub make_before_in_job_script {
    my $self = shift;
    my @body = ();
    if (defined ($self->{before_in_job})) {
        push (@body, 'before_in_job');
    }
    # Calls it even if @body is empty because child methods may add code
    $self->make_in_job_script ('before_in_job_script', @body);
}

# set a script to {exe_in_job_script} by employing make_in_job_script()
sub make_exe_in_job_script {
    my $self = shift;
    if (defined ($self->{exe})) {
        $self->make_in_job_script ('exe_in_job_script', 'exe');
    }
}

# set a script to {afeter_in_job_script} by employing make_in_job_script()
sub make_after_in_job_script {
    my $self = shift;
    my @body = ();
    if (defined ($self->{after_in_job})) {
        push (@body, 'after_in_job')
    }
    # Calls it even if @body is empty because child methods may add code
    make_in_job_script ($self, 'after_in_job_script', @body);
}

# Create and set a script to {$memb_script}
sub make_in_job_script {
    my ($self, $memb_script, @body) = @_;
    my @script = ();
    ## The snapshot of the Perl(Xcyrpt) environment
    push (@script, @{$self->{dumped_environment}});
    ## Calling the dumped method and writing the return value.
    foreach my $name (@body) {
        if (deifned ($self->{$name})) {
            push (@script, "($name +self+)");
        }
    }
    $self->{$memb_script} = \@script;
}
