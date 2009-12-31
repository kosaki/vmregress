#!/bin/bash
# This script only performs the highalloc test, no other load is occuring
# at the same time unlike bench-plainhighalloc that sets up a large number
# of kernel compiles first

VMREGRESS_DIR=/usr/src/vmregress
KERNEL_TAR=/usr/src/linux-2.6.11.tar.gz
BUILD_DIR=/usr/src/bench-plainhighalloc-test
RESULT_DIR=/root/vmregressbench-`uname -r`/highalloc-plain
EXTRA=

SEQ=6
HIGHALLOC_ORDER=10
HIGHALLOC_COUNT=160

# Print usage of command
usage() {
  echo "bench-plainhighalloc.sh (c) Mel Gorman 2005"
  echo This script tries to allocate a number of highorder pages
  echo
  echo "Usage: bench-plainhighalloc.sh [options]"
  echo "    -r, --result   Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra    String to append to result dir"
  echo "    -v, --vmr      VMRegress install directory (default: $VMREGRESS_DIR)"
  echo "    -o, --oprofile Collect oprofile information"
  echo "    -s, --order    Size of the pages to allocate (default: $HIGHALLOC_ORDER)"
  echo "    -c, --count    Number of pages to allocate (default: $HIGHALLOC_COUNT)"
  echo "    -z, --highmem  User high memory if possible (default: no)"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

# Parse command line arguements
ARGS=`getopt -o hr:e:s:c:oz --long help,result:,extra:,order:,count:,oprofile,highmem -n bench-plainhighalloc.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
	-r|--result) export RESULT_DIR="$2"; shift 2;;
	-e|--extra)  export EXTRA="$2"; shift 2;;
	-v|--vmr)    export VMREGRESS_DIR="$2"; shift 2;;
	-o|--oprofile) export OPROFILE=1; shift 1;;
	-z|--highmem) export HIGHMEM="gfp_highuser=1"; shift 1;;
	-s|--order)  export HIGHALLOC_ORDER="$2"; shift 2;;
	-c|--count)  export HIGHALLOC_COUNT="$2"; shift 2;;
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

if [ ! -e "$VMREGRESS_DIR" ]; then
  echo VMRegress does not exist
  echo Run with --help for options
  exit
fi

insmod $VMREGRESS_DIR/kernel_src/core/vmregress_core.ko
insmod $VMREGRESS_DIR/kernel_src/core/buddyinfo.ko
insmod $VMREGRESS_DIR/kernel_src/sense/trace_allocmap.ko
insmod $VMREGRESS_DIR/kernel_src/test/highalloc.ko $HIGHMEM
if [ ! -e /proc/vmregress/test_highalloc ]; then
  echo High alloc proc test does not exist
  echo Run with --help for options
  exit
fi

START=`date +%s`
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


echo HighAlloc Plain Stress Test $EXTRA > $RESULTS
echo Start date: `date`
echo Start date: `date` >> $RESULTS
uname -a >> $RESULTS
if [ ! -e $RESULTS ]; then
  echo Unable to create results file
  exit
fi

echo Buddyinfo at start of highalloc test >> $RESULTS
echo ------------------------------------ >> $RESULTS
cat /proc/buddyinfo >> $RESULTS
echo >> $RESULTS
$VMREGRESS_DIR/bin/extfrag_stat.pl >> $RESULTS

STARTALLOC=`date +%s`
echo $HIGHALLOC_ORDER $HIGHALLOC_COUNT > /proc/vmregress/test_highalloc
ENDALLOC=`date +%s`

echo >> $RESULTS
echo HighAlloc Test Result >> $RESULTS
echo ---------------------------------------- >> $RESULTS
cat /proc/vmregress/test_highalloc >> $RESULTS
$VMREGRESS_DIR/bin/alloctimings_stat.pl >> $RESULTS
cat /proc/vmregress/test_highalloc
echo Duration alloctest: $(($ENDALLOC-$STARTALLOC)) >> $RESULTS

echo >> $RESULTS
echo Buddyinfo at end of highalloc test >> $RESULTS
echo --------------------------------- >> $RESULTS
cat /proc/buddyinfo >> $RESULTS
echo >> $RESULTS
$VMREGRESS_DIR/bin/extfrag_stat.pl >> $RESULTS

if [ "$OPROFILE" != "" ]; then
  echo Dumping oprofile information
  opcontrol --stop
  echo OProfile Result >> $RESULTS
  echo --------------- >> $RESULTS
  opreport -l --show-address >> $RESULTS
fi

END=`date +%s`
echo End date: `date`
echo Duration: $(($END-$START))

echo >> $RESULTS
echo Test Completed >> $RESULTS
echo -------------- >> $RESULTS
echo End date: `date` >> $RESULTS
echo Duration: $(($END-$START)) >> $RESULTS
echo Completed. Results: $RESULTS
