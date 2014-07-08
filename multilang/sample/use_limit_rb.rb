require_relative "../client.rb"
require_relative "../lib/limit_rb.rb"

xcrypt_init "limit_rb", "core"

template = {
  "id" => "j100_limit_rb.rb",
  # "RANGE0" => [*1..5],
  # "after" => lambda{|this,x| "echo after #{x}"},
  # "exe0@" => lambda{|job,i| "./a.out #{i}"}
  'RANGE0' => [30,40],
  'RANGE1' => [0,1,2,3],
  'exe0' => '~/Xcrypt/sample/bin/fib',
  'arg0_0@' => lambda {|_,x,y,*| x+y },
  'arg0_1@' => lambda {|this,*| "> out_#{this["id"]}"}
}

pp xcrypt_call("limit_rb::initialize", 8)

pputs "jobs",:blue
jobs = xcrypt_call("prepare", template)
pp [:jobs, jobs]

pputs "submit", :blue
pp submit(jobs)

pputs "sync", :blue
pp sync(jobs)
