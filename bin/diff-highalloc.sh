#!/bin/bash
# Simple script to list the differences between two aim 9 results



# Print usage of command
usage() {
  echo "diff-highalloc.sh (c) Mel Gorman 2005"
  echo "Thisscripts makes a side by side comparison between two highalloc"
  echo "stress reports"
  echo
  echo "Usage: diff-highalloc.sh File1 File2"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

FILE1=$1
FILE2=$2
FILE3=$3

# Parse command line arguements
ARGS=`getopt -o h --long help -n bench-highalloc.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done

if [ -d "$FILE1" ]; then
  if [ -d "$FILE1/highalloc-heavy" ]; then
    FILE1=$FILE1/highalloc-heavy/log.txt
  fi
fi

if [ "$FILE1" = "" ] || [ ! -e "$FILE1" ]; then
  echo "File1 ($FILE1) does not exist or was not specified"
  usage
fi

if [ -d "$FILE2" ]; then
  if [ -d "$FILE2/highalloc-heavy" ]; then
    FILE2=$FILE2/highalloc-heavy/log.txt
  fi
fi

if [ "$FILE2" = "" ] || [ ! -e "$FILE2" ]; then
  echo "File2 ($FILE2) does not exist or was not specified"
  usage
fi

if [ "$FILE2" != "" ] && [ ! -e "$FILE2" ]; then
  echo "File3 ($FILE3) was specified but does not exist"
  usage
fi



die() {
  echo "$@"
  exit
}
TEMP=`mktemp`
if [ "$TEMP" = "" ] || [ ! -e "$TEMP" ]; then
  die Failed to create temporary file
fi
rm $TEMP
mkdir $TEMP

NAME1=`head -5 $FILE1 | grep ^Linux | awk '{print $3}'`
NAME2=`head -5 $FILE2 | grep ^Linux | awk '{print $3}'`
WIDTH1=`echo $NAME1 | wc -c`
WIDTH2=`echo $NAME2 | wc -c`

SET=0
while [ "$SET" != "3" ]; do
  SET=$(($SET+1))
  
  grep ^HighAlloc $FILE1 | grep Results | head -$SET | tail -1
  START1=`grep -n ^HighAlloc $FILE1 | grep Results | head -$SET | tail -1 | awk -F : '{print $1}'`
  START2=`grep -n ^HighAlloc $FILE2 | grep Results | head -$SET | tail -1 | awk -F : '{print $1}'`

  END1=$(($START1+12))
  END2=$(($START2+12))
  START1=$(($START1+2))
  START2=$(($START2+2))

  # Extract the two reports
  head -$END1 $FILE1 | tail -11 | grep -v "Test completed" > $TEMP/report1
  head -$END2 $FILE2 | tail -11 | grep -v "Test completed" > $TEMP/report2

  # Handle file3 in the same way if specified
  if [ "$FILE3" != "" ]; then
    NAME3=`head -5 $FILE3 | grep ^Linux | awk '{print $3}'`
    WIDTH3=%`echo $NAME3 | wc -c`s
    START3=`grep -n ^HighAlloc $FILE3 | grep Results | head -$SET | tail -1 | awk -F : '{print $1}'`
    END3=$(($START3+12))
    START3=$(($START3+2))
    head -$END3 $FILE3 | tail -11 | grep -v "Test completed" > $TEMP/report3
  fi

  # Print the report header
  printf "%-25s %${WIDTH1}s %${WIDTH2}s $WIDTH3\n" "" $NAME1 $NAME2 $NAME3
  IFS="
"
  for LINE in `cat $TEMP/report1`; do
    FIELD=`echo $LINE | awk -F : '{print $1}'`
    RES1=`echo $LINE | awk -F : '{print $2}' | sed -e 's/\\s//g'`
    RES2=`cat $TEMP/report2 | grep "$FIELD" | awk -F : '{print $2}' | sed -e 's/\\s//g'`
    if [ -e $TEMP/report3 ]; then
      RES3=`cat $TEMP/report3 | grep "$FIELD" | awk -F : '{print $2}' | sed -e 's/\\s//g'`
    fi
    
    printf "%-25s %${WIDTH1}s %${WIDTH2}s $WIDTH3\n" "$FIELD" "$RES1" "$RES2" $RES3
  done
done

