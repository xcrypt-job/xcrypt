# cf. to_perl.rb
module XcryptLib
  module_function

  def xcrypt_package(pl,rb)
    $XCRYPT_PACKAGE = pl
    $XCRYPT_PACKAGE_RUBY = rb
  end

  def xcrypt_use(*args)
    $XCRYPT_USE_LIBS = args
  end
end

class Module
  def xcrypt_call_next(*args)
    $log.debug "xcrypt_call_next"
    f = Thread.current[:super]
    f.call(*args)
    $log.debug "xcrypt_call_done"
  end
end







