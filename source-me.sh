if [ "x$XCRYPT" = "x" ]; then
    export XCRYPT=$HOME/xcrypt
fi
if [ "x$XCRJOBSCHED" = "x" ]; then
    export XCRJOBSCHED="sh"
fi
export PATH=$XCRYPT/bin:$PATH
export XCR_CPAN_BASE=$XCRYPT/lib/cpan
export PERL5LIB=$XCRYPT/lib:$XCRYPT/lib/algo/lib:$XCR_CPAN_BASE:$PERL5LIB
