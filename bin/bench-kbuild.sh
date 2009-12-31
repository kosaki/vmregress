#!/bin/bash

VMREGRESS_DIR=/usr/src/vmregress
KERNEL_TAR=/usr/src/linux-2.6.11.tar.gz
BUILD_DIR=/usr/src/bench-kbuild-test
RESULT_DIR=$HOME/vmregressbench-`uname -r`/kbuild
EXTRA=
SYSTIME=`which time`

SEQ=6
HIGHALLOC_ORDER=10
HIGHALLOC_COUNT=160

# Print usage of command
usage() {
  echo "bench-kbuild.sh (c) Mel Gorman 2005"
  echo This script times how long it takes to extract, configure a defconfig
  echo kernel and build it
  echo
  echo "Usage: bench-stresshighalloc.sh [options]"
  echo "    -t, --tar      Kernel source tree to use (default: $KERNEL_TAR)"
  echo "    -b, --build    Directory to build in (default: $BUILD_DIR)"
  echo "    -r, --result   Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra    String to append to result dir"
  echo "    -v, --vmr      VMRegress install directory (default: $VMREGRESS_DIR)"
  echo "    -o, --oprofile Collect oprofile information"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

# Parse command line arguements
ARGS=`getopt -o ht:b:r:v:e:ov: --long help,tar:,build:,result:,extra:,,oprofile,vmr: -n bench-kbuild.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
	-t|--tar)    export KERNEL_TAR="$2"; shift 2;;
	-b|--build)  export BUILD_DIR="$2"; shift 2;;
	-r|--result) export RESULT_DIR="$2"; shift 2;;
	-e|--extra)  export EXTRA="$2"; shift 2;;
	-v|--vmr)    export VMREGRESS_DIR="$2"; shift 2;;
	-o|--oprofile) export OPROFILE=1; shift 1;;
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done

if [ "$EXTRA" != "" ]; then
  export EXTRA=-$EXTRA
fi
export RESULT_DIR=$RESULT_DIR$EXTRA

# Setup results directory
RESULTS=$RESULT_DIR/log.txt
if [ -e $RESULT_DIR ]; then
  echo Results directory \($RESULT_DIR\) already exists
  echo Run with --help for options
  exit
fi

if [ ! -e "$BUILD_DIR" ]; then
  echo Build directory \($BUILD_DIR\) does not exist
  echo Run with --help for options
  exit
fi

if [ ! -e "$KERNEL_TAR" ]; then
  echo Kernel tar does not exist
  echo Run with --help for options
  exit
fi

if [ ! -e "$VMREGRESS_DIR" ]; then
  echo VMRegress does not exist
  echo Run with --help for options
  exit
fi

mkdir -p "$RESULT_DIR"
if [ ! -e "$RESULT_DIR" ]; then
  echo Failed to create results directory
  echo Run with --help for options
  exit
fi

if [ "$OPROFILE" != "" ]; then
  echo Purging /var/lib/oprofile
  rm -rf /var/lib/oprofile/*

  echo Starting oprofile
  opcontrol --setup --vmlinux=/boot/vmlinux-`uname -r`
  opcontrol --start
fi

# Get the tar zip flag
echo Using Kernel tar: $KERNEL_TAR
case $KERNEL_TAR in
*.tgz|*.gz)
        export ZIPFLAG=z
        ;;
*.bz2)
        export ZIPFLAG=j
        ;;
*)
        echo Do not recognised kernel tar type $KERNEL_TAR
        exit 1
        ;;
esac

echo KBuilt Timing Test $EXTRA > $RESULTS
echo Start date: `date`
echo Start date: `date` >> $RESULTS
uname -a >> $RESULTS
echo >> $RESULTS
if [ ! -e $RESULTS ]; then
  echo Unable to create results file
  exit
fi

cd $BUILD_DIR
echo Deleting old trees from last run
TREE=`tar -t${ZIPFLAG}f "$KERNEL_TAR" | grep ^linux- | head -1 | sed -e 's/\///'`
echo Deleting: "$TREE*"
rm $TREE* -rf

STARTTIME=`date +%s`
echo Expanding tree
if [ "$SYSTIME" != "" ]; then
  $SYSTIME -o extracttime.txt tar -${ZIPFLAG}xf "$KERNEL_TAR"
  mv extracttime.txt $BUILD_DIR/$TREE
else
  echo WARNING: time is not available
  tar -${ZIPFLAG}xf "$KERNEL_TAR"
fi

cd $BUILD_DIR/$TREE
EXTRACTTIME=`date +%s`
echo Extract time $(($EXTRACTTIME-$STARTTIME))

echo Making mrproper
make mrproper > /dev/null 2> /dev/null

echo Making config
make defconfig > /dev/null 2> /dev/null

echo Making tree
BUILDSTARTTIME=`date +%s`
if [ "$SYSTIME" != "" ]; then
  $SYSTIME -o buildtime.txt make > /dev/null 2> ../error-primary.txt
else
  make > /dev/null 2> ../error-primary.txt
fi

FINISHTIME=`date +%s`

EXTRACTTIME=$(($EXTRACTTIME-$STARTTIME))
BUILDTIME=$(($FINISHTIME-$BUILDSTARTTIME))
TOTALTIME=$(($FINISHTIME-$STARTTIME))
echo "Time taken to extract kernel:  $EXTRACTTIME" | tee -a $RESULTS
echo "Time taken to build kernel:    $BUILDTIME"   | tee -a $RESULTS
echo "Total time taken:              $TOTALTIME"   | tee -a $RESULTS

echo | tee -a $RESULTS
echo "Time breakdown during extract: `head -1 extracttime.txt`" | tee -a $RESULTS
echo "Time breakdown during build:   `head -1 buildtime.txt`" | tee -a $RESULTS

echo | tee -a $RESULTS
echo "IO and Faults during extract:  `tail -1 extracttime.txt`" | tee -a $RESULTS
echo "IO and Faults during build:    `tail -1 buildtime.txt`" | tee -a $RESULTS
echo | tee -a $RESULTS

END=`date +%s`
echo End date: `date`
echo Duration: $(($END-$STARTTIME))

echo >> $RESULTS
echo Test Completed >> $RESULTS
echo -------------- >> $RESULTS
echo End date: `date` >> $RESULTS
echo Duration: $(($END-$STARTTIME)) >> $RESULTS
echo Completed. Results: $RESULTS
