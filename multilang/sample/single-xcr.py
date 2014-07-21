# -*- coding:utf-8 -*-
import subprocess

print '** start **'
#subprocess.call("rm -r inv_watch", shell=True)
execfile("client.py")

xcrypt_init("core")

def myafter(self):
    print "** my job %s finished!! **" % str(self)

template = {
  "id":"j100_simple",
  "exe0":"./a.out 10",
  "after": myafter
}

jobs = xcrypt_call("prepare_submit_sync",template)

print "** jobs **", jobs

print '** end **'
