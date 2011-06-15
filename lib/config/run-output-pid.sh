#!/bin/sh
# -o stdofile -e stdefile scriptfile
while getopts o:e: opt
do
   case ${opt} in
    o)
        STDOFILE=${OPTARG};;
    e)
        STDEFILE=${OPTARG};;
    *)
  exit 1;;
  esac
done
if [ 'x' = "x$STDOFILE" ]; then
    echo "stdofile not given" >&2
    exit -1
fi

if [ 'x' = "x$STDEFILE" ]; then
    echo "stdefile not given" >&2
    exit -1
fi

shift `expr $OPTIND - 1`
if [ 'x' = "x$1" ]; then
    echo "scriptfile not given" >&2
    exit -1
fi

/bin/sh `basename $1` > $STDOFILE 2> $STDEFILE &
echo $!
