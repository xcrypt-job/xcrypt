#!/bin/sh

# Compiler settings
CC="gcc"
LD="gcc"
if [ `uname` = 'AIX' ]; then
    CC="xlc_r -q32"
    LD="xlc_r -q32"
fi

# Installation settings
# In some system we need to wait for a few seconds between "make" and "make install"
SLEEP=5

# Install Directory
INSTALLDIR_DEFAULT=`pwd`
if [ "x$INSTALLDIR" = "x" ]; then
    printf "Install Directory [default=$INSTALLDIR_DEFAULT]: "
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
    RMVDIR=$INSTALLDIR/cpan/$i
    if [ -e $RMVDIR ]; then
        echo "Removing $RMVDIR"
        rm -rf $RMVDIR
    fi
done

echo "### Extracting CPAN archives. ###"
for i in $LIBS
do
    GZFILE=$INSTALLDIR/cpan/$i.tar.gz
    if [ ! -f $GZFILE ]; then
        echo "Error: CPAN archive $GZFILE does not exist."
        exit 99
    fi
    echo "Extracting $GZFILE"
    gzip -dc $GZFILE | tar -xf - -C $INSTALLDIR/cpan
done    

echo "### Removing CPAN install directory. ###"
if [ -e $XCR_CPAN_BASE ]; then
    echo "Removing $XCR_CPAN_BASE"
    rm -rf $XCR_CPAN_BASE
fi

echo "### Installing CPAN libraries. ###"
for i in $LIBS
do
  echo; echo "# Installing $i #"
  (cd $INSTALLDIR/cpan/$i && perl Makefile.PL LIB=$XCR_CPAN_BASE && make CC="$CC" LD="$LD" INSTALLSITEMAN3DIR=none && sleep $SLEEP ; make CC="$CC" LD="$LD" INSTALLSITEMAN3DIR=none install)
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
cp -p $WRAPPER_TMPL $WRAPPER
sed s#@@INSTALLDIR@@#$INSTALLDIR# < $WRAPPER_TMPL > $WRAPPER

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

