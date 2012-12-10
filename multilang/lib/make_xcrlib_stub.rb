#!env ruby
## Usage: ruby <lang> <package> <func_names...>
require 'pp'
require 'fileutils'

def make_xcrlib_stub(lang, package, *funcs)
  begin
    # # package
    # raise unless $XCRYPT_PACKAGE
    # package = $XCRYPT_PACKAGE
    ENV["XCRYPT_LIB"] ||= "./"
    outpath = File.join(ENV["XCRYPT_LIB"], "#{package}.pm")

    out = open(outpath, "w")

    out.puts "require \"communicator.pm\";"
    out.puts "push(@Comm::langs_in_libs, \"#{lang}\");"
    out.puts "push(@{$Comm::sockets->{#{lang}}->{libs}},\"#{package}\");"
    
    puts "package #{package};"
    out.puts "package #{package};"

#    if $XCRYPT_USE_LIBS
#      $XCRYPT_USE_LIBS.each {|lib|
#        puts "use #{lib};"
#        out.puts "use #{lib};"
#      }
#    end

    funcs.each do |fn|
      out.puts <<EOH
sub #{fn} {
    my ($self, @args) = @_; # fixme
    my $sig=new Coro::Signal;
    my $msg='';
    my @super_args, $super_ret;
    my $remote_thr = Coro::async {
        my $remote_ret = user::xcrypt_call_with_super(
            '#{lang}',
            sub {
                @super_args = @_;
                $msg='super_call'; $sig->broadcast();
                until ($msg eq 'super_ret') {
                    $sig->wait;
                }
                return $super_ret;
            },
            '#{package}::#{fn}', $self, @args);
        $msg='remote_ret'; $sig->broadcast();
        return $remote_ret;
    };
    until ($msg eq 'remote_ret') {
        $sig->wait();
        if ($msg eq 'super_call') {
            $super_ret = $self->NEXT::#{fn}(@super_args);
            $msg='super_ret';  $sig->broadcast();
        }
    }
    return $remote_thr->join();
}
EOH
    end

    out.puts "1;"

  end
end

# main
make_xcrlib_stub(*ARGV)
