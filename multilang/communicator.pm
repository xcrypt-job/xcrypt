package Comm;
use strict;
use warnings;

use Coro::Socket;
use Coro::Channel;              # also in coro.pm
use Switch;

use JSON;
use NEXT;

# for debug
use Log::Handler;
use Data::Dumper;
use Carp;

use FindBin qw($Bin);
use lib $Bin;

our @langs_in_libs = ();

our $sockets = {
    ruby => {
        port=>9000, bin=>'ruby client.rb',
        socket=>undef, dispatch=>undef, pid=>undef,
        lock=>Coro::Semaphore->new(1), queue=>{}, libs=>[]},
    lisp => {
        port=>9001,
	bin=>"alisp -L ~/quicklisp/setup.lisp -L $ENV{XCRYPT}/multilang/client.lisp -kill --",
        socket=>undef, dispatch=>undef, pid=>undef,
        lock=>Coro::Semaphore->new(1), queue=>{}, libs=>[]},
};


1;
