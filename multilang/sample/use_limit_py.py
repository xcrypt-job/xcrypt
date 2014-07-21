# -*- coding:utf-8 -*- 
import subprocess
import limit_py

print '** start **'
subprocess.call("rm -r inv_watch", shell=True)
execfile("client.py")

xcrypt_init("limit_py core")

limit_py.initialize(4)

def myafter(self):
    print "** my job %s finished!! **" % str(self)

template = {
  "id":"j100_simple",
  "exe0":"./a.out 10",
  "RANGE0": [1,2,3,4,5,6,7,8],
  "after": myafter
}

jobs = xcrypt_call("prepare_submit_sync",template)

print "** jobs **", jobs

print '** end **'

