#!/bin/sh
## source source-me.sh before executing this script
CC=gcc
LD=gcc

if [ "x$XCRYPT" = "x" ]; then
  echo "Set environment variable XCRYPT."
  exit 99
fi
if [ "x$XCR_CPAN_BASE" = "x" ]; then
  echo "Set environment variable XCR_CPAN_BASE."
  exit 99
fi

LIBS="Config-Simple-4.59-without-flock Data-Dumper-2.131 File-Copy-Recursive-0.38 EV-4.11 Event-1.20 AnyEvent-7.01 common-sense-3.6 Guard-1.021 Coro-6.08-without-conftest Net-OpenSSH-0.57 Error-0.17018 Text-CSV_XS-0.90 JSON-2.53 Log-Handler-0.75"

echo "Removing CPAN working directories."
for i in $LIBS
do
  rm -rf $i
  tar xfz $i.tar.gz
done

echo "Removing CPAN install directory."
rm -rf $XCR_CPAN_BASE

echo "Start installation."
for i in $LIBS
do
  echo ">>> installing $i <<<"
  (cd $i && perl Makefile.PL LIB=$XCR_CPAN_BASE && make CC=$CC LD=$LD INSTALLSITEMAN3DIR=none install)
done
