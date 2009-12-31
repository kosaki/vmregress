#!/bin/bash
# Simple script to list the differences between two hugepagecapability results

# Print usage of command
usage() {
  echo "diff-hugepagecapability.sh (c) Mel Gorman 2005"
  echo
  echo "Usage: diff-hugepagecapability.sh File1 File2"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

FILE1=$1
FILE2=$2
FILE3=$3

# Parse command line arguements
ARGS=`getopt -o h --long help -n bench-hugepagecapability.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done

if [ "$FILE1" = "" ] || [ ! -e "$FILE1" ]; then
  echo "File1 ($FILE1) does not exist or was not specified"
  usage
fi

if [ -d "$FILE1" ]; then
  if [ -d "$FILE1/hugetlb-capability" ]; then
    FILE1=$FILE1/hugetlb-capability/log.txt
  fi
fi

if [ "$FILE2" = "" ] || [ ! -e "$FILE2" ]; then
  echo "File2 ($FILE2) does not exist or was not specified"
  usage
fi

if [ -d "$FILE2" ]; then
  if [ -d "$FILE2/hugetlb-capability" ]; then
    FILE2=$FILE2/hugetlb-capability/log.txt
  fi
fi

IFS="
"

PASS1_1=`grep "Number huge pages before pass 1" "$FILE1" | awk -F : '{print $2}' | tr -d " "`
PASS1_2=`grep "Number huge pages before pass 1" "$FILE2" | awk -F : '{print $2}' | tr -d " "`
BEFOREDD_1=`grep "Number huge pages at rest before dd of large file" "$FILE1" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`
BEFOREDD_2=`grep "Number huge pages at rest before dd of large file" "$FILE2" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`
AFTERDD_1=`grep "Number huge pages at rest after  dd of large file" "$FILE1" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`
AFTERDD_2=`grep "Number huge pages at rest after  dd of large file" "$FILE2" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`

NAME1=`head -5 "$FILE1" | grep ^Linux | awk '{print $3}'`
NAME2=`head -5 "$FILE2" | grep ^Linux | awk '{print $3}'`

WIDTH1=`echo $NAME1 | wc -c`
WIDTH2=`echo $NAME2 | wc -c`

if [ "$FILE3" != "" ]; then
  PASS1_3=`grep "Number huge pages before pass 1" "$FILE3" | awk -F : '{print $2}' | tr -d " "`
  BEFOREDD_3=`grep "Number huge pages at rest before dd of large file" "$FILE3" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`
  AFTERDD_3=`grep "Number huge pages at rest after  dd of large file" "$FILE3" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`
  NAME3=`head -5 "$FILE3" | grep ^Linux | awk '{print $3}'`
  WIDTH3=`echo $NAME3 | wc -c`

  printf "                                 %${WIDTH1}s %${WIDTH2}s %${WIDTH3}s\n" $NAME1 $NAME2 $NAME3
  printf "During compile:                  %${WIDTH1}s %${WIDTH2}s %${WIDTH3}s\n" $PASS1_1 $PASS1_2 $PASS1_3
  printf "At rest before dd of large file: %${WIDTH1}s %${WIDTH2}s %${WIDTH3}s\n" $BEFOREDD_1 $BEFOREDD_2 $BEFOREDD_3
  printf "At rest after  dd of large file: %${WIDTH1}s %${WIDTH2}s %${WIDTH3}s\n" $AFTERDD_1 $AFTERDD_2 $AFTERDD_3
else

  printf "                                 %${WIDTH1}s %${WIDTH2}s\n" $NAME1 $NAME2
  printf "During compile:                  %${WIDTH1}s %${WIDTH2}s\n" $PASS1_1 $PASS1_2
  printf "At rest before dd of large file: %${WIDTH1}s %${WIDTH2}s\n" $BEFOREDD_1 $BEFOREDD_2
  printf "At rest after  dd of large file: %${WIDTH1}s %${WIDTH2}s\n" $AFTERDD_1 $AFTERDD_2
fi
