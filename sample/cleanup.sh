#!/bin/bash

echo 1; find . -name "*.xcr.pl"| xargs rm -f
echo 2; find . -name "invwrite-sock.log"| xargs rm -f
echo 3; find . -name "job[0-9]*"| xargs rm -rf
echo 4; find . -name "job_lu*"| xargs rm -rf
echo 5; find . -name 'job-xcrypt'| xargs rm -rf
echo 6; find . -name "inv_watch"| xargs rm -rf

