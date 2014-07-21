# -*- coding: utf-8 -*-
import subprocess
import time

import dry_py

from client import *

print "** start **"

xcrypt_init("dry_py", "core")
xcrypt_call("dry_py::start", "dummy")

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
for x in [400,500]:
    for i in range(0,5):
        run(x)

print "** end of script **"
