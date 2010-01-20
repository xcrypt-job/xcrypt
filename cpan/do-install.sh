#/bin/sh
if [ "x$XCRYPT" = "x" ]; then
  echo "Set environment variable XCRYPT."
  exit 99
fi

PERLVER=5.8.5
ARCH=x86_64-linux-thread-multi
CPAN_DIR=$XCRYPT/lib/cpan

export PERL5LIB=$CPAN_DIR/usr/lib/perl5/site_perl/$PERLVER/:$CPAN_DIR/usr/lib64/perl5/site_perl/$PERLVER/$ARCH/:$PERL5LIB

(cd EV-3.9           && perl Makefile.PL && make DESTDIR=$CPAN_DIR install)
(cd Event-1.13       && perl Makefile.PL && make DESTDIR=$CPAN_DIR install)
(cd AnyEvent-5.24    && perl Makefile.PL && make DESTDIR=$CPAN_DIR install)
(cd common-sense-3.0 && perl Makefile.PL && make DESTDIR=$CPAN_DIR install)
(cd Guard-1.021      && perl Makefile.PL && make DESTDIR=$CPAN_DIR install)
(cd Coro-5.21        && perl Makefile.PL && make DESTDIR=$CPAN_DIR install)
