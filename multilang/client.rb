# -*- coding: utf-8 -*-
# -*- ruby-indent-level:2 indent-tabs-mode:nil -*-
require 'highline'
require 'json'
require 'logger'
require 'pp'
require 'socket'
require 'thread'
require 'timeout'
require 'optparse'

$DEBUG = true #trap error in all threads
$debug = true # ENV["XCRYPT_DEBUG"]

file_stdout = open("log-client.o", "w") or raise "io error"
file_stderr = open("log-client.e", "w") or raise "io error"
$stdout = file_stdout
$stderr = file_stderr
$stdout.sync = $stderr.sync = true

5.times{$stdout.puts;$stderr.puts}

$: << "#{File.dirname(__FILE__)}/lib" # load path
$Functions = {}
$Job_objs = {}                  # eachで回せる / ユーザーにさせる
$queues = {}                    # key: Thread.current.to_s
$locker = Mutex.new
$server = nil

# for debug
$highline = HighLine.new
def pputs(s,color=:red)
  puts $highline.color(s + " -- #{caller[0]}", color)
end

$log = @log = Logger.new($stderr)
@log.level = Logger::DEBUG
_orig_formatter = Logger::Formatter.new
@log.formatter = lambda {|s,date,prog,m|
  _orig_formatter.call(s,date,prog,"#{m} @ #{caller.last.match(/[^\/]+:\d+/)}")
}

# ----------------
# Ruby => JSON
# ----------------
class Proc
  def to_json(*state)
    $Functions[self.to_s] = self
    %Q({"type":"function/ext", "id":"#{self.to_s}"})
  end
end

# ----------------
# JSON => Ruby
# ----------------
def convert_to_job_object(id)
  return $Job_objs[id] ||= XcryptJobObject.new(id)
end

def retrieve_function(a)
  case a
  when Hash
    case a["type"]
    when "job_obj"
      return convert_to_job_object(a["id"])
    when "function/ext"         # Lispのが混じってたらどうする？
      if $Functions[ a["id"] ]  # テーブルに存在
        # fixme: 存在するとはかぎらない(lispかも)
        @log.debug("function/ext")
        @log.debug(a["id"])
        return $Functions[ a["id"] ] if a["id"]
        @log.debug("found function/ext, but this is not a ruby function")
      else
        raise "#{a["id"]} not found in $Functions"
      end
    when "function/pl"
      # perlの関数を呼び出す関数
      return lambda {|*args| xcrypt_call(a, *args)}
    else
      a.each {|k,v| a[k] = retrieve_function(v)}
      return a
    end

  when Array
    return a.map {|e| retrieve_function(e)}

  else
    return a
  end
end

class XcryptJobObject
  def initialize(id)
    @id = id
    $Job_objs[id] ||= self
  end

  attr_reader :id

  def get(field)
    xcrypt_call("get", self, field)
  end

  def set(field, newvar)
    xcrypt_call("set", self, field, newvar)
  end

  def funcall(field, *args)
    # ジョブオブジェクトのメンバー名で関数呼び出し
    xcrypt_call(get(field), self, *args)
  end

  def to_json(*)
    '{"type":"job_obj","id":"' + @id.to_s + '"}'
  end

  def call_next(*args)
    funcall("next", *args)
  end

  def submit
    xcrypt_call("submit", self)
  end
end

# ----------------
# User Functions
# ----------------
def make_foreign_function_callable(fn)
  Kernel.send :define_method, :"#{fn}" do |*args|
    xcrypt_call(fn, *args)
  end
end

job_api_functions = ["prepare", "submit", "sync", "prepare_submit", "submit_sync", "prepare_submit_sync"]
job_api_functions.each {|f| make_foreign_function_callable(f)}

# Send anything to server.
def xcrypt_send(message, dst = $server)
  $log.debug "==> sending -- xcrypt_send"
  $log.debug message

  $locker.synchronize do
    dst.print(message.to_json + "\n")
    dst.flush
  end
end

# Send "funcall" message to server.
def xcrypt_call(fn, *args)
  $queues[ Thread.current.to_s ] = Queue.new # fix me

  xcrypt_send({
      "thread_id" => Thread.current.to_s,
      "exec" => "funcall",
      "function" => fn,
      "args" => args
  })

#  @log.debug "waiting '#{fn}' -- xcrypt_call"
  return $queues[ Thread.current.to_s ].pop
end

# fork perl process, connect_to_server and launch_dispatch.
def xcrypt_init(*libs)
  @log.debug " --xcrypt_init"
  open("temp.xcr","w") {|f|
    f.print "use base qw(#{libs.join(' ')});"
  }
  `cat #{File.expand_path("communicator.xcr")} >> temp.xcr` # fixme: don't use system()
  fork do
    # STDOUT.reopen File.open('log-communicator.o', 'w')
    # STDERR.reopen File.open('log-communicator.e', 'w')
    # exec "xcrypt", "--xcrypt-rpc-lang=ruby", "temp.xcr"
    exec "xcrypt", "--lang=ruby", "temp.xcr"
  end

  sleep 3
  connect_to_server and launch_dispatch or exit
end

# Send "finish" message to server
# fixme
def xcrypt_finish(message=nil)
  xcrypt_call("finish",message)
  exit
end

# ----------------
# Internal functions
# ----------------
def launch_dispatch
  @log.info "start -- launch_dispatch"
  Thread.start do
    begin
      dispatch
    rescue
      @log.fatal($!)
    end
  end
end

def dispatch
  # serverと接続後!
  loop do
    @log.fatal("Server is undef") unless $server
    line = $server.gets.chomp
    @log.info "<== gotline -- dispatch" if $debug
    @log.debug('raw string') {line}

    hash = JSON.parse(line)
    pp(hash);
    message = retrieve_function(hash)

    @log.debug('retrieved') {message}

    case message["exec"]
    when "return"
      $queues[message["thread_id"]].push message["message"]
    when "funcall"
      @log.info "-- funcall" if $debug
      Thread.start(message) {|message|
        @log.debug "-- funcall thread start" if $debug
        fn = message["function"]
        args = message["args"]
        Thread.current[:super] = message["super"] or @log.fatal "NO SUPER"

        if fn.class == Proc
          ret = fn.call(*args)
        else
          @log.debug [:eval, fn, :args, args]

          # get method with Object#method
          if fn =~ /(.*)::(.*)/
            p [$1,$2]
            module_name, fn_name = $1,$2

            p m = eval(module_name).method(:"#{fn_name}")
            ret = m.call(*args)
          else
            p fn
            # p m = self.method(:"#{fn}")
            p m = $Functions[fn]
            ret = m.call(*args)
          end
        end

        xcrypt_send({
            "thread_id" => message["thread_id"],
            "exec" => "return",
            "message" => ret
        })
        @log.debug "-- funcall thread finish" if $debug
      }
    else
      log.fatal message
      raise "invalid message -- dispatch"
      exit
    end
  end
end

def connect_to_server
  begin
    @log.debug "connect_to_server" if $debug
#    timeout(3) do
      $server = TCPSocket.new("localhost", 9000)
      @log.debug $server
#    end
  rescue
    @log.fatal "error: #{$!} -- connect_to_server"
    exit
  end
end

# ----------------
# main
# ----------------
#if __FILE__ == $0

# check commandline options
# --libs=<ruby libs to load>
# --xcrypt-rpc-client (要る？)
params = OptionParser.getopts(nil, "xcrypt-rpc-libs:", "xcrypt-rpc-client")

if params["xcrypt-rpc-client"]
  params["xcrypt-rpc-libs"] and params["xcrypt-rpc-libs"].split(',').each {|f|
    @log.debug "load module '#{f}'"
    require f
  }
  @log.debug "modules loaded"

  connect_to_server
  dispatch

else
  # load "client.rb"で読み込まれた => xcrypt_init
end

at_exit do
  pputs("ruby process terminating...", :blue)

  # warning!
  file_stdout.close if file_stdout
  file_stderr.close if file_stdout
  $stdout = STDOUT
  $stderr = STDERR
end
