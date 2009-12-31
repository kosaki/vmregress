#!/bin/bash

RESULT_DIR=/root/vmregressbench-`uname -r`/gsbench
EXTRA=
PS=/usr/src/gcc.ps
ITERATIONS=5

# Print usage of command
usage() {
  echo "bench-gs.sh (c) Mel Gorman 2005"
  echo This script parses a postscript file a number of times and measures
  echo the average. The objective is to measure relative CPU cache performance
  echo
  echo A good postscript file to use can be obtained at
  echo http://gcc.gnu.org/onlinedocs/gcc-3.4.3/gcc.ps.gz
  echo Download and unzip it to /usr/src/gcc.ps to be picked up by the default
  echo options
  echo
  echo "Usage: bench-gs.sh [options]"
  echo "    -p, --ps     Postscript file to interpret (default: $PS)"
  echo "    -r, --result Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra  String to append to result dir"
  echo "    -h, --help   Print this help message"
  echo
  exit
}

# Parse command line arguements
ARGS=`getopt -o hp:r:e: --long help,ps:,result:,extra: -n bench-gs.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
        -p|--ps)     export PS="$2"; shift 2;;
        -r|--result) export RESULT_DIR="$2"; shift 2;;
        -e|--extra)  export EXTRA="$2"; shift 2;;
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done

export RESULT_DIR="$RESULT_DIR$EXTRA"

# Check for postscript file
if [ ! -e "$PS" ]; then
  echo Postscript file \($PS\) does not exist
  echo Run with --help for options
  exit
fi

# Setup results directory
RESULTS=$RESULT_DIR/log.txt
if [ -e $RESULT_DIR ]; then
  echo Results directory \($RESULT_DIR\) already exists
  echo Run with --help for options
  exit
fi
mkdir -p $RESULT_DIR

RESULT="$RESULT_DIR/log.txt"

echo Reading postscript file once to make it hot in buffer cache
cat "$PS" > /dev/null
echo Starting test

echo -n > $RESULT
REAL=0
USER=0
SYS=0

for i in `seq 1 $ITERATIONS`; do
  /usr/bin/time -f "%e real, %U user, %S sys" gs -dBATCH -dNODISPLAY $PS > /tmp/log 2>> $RESULT
  echo Finished: $i - `tail -1 $RESULT`
done

IFS="
"
REAL=0
USER=0
SYS=0
for i in `cat $RESULT`; do
  THISREAL=`echo $i | awk '{print $1}'`
  THISUSER=`echo $i | awk '{print $3}'`
  THISSYS=`echo $i | awk '{print $5}'`
  REAL=`perl -e "print $REAL + $THISREAL"`
  USER=`perl -e "print $USER + $THISUSER"`
  SYS=`perl -e "print $SYS + $THISSYS"`
done

REAL=`perl -e "print $REAL/$ITERATIONS"`
USER=`perl -e "print $USER/$ITERATIONS"`
SYS=`perl -e "print $SYS/$ITERATIONS"`

echo Average: $REAL real, $USER user, $SYS sys >> $RESULT
echo Completed. Results: $RESULT
