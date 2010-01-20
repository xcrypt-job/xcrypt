use utf8;
use AnyEvent::Util;

$| = 1; print "1..11\n";

print "ok 1\n";

print "ko-eka" eq (AnyEvent::Util::punycode_encode "öko" ) ? "" : "not ", "ok 2\n";
print "wgv71a" eq (AnyEvent::Util::punycode_encode "日本") ? "" : "not ", "ok 3\n";

print "öko"  eq (AnyEvent::Util::punycode_decode "ko-eka") ? "" : "not ", "ok 4\n";
print "日本" eq (AnyEvent::Util::punycode_decode "wgv71a") ? "" : "not ", "ok 5\n";

print "www.xn--ko-eka.eu"   eq (AnyEvent::Util::idn_to_ascii "www.öko.eu"  ) ? "" : "not ", "ok 6\n";
print "xn--1-jn6bt1b.co.jp" eq (AnyEvent::Util::idn_to_ascii "日本1.co.jp" ) ? "" : "not ", "ok 7\n";
print "xn--tda.com"         eq (AnyEvent::Util::idn_to_ascii "xn--tda.com" ) ? "" : "not ", "ok 8\n";
print "xn--a-ecp.ru"        eq (AnyEvent::Util::idn_to_ascii "xn--a-ecp.ru") ? "" : "not ", "ok 9\n";
print "xn--wgv71a119e.jp"   eq (AnyEvent::Util::idn_to_ascii "日本語。ＪＰ") ? "" : "not ", "ok 10\n";

print "ok 11\n";
