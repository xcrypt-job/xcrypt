#!/bin/sh
if [ "x$XCRYPT" = "x" ]; then
  echo "Set environment variable XCRYPT."
  exit 99
fi

PERLVER=5.8.5
ARCH=x86_64-linux-thread-multi
CPAN_BASE=$XCRYPT/lib/cpan
for i in usr usr/local; do
  for j in lib lib64; do
      for k in perl5 perl5/site_perl; do
          export PERL5LIB=$CPAN_BASE/$i/$j/$k:$PERL5LIB
      done
  done
done

CPAN_LIB=$CPAN_BASE/usr/lib/perl5
CPAN_LIB64=$CPAN_BASE/usr/lib64/perl5
CPAN_LLIB=$CPAN_BASE/usr/local/lib/perl5
CPAN_LLIB64=$CPAN_BASE/usr/local/lib64/perl5

export PERL5LIB=$CPAN_LIB:$CPAN_LIB/site_perl:$CPAN_LIB64:$CPAN_LIB64/site_perl:$PERL5LIB

# /perl5/site_perl/$PERLVER/:$CPAN_DIR/usr/lib64/perl5/site_perl/$PERLVER/$ARCH/:$PERL5LIB

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
  
# (cd EV-3.9           && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd Event-1.13       && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd AnyEvent-5.24    && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd common-sense-3.0 && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd Guard-1.021      && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd Coro-5.21        && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
