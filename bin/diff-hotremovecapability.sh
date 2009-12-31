#!/bin/bash
# Simple script to list the differences between two hotplug-remove-capability results

# Print usage of command
usage() {
  echo "diff-hotremovecapability.sh (c) Mel Gorman 2005"
  echo
  echo "Usage: diff-hotremovecapability.sh File1 File2"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

FILE1=$1
FILE2=$2

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
    FILE1=$FILE1/hotremove-capability/log.txt
  fi
fi

if [ "$FILE2" = "" ] || [ ! -e "$FILE2" ]; then
  echo "File2 ($FILE2) does not exist or was not specified"
  usage
fi

if [ -d "$FILE2" ]; then
  if [ -d "$FILE2/hotremove-capability" ]; then
    FILE2=$FILE2/hotremove-capability/log.txt
  fi
fi

IFS="
"

OFFLINE_1=`grep "Number of banks offline" "$FILE1" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`
OFFLINE_2=`grep "Number of banks offline" "$FILE2" | awk -F : '{print $2}' | awk '{print $1}' | tr -d " "`

NAME1=`head -5 "$FILE1" | grep ^Linux | awk '{print $3}'`
NAME2=`head -5 "$FILE2" | grep ^Linux | awk '{print $3}'`

WIDTH1=`echo $NAME1 | wc -c`
WIDTH2=`echo $NAME2 | wc -c`

printf "                                 %${WIDTH1}s %${WIDTH2}s\n" $NAME1 $NAME2
printf "Number of banks taken offline:   %${WIDTH1}s %${WIDTH2}s\n" $OFFLINE_1 $OFFLINE_2
