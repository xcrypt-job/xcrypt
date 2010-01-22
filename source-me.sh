export XCRYPT=/path/to/xcrypt
export XCRJOBSCHED="sh"
export PERL5LIB=$XCRYPT/lib:$PERL5LIB
CPAN_BASE=$XCRYPT/lib/cpan
for i in usr usr/local; do
  for j in lib lib64; do
      for k in perl5 perl5/site_perl; do
          export PERL5LIB=$CPAN_BASE/$i/$j/$k:$PERL5LIB
      done
  done
done
