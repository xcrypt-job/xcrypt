#!/bin/bash

find . -name "*.xcr.pl"| xargs rm -f
find . -name "bulk[0-9]*"| xargs rm -rf
find . -name "job[0-9]*"| xargs rm -rf
find . -name "out_*"| xargs rm -f
find . -name "inv_watch"| xargs rm -rf
find . -name "_invwrite.log"| xargs rm -f
find . -name "stdout"| xargs rm -f
find . -name "stderr"| xargs rm -f
