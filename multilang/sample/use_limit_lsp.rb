require_relative "../client.rb"
xcrypt_init "limit_lsp", "core"

pp xcrypt_call("limit_lsp::initialize", 8)

template = {
  "id" => "j100_limit_lsp.rb",
  # "RANGE0" => [*1..5],
  # "after" => lambda{|this,x| "echo after #{x}"},
  # "exe0@" => lambda{|job,i| "./a.out #{i}"}
  'RANGE0' => [30,40],
  'RANGE1' => [0,1,2,3],
  'exe0' => './sample/bin/fib',
  'arg0_0@' => lambda {|_,x,y,*| x+y },
  'arg0_1@' => lambda {|this,*| "> out_#{this["id"]}"}
}

pputs "jobs",:blue
jobs = xcrypt_call("prepare", template)
pp [:jobs, jobs]

pputs "submit", :blue
pp submit(jobs)

pputs "sync", :blue
pp sync(jobs)
