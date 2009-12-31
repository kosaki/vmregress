#!/bin/bash
# Simple script to list the differences between two aim 9 results



# Print usage of command
usage() {
  echo "diff-aim9.sh (c) Mel Gorman 2005"
  echo "This script outputs the differences in operations/persecond of two"
  echo "sets of aim9 results"
  echo
  echo "Usage: diff-aim9.sh File1 File2"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

FILE1=$1
FILE2=$2
FILE3=$3

# Parse command line arguements
ARGS=`getopt -o h --long help -n bench-aim9.sh -- "$@"`

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
  if [ -d "$FILE1/aim9" ]; then
    FILE1=$FILE1/aim9/log.txt
  fi
fi

if [ "$FILE2" = "" ] || [ ! -e "$FILE2" ]; then
  echo "File2 ($FILE2) does not exist or was not specified"
  usage
fi

if [ -d "$FILE2" ]; then
  if [ -d "$FILE2/aim9" ]; then
    FILE2=$FILE2/aim9/log.txt
  fi
fi

NAME1=`head -5 "$FILE1" | grep ^Linux | awk '{print $3}'`
NAME2=`head -5 "$FILE2" | grep ^Linux | awk '{print $3}'`

WIDTH1=`echo $NAME1 | wc -c`
WIDTH2=`echo $NAME2 | wc -c`

if [ "$FILE3" != "" ]; then
  NAME3=`head -5 "$FILE3" | grep ^Linux | awk '{print $3}'`
  WIDTH3=`echo $NAME3 | wc -c`
  echo "                 $NAME1  $NAME2                    $NAME3"
else
  echo "                 $NAME1  $NAME2"
fi

IFS="
"
for LINE in `cat "$FILE1" | egrep '^[ ]*[0-9]+[ ][a-z]*[_|-].*' | grep "/second"`; do
  NUM=`echo $LINE | awk '{print $1}'`
  TEST=`echo $LINE | awk '{print $2}' | sed -e 's/ //g'`
  RESULTA=`echo $LINE | head -1 | awk '{print $6}'`
  DESC=`echo $LINE | awk '{print $7" "$8" "$9" "$10" "$11}' | sed -e 's///' | sed -e 's/ *$//'`
  RESULTB=`grep $TEST "$FILE2" | head -1 | awk '{print $6}'`
  if [ "$FILE3" != "" ]; then
    RESULTC=`grep $TEST "$FILE3" | head -1 | awk '{print $6}'`

    DIFFA=`perl -e "print $RESULTB-$RESULTA"`
    PDIFFA=`perl -e "print $DIFFA/$RESULTA * 100"`
    DIFFB=`perl -e "print $RESULTC-$RESULTA"`
    PDIFFB=`perl -e "print $DIFFB/$RESULTA * 100"`
    printf "%2d %-12s %${WIDTH1}.2f %${WIDTH2}.2f %10.2f %5.2f%% %${WIDTH3}.2f %10.2f %5.2f%% %s\n" $NUM $TEST $RESULTA $RESULTB $DIFFA $PDIFFA $RESULTC $DIFFB $PDIFFB $DESC

  else 
    if [ "$RESULTA" != "" ] && [ "$RESULTB" != "" ]; then
      DIFF=`perl -e "print $RESULTB-$RESULTA"`
      PDIFF=`perl -e "print $DIFF/$RESULTA * 100"`
      printf "%2d %-12s %${WIDTH1}.2f %${WIDTH2}.2f %10.2f %5.2f%% %s\n" $NUM $TEST $RESULTA $RESULTB $DIFF $PDIFF $DESC
    fi
  fi
  
done

