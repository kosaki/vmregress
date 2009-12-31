#!/bin/bash

VMREGRESS_DIR=/usr/src/vmregress
RESULT_DIR=$HOME/vmregressbench-`uname -r`/hotremove-capability
EXTRA=

SEQ=6
HIGHALLOC_ORDER=10
HIGHALLOC_COUNT=160

# Print usage of command
usage() {
  echo "bench-hotremovecapability.sh (c) Mel Gorman 2005"
  echo This script measures how capable the system is of offlining memory.
  echo It requires fairly extensive kernel-side support which may not be
  echo in the mainline kernel and still lurking in -mhp somewhere
  echo
  echo "Usage: bench-hotremovecapability.sh [options]"
  echo "    -r, --result   Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra    String to append to result dir"
  echo "    -v, --vmr      VMRegress install directory (default: $VMREGRESS_DIR)"
  echo "    -h, --help     Print this help message"
  echo
  exit 1
}

# Parse command line arguements
ARGS=`getopt -o hr:e:v: --long help,result:,extra:,vmr: -n bench-hotremovecapability.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
	-r|--result) export RESULT_DIR="$2"; shift 2;;
	-e|--extra)  export EXTRA="$2"; shift 2;;
	-v|--vmr)    export VMREGRESS_DIR="$2"; shift 2;;
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done

if [ "$EXTRA" != "" ]; then
  export EXTRA=-$EXTRA
fi
export RESULT_DIR=$RESULT_DIR$EXTRA
STARTTIME=`date +%s`

# Setup results directory
RESULTS=$RESULT_DIR/log.txt
if [ -e $RESULT_DIR ]; then
  echo Results directory \($RESULT_DIR\) already exists
  echo Run with --help for options
  exit 1
fi
mkdir -p "$RESULT_DIR"

echo Memory Hot-Remove Capability Test $EXTRA > $RESULTS
echo Start date: `date`
echo Start date: `date` >> $RESULTS
uname -a >> $RESULTS
echo >> $RESULTS
if [ ! -e $RESULTS ]; then
  echo Unable to create results file
  exit 1
fi
echo >> $RESULTS

# Check that there is a chance this will work
if [ ! -d /sys/devices/system/memory ]; then
  echo ERROR: /sys/devices/system/memory does not exist. Memory hotplug is not supported
  exit 1
fi

# Attempting to offline memory
echo Trying to offline memory
$VMREGRESS_DIR/bin/hotmemory_onoff offline | tee -a $RESULTS.tmp

# Make sure no errors occured
TEST=`grep "^Number of banks" $RESULTS.tmp`
if [ "$TEST" = "" ]; then
  echo ERROR: Offline attempt did not complete. Kernel probably Oopsed | tee -a $RESULTS
  rm $RESULTS.tmp
  exit 1
fi

# Record result
echo "Bank status after hot-remove attempt" >> $RESULTS
grep "^Number of banks" $RESULTS.tmp >> $RESULTS
rm $RESULTS.tmp

# Bring memory back online
$VMREGRESS_DIR/bin/hotmemory_onoff online

ENDTIME=`date +%s`
echo End date: `date`
echo Duration: $(($ENDTIME-$STARTTIME))

echo >> $RESULTS
echo Test Completed >> $RESULTS
echo -------------- >> $RESULTS
echo End date: `date` >> $RESULTS
echo Duration: $(($END-$STARTTIME)) >> $RESULTS
echo Completed. Results: $RESULTS
exit 0
