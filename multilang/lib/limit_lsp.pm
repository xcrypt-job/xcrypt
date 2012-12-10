require "communicator.pm";
push(@Comm::langs_in_libs, "lisp");
push(@{$Comm::sockets->{lisp}->{libs}},"limit_lsp");
package limit_lsp;
sub initialize {
    my ($self, @args) = @_; # fixme
    my $sig=new Coro::Signal;
    my $msg='';
    my @super_args, $super_ret;
    my $remote_thr = Coro::async {
        my $remote_ret = user::xcrypt_call_with_super(
            'lisp',
            sub {
                @super_args = @_;
                $msg='super_call'; $sig->broadcast();
                until ($msg eq 'super_ret') {
                    $sig->wait;
                }
                return $super_ret;
            },
            'limit_lsp::initialize', $self, @args);
        $msg='remote_ret'; $sig->broadcast();
        return $remote_ret;
    };
    until ($msg eq 'remote_ret') {
        $sig->wait();
        if ($msg eq 'super_call') {
            $super_ret = $self->NEXT::initialize(@super_args);
            $msg='super_ret';  $sig->broadcast();
        }
    }
    return $remote_thr->join();
}
sub initially {
    my ($self, @args) = @_; # fixme
    my $sig=new Coro::Signal;
    my $msg='';
    my @super_args, $super_ret;
    my $remote_thr = Coro::async {
        my $remote_ret = user::xcrypt_call_with_super(
            'lisp',
            sub {
                @super_args = @_;
                $msg='super_call'; $sig->broadcast();
                until ($msg eq 'super_ret') {
                    $sig->wait;
                }
                return $super_ret;
            },
            'limit_lsp::initially', $self, @args);
        $msg='remote_ret'; $sig->broadcast();
        return $remote_ret;
    };
    until ($msg eq 'remote_ret') {
        $sig->wait();
        if ($msg eq 'super_call') {
            $super_ret = $self->NEXT::initially(@super_args);
            $msg='super_ret';  $sig->broadcast();
        }
    }
    return $remote_thr->join();
}
sub finally {
    my ($self, @args) = @_; # fixme
    my $sig=new Coro::Signal;
    my $msg='';
    my @super_args, $super_ret;
    my $remote_thr = Coro::async {
        my $remote_ret = user::xcrypt_call_with_super(
            'lisp',
            sub {
                @super_args = @_;
                $msg='super_call'; $sig->broadcast();
                until ($msg eq 'super_ret') {
                    $sig->wait;
                }
                return $super_ret;
            },
            'limit_lsp::finally', $self, @args);
        $msg='remote_ret'; $sig->broadcast();
        return $remote_ret;
    };
    until ($msg eq 'remote_ret') {
        $sig->wait();
        if ($msg eq 'super_call') {
            $super_ret = $self->NEXT::finally(@super_args);
            $msg='super_ret';  $sig->broadcast();
        }
    }
    return $remote_thr->join();
}
1;
