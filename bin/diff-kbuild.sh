#!/bin/bash
# Simple script to list the differences between two kbuild results

# Print usage of command
usage() {
  echo "diff-kbuild.sh (c) Mel Gorman 2005"
  echo "This script outputs the differences in operations/persecond of two"
  echo "sets of aim9 results"
  echo
  echo "Usage: diff-kbuild.sh File1 File2 [File3]"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

FILE1=$1
FILE2=$2
FILE3=$3

# Parse command line arguements
ARGS=`getopt -o h --long help -n bench-kbuild.sh -- "$@"`

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
  if [ -d "$FILE1/kbuild" ]; then
    FILE1=$FILE1/kbuild/log.txt
  fi
fi

if [ "$FILE2" = "" ] || [ ! -e "$FILE2" ]; then
  echo "File2 ($FILE2) does not exist or was not specified"
  usage
fi

if [ -d "$FILE2" ]; then
  if [ -d "$FILE2/kbuild" ]; then
    FILE2=$FILE2/kbuild/log.txt
  fi
fi

IFS="
"

EXTRACT1=`grep "extract kernel" "$FILE1" | awk -F : '{print $2}' | tr -d " "` 
EXTRACT2=`grep "extract kernel" "$FILE2" | awk -F : '{print $2}' | tr -d " "` 
BUILD1=`grep "build kernel" "$FILE1" | awk -F : '{print $2}' | tr -d " "`
BUILD2=`grep "build kernel" "$FILE2" | awk -F : '{print $2}' | tr -d " "`

NAME1=`head -5 "$FILE1" | grep ^Linux | awk '{print $3}'`
NAME2=`head -5 "$FILE2" | grep ^Linux | awk '{print $3}'`

WIDTH1=`echo $NAME1 | wc -c`
WIDTH2=`echo $NAME2 | wc -c`

if [ "$FILE3" != "" ]; then
  EXTRACT3=`grep "extract kernel" "$FILE3" | awk -F : '{print $2}' | tr -d " "` 
  BUILD3=`grep "build kernel" "$FILE3" | awk -F : '{print $2}' | tr -d " "`
  NAME3=`head -5 "$FILE3" | grep ^Linux | awk '{print $3}'`
  WIDTH3=`echo $NAME3 | wc -c`

  printf "                              %${WIDTH1}s %${WIDTH2}s %${WIDTH3}s\n" $NAME1 $NAME2 $NAME3
  printf "Time taken to extract kernel: %${WIDTH1}s %${WIDTH2}s %${WIDTH3}s\n" $EXTRACT1 $EXTRACT2 $EXTRACT3
  printf "Time taken to build kernel:   %${WIDTH1}s %${WIDTH2}s %${WIDTH3}s\n" $BUILD1 $BUILD2 $BUILD3
else
  printf "                              %${WIDTH1}s %${WIDTH2}s\n" $NAME1 $NAME2
  printf "Time taken to extract kernel: %${WIDTH1}s %${WIDTH2}s\n" $EXTRACT1 $EXTRACT2
  printf "Time taken to build kernel:   %${WIDTH1}s %${WIDTH2}s\n" $BUILD1 $BUILD2
fi
