#!/bin/sh
if [ "x$XCRYPT" = "x" ]; then
  echo "Set environment variable XCRYPT."
  exit 99
fi

PERLVER=5.8.5
ARCH=x86_64-linux-thread-multi
CPAN_BASE=$XCRYPT/lib/cpan
CPAN_LIB=$CPAN_BASE/usr/lib/perl5
CPAN_LIB64=$CPAN_BASE/usr/lib64/perl5

export PERL5LIB=$CPAN_LIB:$CPAN_LIB/site_perl:$CPAN_LIB64:$CPAN_LIB64/site_perl:$PERL5LIB

# /perl5/site_perl/$PERLVER/:$CPAN_DIR/usr/lib64/perl5/site_perl/$PERLVER/$ARCH/:$PERL5LIB

LIBS="EV-3.9 Event-1.13 AnyEvent-5.24 common-sense-3.0 Guard-1.021 Coro-5.21"

echo "Removing CPAN working directories."
for i in $LIBS
do
  rm -rf $i
  tar xfz $i.tar.gz
done

echo "Removing CPAN install directory."
rm -rf $CPAN_BASE/usr

echo "Start install."
for i in $LIBS
do
  (cd $i && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
done
  
# (cd EV-3.9           && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd Event-1.13       && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd AnyEvent-5.24    && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd common-sense-3.0 && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd Guard-1.021      && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
# (cd Coro-5.21        && perl Makefile.PL && make DESTDIR=$CPAN_BASE install)
