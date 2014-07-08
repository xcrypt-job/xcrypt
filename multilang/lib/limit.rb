### export: initialize initially finally

# ruby: filename=snake, classname=Camel
# perl: filename=Camel, classname=Camel

warn "loading limit -- limit.rb"

require_relative './xcrypt_lib.rb'
include XcryptLib
require 'thread'

xcrypt_package("Limit","limit")

warn "loading limit.rb"

module Limit
  module_function

  def initialize(n)
    warn "** Limit::initialize n=#{n}**"
    @lock = Mutex.new
    @n = n
  end

  # def new(*args)                # hashref
  #   $log.info "Limit::new"
  #   warn "** Limit::new **"
  #   ret = call_next(self,*args)       # self==Limit
  #   warn [:ret, ret]
  #   exit
  # end

  #  call_next_start
  # def start
  #   warn "** Limit::start **"
  #   exit #!!!!!
  #   pp self
  #   call_next(self)             # xcrypt_call("NEXT->start")
  # end

  def initially(*args)
    warn "** Limit::initially n:#{@n} **"
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

    warn "** end -- Limit::initially"
    1
  end

  def finally(*args)
    warn "** Limit::finally **"
    @lock.synchronize {
      @n+=1
    }
  end

  def start(job)
    warn "** Limit::start **"
    xcrypt_call_next(job)
  end

end
