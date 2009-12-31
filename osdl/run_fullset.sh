#!/bin/bash
set -x
TESTDIR=./results
grep -q "Linux version 2.4" /proc/version
LINUX2_4=$?
if [ $LINUX2_4 -eq 0 ] ; then
	VMRBIN=./vmregress-0.7/bin/
else
	VMRBIN=./vmregress-0.7_2.5/bin/
fi
CPUS=`grep -c processor /proc/cpuinfo`

PATH=$PATH:$VMRBIN

echo ---------Making test directories-------
mkdir -p $TESTDIR/alloc
mkdir -p $TESTDIR/fault
mkdir -p $TESTDIR/data
mkdir -p $TESTDIR/mmap/read/25000
mkdir -p $TESTDIR/mmap/write/25000
if [ $CPUS -gt 2 ]; then
	mkdir -p $TESTDIR/mmap/write/50000
	mkdir -p $TESTDIR/mmap/read/50000
fi

echo ---------Generating Reference data-----
echo Generating 1000000 references over 25000 pages
generate_references.pl --size 25000 --references 1000000 --pattern smooth_sin --output $TESTDIR/data/smooth_sin_25000
echo Generating 1000000 references over 50000 pages
generate_references.pl --size 50000 --references 1000000 --pattern smooth_sin --output $TESTDIR/data/smooth_sin_50000

echo ---------Generating Filemap------------
dd if=/dev/zero of=$TESTDIR/data/filemap bs=4096 count=50000

echo ---------Running Alloc Tests-----------
echo o testfast
test_alloc.pl --testfast --output $TESTDIR/alloc/alloc_fast

echo o testlow
test_alloc.pl --testlow --output $TESTDIR/alloc/alloc_low

echo o testmin
test_alloc.pl --testmin --output $TESTDIR/alloc/alloc_min

echo o testzero
test_alloc.pl --testzero --output $TESTDIR/alloc/alloc_zero

echo ----------Running Fault Tests----------
echo o testfast
test_fault.pl --testfast --output $TESTDIR/fault/fault_fast

echo o testlow
test_fault.pl --testlow --output $TESTDIR/fault/fault_low

echo o testmin
test_fault.pl --testmin --output $TESTDIR/fault/fault_min

echo o testzero
test_fault.pl --testzero --output $TESTDIR/fault/fault_zero

echo -----------Running Anon Read Test------
echo o 25000
bench_mmap.pl --size 25000 --refdata $TESTDIR/data/smooth_sin_25000 --output $TESTDIR/mmap/read/25000/mapanon

echo -----------Running File Read Test------
echo o 25000
bench_mmap.pl --size 25000 --filemap $TESTDIR/data/filemap --refdata $TESTDIR/data/smooth_sin_25000 --output $TESTDIR/mmap/read/25000/mapfile

echo -----------Running Anon Write Test-----
echo o 25000
bench_mmap.pl --size 25000 --write --refdata $TESTDIR/data/smooth_sin_25000 --output $TESTDIR/mmap/write/25000/mapanon

echo -----------Running File Write Test-----
echo o 25000
bench_mmap.pl --size 25000 --write --filemap $TESTDIR/data/filemap --refdata $TESTDIR/data/smooth_sin_25000 --output $TESTDIR/mmap/write/25000/mapfile

if [ $CPUS -gt 2 ]; then
	echo -----------Running Large Anon Read Test------
 	echo o 50000
 	bench_mmap.pl --size 50000 --write --refdata $TESTDIR/data/smooth_sin_50000 --output $TESTDIR/mmap/write/50000/mapanon

	echo -----------Running Large File Read Test------
 	echo o 50000
 	bench_mmap.pl --size 50000 --filemap $TESTDIR/data/filemap --refdata $TESTDIR/data/smooth_sin_50000 --output $TESTDIR/mmap/read/50000/mapfile

	echo -----------Running Large Anon Write Test-----
 	echo o 50000
 	bench_mmap.pl --size 50000 --refdata $TESTDIR/data/smooth_sin_50000 --output $TESTDIR/mmap/read/50000/mapanon

	echo -----------Running File Write Test-----
 	echo o 50000
 	bench_mmap.pl --size 50000 --write --filemap $TESTDIR/data/filemap --refdata $TESTDIR/data/smooth_sin_50000 --output $TESTDIR/mmap/write/50000/mapfile

fi





