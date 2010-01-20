use ExtUtils::MakeMaker;

use 5.008001; # AnyEvent perl event loop seems to work with 5.6, other modules not

print <<EOF;

***
*** The EV module is recommended for even better performance, unless you
*** have to use one of the other adaptors (Event, Glib, Tk, etc.).
*** The Async::Interrupt module is highly recommended to efficiently avoid
*** race conditions in/with other event loops.
***
*** This module does not have ANY dependencies, even if it might look
*** otherwise. If you are building a distribution package or have
*** difficulties installing this package due to dependencies, report this
*** to the packager as a bug.
***
*** This module is guaranteed to stay 100% pure-perl, full-featured
*** and performant, even without any of the optional modules.
***

EOF

WriteMakefile(
    dist	=> {
	            PREOP	=> 'pod2text lib/AnyEvent.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
	            COMPRESS	=> 'gzip -9v',
	            SUFFIX	=> '.gz',
	           },
    test         => { TESTS => "t/*.t t/handle/*.t" },
    NAME         => "AnyEvent",
    VERSION_FROM => "lib/AnyEvent.pm",
    META_MERGE => {
        recommends => {
           "Net::SSLeay"      => 1.33,
           "JSON"             => 2.09,
           "JSON::XS"         => 2.2,
           "EV"               => 3.05,
           "Guard"            => 1.02,
           "Async::Interrupt" => 1.0,
        }
    },
);

