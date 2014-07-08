#!/bin/sh
CC=gcc
LD=gcc

# Install Directory
INSTALLDIR_DEFAULT=`pwd`
if [ "x$INSTALLDIR" = "x" ]; then
    echo -n "Install Directory [default=$INSTALLDIR_DEFAULT]: "
    read INSTALLDIR
    if [ "x$INSTALLDIR" = "x" ]; then
        INSTALLDIR=$INSTALLDIR_DEFAULT
    fi
fi

if [ ! -d $INSTALLDIR ]; then
  echo "Error: $INSTALLDIR is not a directory. Please specify the existing Xcrypt root directory."
fi

echo $INSTALLDIR

# Perl library paths
XCR_CPAN_BASE=$INSTALLDIR/lib/cpan
PERL5LIB=$INSTALLDIR/lib:$INSTALLDIR/lib/algo/lib:$XCR_CPAN_BASE:$PERL5LIB

#########################################################
echo "##### Installing CPAN libraries #####"
LIBS="Config-Simple-4.59-without-flock Data-Dumper-2.151 File-Copy-Recursive-0.38 EV-4.11 Event-1.22 AnyEvent-7.01 common-sense-3.6 Guard-1.021 Coro-6.39-without-conftest Net-OpenSSH-0.57 Error-0.17018 Text-CSV_XS-0.90 JSON-2.53 Log-Handler-0.75 TermReadKey-2.32"

echo "### Removing CPAN working directories. ###"
for i in $LIBS
do
    rm -rf $INSTALLDIR/cpan/$i
done

echo "### Extracting CPAN archives. ###"
for i in $LIBS
do
    GZFILE=$INSTALLDIR/cpan/$i.tar.gz
    if [ ! -f $GZFILE ]; then
        echo "Error: CPAN archive $GZFILE does not exist."
        exit 99
    fi
    tar xfz $GZFILE -C $INSTALLDIR/cpan
done    

echo "### Removing CPAN install directory. ###"
rm -rf $XCR_CPAN_BASE

echo "### Starting CPAN installation. ###"
for i in $LIBS
do
  echo; echo "# installing $i #"
  (cd $INSTALLDIR/cpan/$i && perl Makefile.PL LIB=$XCR_CPAN_BASE && make CC=$CC LD=$LD INSTALLSITEMAN3DIR=none install)
done
echo

#########################################################
echo "##### Generating a wrapper script #####"

BINDIR=$INSTALLDIR/bin
WRAPPER_FILE=.wrapper
WRAPPER=$BINDIR/$WRAPPER_FILE
WRAPPER_TMPL=$BINDIR/wrapper-template

if [ ! -f $WRAPPER_TMPL ]; then
    echo "Error: $WRAPPER_TMPL does not exist."
    exit 99
fi

rm -f $WRAPPER
sed s#@@INSTALLDIR@@#$INSTALLDIR# < $WRAPPER_TMPL > $WRAPPER
chmod --reference=$WRAPPER_TMPL $WRAPPER

#########################################################
echo "##### Generating Xcrypt commands #####"
for i in xcrypt xcryptdel xcryptstat xcryptsched
do
    (cd $BINDIR; rm -f $i; ln -s $WRAPPER_FILE $i)
    echo Created $BINDIR/$i
done

#########################################################
echo "#######################################"
echo "Installation finished."
echo "Add $INSTALLDIR/bin to your execution path and you can run xcrypt."

