#!/bin/bash

VMREGRESS_DIR=/usr/src/vmregress
KERNEL_TAR=/usr/src/linux-2.6.11.tar.gz
BUILD_DIR=/usr/src/bench-stresshighalloc-test
RESULT_DIR=/root/vmregressbench-`uname -r`/hugetlb-capability
EXTRA=

SEQ=6
HIGHALLOC_ORDER=10
HIGHALLOC_COUNT=275
HUGETLB_ORDER=10
PAGESIZE=4096

# Print usage of command
usage() {
  echo "bench-hugepagecapability.sh (c) Mel Gorman 2005"
  echo This script takes a kernel source tree and performs the following
  echo test on it
  echo 1. Untar to $BUILD_DIR
  echo 2. Copy and start building the tree as each copy finishes. $SEQ copies are made and
  echo "    build with -j1"
  echo 3. Start building the main copy
  echo 5. After 1 minute, try allocate and pin $HIALLOC_COUNT 2\*\*10 pages
  echo 6. Immediately after, try again to see has reclaim made a difference
  echo 7. Wait 30 seconds
  echo 8. Kill all compiles and delete the source trees
  echo 9. Try and allocate 2\*\*10 pages again
  echo
  echo "Usage: bench-hugepagecapability.sh [options]"
  echo "    -t, --tar      Kernel source tree to use (default: $KERNEL_TAR)"
  echo "    -b, --build    Directory to build in (default: $BUILD_DIR)"
  echo "    -k, --kernels  Number of trees to compile (default: $SEQ)"
  echo "    -r, --result   Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra    String to append to result dir"
  echo "    -v, --vmr      VMRegress install directory (default: $VMREGRESS_DIR)"
  echo "    -o, --oprofile Collect oprofile information"
  echo "    -h, --help     Print this help message"
  echo
  exit 1
}

# Parse command line arguements
ARGS=`getopt -o ht:k:b:r:e:ov: --long help,kernels:,tar:,build:,result:,extra:,oprofile,vmr: -n bench-hugepagecapability.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
	-t|--tar)    export KERNEL_TAR="$2"; shift 2;;
	-b|--build)  export BUILD_DIR="$2"; shift 2;;
	-k|--kernels)export SEQ="$2"; shift 2;;
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

# Make sure the test can change the necessary values
echo 0 > /proc/sys/vm/nr_hugepages 2> /dev/null
if [ "$?" != "0" ]; then
  echo ERROR: Unable to write to /proc/sys/vm/nr_hugepages
  exit 1
fi

# Setup results directory
RESULTS=$RESULT_DIR/log.txt
if [ -e $RESULT_DIR ]; then
  echo Results directory \($RESULT_DIR\) already exists
  echo Run with --help for options
  exit 1
fi

if [ ! -e "$BUILD_DIR" ]; then
  echo Build directory \($BUILD_DIR\) does not exist
  echo Run with --help for options
  exit 1
fi

if [ ! -e "$KERNEL_TAR" ]; then
  echo Kernel tar does not exist
  echo Run with --help for options
  exit 1
fi

if [ ! -e "$VMREGRESS_DIR" ]; then
  echo VMRegress does not exist
  echo Run with --help for options
  exit 1
fi


echo Adjusting swappiness to 100
echo 100 > /proc/sys/vm/swappiness

START=`date +%s`
mkdir -p "$RESULT_DIR"
if [ ! -e "$RESULT_DIR" ]; then
  echo Failed to create results directory
  echo Run with --help for options
  exit 1
fi

if [ "$OPROFILE" != "" ]; then
  echo Purging /var/lib/oprofile
  rm -rf /var/lib/oprofile/*

  echo Starting oprofile
  opcontrol --setup --vmlinux=/boot/vmlinux-`uname -r`
  opcontrol --start
fi

echo Protecting from OOM killer
echo -17 > /proc/self/oom_adj

echo Working out number of huge pages in system
NUMPAGES=`free -b | grep Mem: | awk '{print $2/4096}'`
HUGEPAGES=`perl -e "print $NUMPAGES >> $HUGETLB_ORDER"`

echo HighAlloc Reasonable Stress Test $EXTRA > $RESULTS
echo Start date: `date`
echo Start date: `date` >> $RESULTS
uname -a >> $RESULTS
if [ ! -e $RESULTS ]; then
  echo Unable to create results file
  exit 1
fi

# Get the tar zip flag
echo Using kernel tar: $KERNEL_TAR
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

cd $BUILD_DIR
echo Deleting old trees from last run
TREE=`tar -t${ZIPFLAG}f "$KERNEL_TAR" | grep ^linux- | head -1 | sed -e 's/\///'`
if [ "$TREE" = "" ]; then
  echo ERROR: Could not determine build tree name from tar file
  exit 1
fi
echo Deleting: "$TREE*"
rm $TREE* -rf

echo Expanding tree: $BUILD_DIR
tar -${ZIPFLAG}xf $KERNEL_TAR

cd $BUILD_DIR/$TREE
make clean

for i in `seq 1 $SEQ`; do
  echo Copying and making copy-$i
  cd ..
  rm -rf $TREE-copy-$i
  cp -r $TREE $TREE-copy-$i
  if [ ! -d $TREE-copy-$i ]; then
    echo ERROR: Failed to make copy $TREE-copy-$i. Probably out of disk space
    exit 1
  fi
  cd $TREE-copy-$i
  make clean > /dev/null 2> /dev/null
  make defconfig > /dev/null 2> /dev/null
  make -j1 > /dev/null 2> ../error-$i.txt &
done

echo Making primary
cd ../$TREE
make defconfig > /dev/null 2> /dev/null
make -j1 > /dev/null 2> ../error-primary.txt &
cd ..

echo Allowing 1 minute to build
sleep 60

# Check for errors
for i in `seq 1 $SEQ` primary; do
  TEST=`grep -i error error-$i.txt`
  if [ "$TEST" != "" ]; then
    echo ERROR: An error was reported by compile job $i
    cat error-$i.txt
    exit 1
  fi
done

echo Checking HugeTLB capability for $HUGEPAGES huge pages
echo $HUGEPAGES > /proc/sys/vm/nr_hugepages
PAGES_PASS1=`cat /proc/sys/vm/nr_hugepages`
echo HugeTLB pages at pass 1: $PAGES_PASS1
echo 0 > /proc/sys/vm/nr_hugepages

echo Killing compile process
killall -KILL make
killall -KILL cc1
killall -KILL updatedb

mkdir $RESULT_DIR/mapfrag-before-delete
mkdir $RESULT_DIR/mapfrag-after-delete
cd $RESULT_DIR/mapfrag-before-delete

echo Recording stats
cat /proc/buddyinfo > buddyinfo
$VMREGRESS_DIR/bin/mapfrag_stat.pl
cp /tmp/*.plot .

echo Deleting trees and recording more stats
rm $BUILD_DIR/$TREE* -rf
cd $RESULT_DIR/mapfrag-after-delete
cat /proc/buddyinfo > buddyinfo

echo $HUGEPAGES > /proc/sys/vm/nr_hugepages
PAGES_BEFOREDD=`cat /proc/sys/vm/nr_hugepages`
echo HugeTLB pages before dd: $PAGES_BEFOREDD
echo 0 > /proc/sys/vm/nr_hugepages

echo DDing large file and deleting to flush buffer caches
size=`free -m | grep Mem: | awk '{print $2}'`
dd if=/dev/zero of=$BUILD_DIR/largefile ibs=1048576 count=$size
cat $BUILD_DIR/largefile > /dev/null
rm $BUILD_DIR/largefile

echo $HUGEPAGES > /proc/sys/vm/nr_hugepages
PAGES_AFTERDD=`cat /proc/sys/vm/nr_hugepages`
echo HugeTLB pages after dd: $PAGES_AFTERDD
echo 0 > /proc/sys/vm/nr_hugepages

echo HugeTLB Capability Results | tee -a $RESULTS
echo -------------------------- | tee -a $RESULTS
echo "Number huge pages before pass 1:                   $PAGES_PASS1" | tee -a $RESULTS
echo "Number huge pages at rest before dd of large file: $PAGES_BEFOREDD" | tee -a $RESULTS
echo "Number huge pages at rest after  dd of large file: $PAGES_AFTERDD" | tee -a $RESULTS

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
exit 0
