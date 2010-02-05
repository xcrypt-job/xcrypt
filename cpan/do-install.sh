#!/bin/sh
## source source-me.sh before executing this script

if [ "x$XCRYPT" = "x" ]; then
  echo "Set environment variable XCRYPT."
  exit 99
fi

LIBS="File-Copy-Recursive-0.38 EV-3.9 Event-1.13 AnyEvent-5.24 common-sense-3.0 Guard-1.021 Coro-5.21-without-conftest"

echo "Removing CPAN working directories."
for i in $LIBS
do
  rm -rf $i
  tar xfz $i.tar.gz
done

echo "Removing CPAN install directory."
rm -rf $XCR_CPAN_BASE/usr

echo "Start installation."
for i in $LIBS
do
  echo ">>> installing $i <<<"
  (cd $i && perl Makefile.PL LIB=$XCR_CPAN_BASE && make INSTALLSITEMAN3DIR=none install)
done
