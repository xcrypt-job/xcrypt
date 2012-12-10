package injob_lisp;

sub new {
    my $class = shift;
    my $self = $class->NEXT::new(@_);
    $self->{injob_program} = 'alisp -qq -s';
    return bless $self, $class;
}

sub unbless {
    my $obj = shift;
    my $unblessed_obj = {};
    foreach my $k (keys %{$obj}) {
	$unblessed_obj->{$k} = $obj->{$k};
    }
    return $unblessed_obj;
}

# Currently, only supports dumping a job object    
sub make_dumped_environment {
    my $self = shift;
    my $self_in_lisp = user::xcrypt_call ('lisp', 'cl-user::serialize', unbless ($self));
    my @body = ();
    ## serialized self in Lisp
    push (@body, "(defconstant +self+ '$self_in_lisp)");
    push (@body, "
(defun jobobj-get (jobj memb)
  (cdr (assoc memb jobj :test #'equal)))
");
    $self->{dumped_environment} = \@body;
}

# set a script to {before_in_job_script} by employing make_in_job_script()
sub make_before_in_job_script {
    my $self = shift;
    my @body = ();
    if (defined ($self->{before_in_job})) {
        push (@body, $self->{before_in_job});
    }
    # Calls it even if @body is empty because child methods may add code
    $self->make_in_job_script ('before_in_job_script', @body);
}

# set a script to {exe_in_job_script} by employing make_in_job_script()
sub make_exe_in_job_script {
    my $self = shift;
    my @body = ();
    if (defined ($self->{exe})) {
        push (@body, $self->{exe});
    }
    # Calls it even if @body is empty because child methods may add code
    if (defined ($self->{exe})) {
        $self->make_in_job_script ('exe_in_job_script', @body);
    }
}

# set a script to {afeter_in_job_script} by employing make_in_job_script()
sub make_after_in_job_script {
    my $self = shift;
    my @body = ();
    if (defined ($self->{after_in_job})) {
        push (@body, $self->{after_in_job})
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
    foreach my $func (@body) {
        push (@script, "($func +self+)");
    }
    $self->{$memb_script} = \@script;
}

1;
