#!/bin/sh
if [ "x$XCRYPT" = "x" ]; then
  echo "Set environment variable XCRYPT."
  exit 99
fi

## source source-me.sh before executing this script
# CPAN_BASE=$XCRYPT/lib/cpan
# for i in usr usr/local; do
#   for j in lib lib64; do
#       for k in perl5 perl5/site_perl; do
#           export PERL5LIB=$CPAN_BASE/$i/$j/$k:$PERL5LIB
#       done
#   done
# done

LIBS="File-Copy-Recursive-0.38 EV-3.9 Event-1.13 AnyEvent-5.24 common-sense-3.0 Guard-1.021 Coro-5.21-without-conftest"

echo "Removing CPAN working directories."
for i in $LIBS
do
  rm -rf $i
  tar xfz $i.tar.gz
done

echo "Removing CPAN install directory."
rm -rf $CPAN_BASE/usr

echo "Start installation."
for i in $LIBS
do
  echo ">>> installing $i <<<"
  (cd $i && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
done
