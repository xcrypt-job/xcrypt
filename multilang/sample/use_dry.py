# -*- coding: utf-8 -*-
import subprocess
import sys
import time

from client import *

print "** start **"

xcrypt_init("dry", "core")
xcrypt_call("dry::initialize", {"dry":4})

def run(n):
    time.sleep(1)
    subprocess.call("rm -r inv_watch", shell=True)
    start = time.time()

    prepare_submit_sync({
            "id":"job_dry_py",
            "RANGE0":range(1,n),
            "exe0":"dummy"
            })

    print "(%djobs) time: %f" % (n, time.time() - start)

# main ----------------
for x in [10]:
#    for i in range(1,10):
        run(x)

print "** end of script **"
