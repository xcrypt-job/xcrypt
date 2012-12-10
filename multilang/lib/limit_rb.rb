### export: initialize initially finally

# ruby: filename=snake, classname=Camel
# perl: filename=Camel, classname=Camel

warn "loading Limit_rb -- limit_rb.rb"

require_relative './xcrypt_lib.rb'
include XcryptLib
require 'thread'

xcrypt_package("Limit_rb","limit_rb")

warn "loading limit_rb.rb"

module Limit_rb
  module_function

  def initialize(n)
    warn "** limit_rb::initialize n=#{n}**"
    @lock = Mutex.new
    @n = n
  end

  # def new(*args)                # hashref
  #   $log.info "limit_rb::new"
  #   warn "** limit_rb::new **"
  #   ret = call_next(self,*args)       # self==limit_rb
  #   warn [:ret, ret]
  #   exit
  # end

  #  call_next_start
  # def start
  #   warn "** limit_rb::start **"
  #   exit #!!!!!
  #   pp self
  #   call_next(self)             # xcrypt_call("NEXT->start")
  # end

  def initially(*args)
    warn "** Limit_rb::initially n:#{@n} **"
    warn [:limit_initially_args, args]

    while_cond = true
    while while_cond
      @lock.synchronize {
        if @n>0
          warn "then"
          @n -= 1
          while_cond = false
        else
          Thread.pass
          # print "."
          # sleep 0.5
        end
      }
    end

    warn "** end -- Limit_rb::initially"
    1
  end

  def finally(*args)
    warn "** Limit_rb::finally **"
    @lock.synchronize {
      @n+=1
    }
  end

  def start(job)
    warn "** Limit_rb::start **"
    xcrypt_call_next(job)
  end

end
