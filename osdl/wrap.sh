#!/bin/sh
set -x

# Wrapper script for the VM Regress tests
# Copyright (C) 2002 Open Source Development Lab, Inc.
# Taken from work done by Mel Gorman 
# MSc Student, University of Limerick
# http://www.csn.ul.ie/~mel
#
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

MYHOME=`pwd`
# Find the kernel
if [ -d ../linux ]; then
	cd ../linux
	KERNDIR=`pwd`
	export KERNDIR
	cd $MYHOME
else		
	echo "Kernel directory not found"
	exit -1
fi

# test if we're running 2.4 or 2.5 kernel
grep -q "Linux version 2.4" /proc/version
LINUX2_4=$?

# Fail immediately if kernel hasn't been patched.
grep -q "EXPORT_SYMBOL(pgdat_list)" $KERNDIR/kernel/ksyms.c
KERNEL_PATCHED=$?
if [ $KERNEL_PATCHED -ne 0 ] ; then
	echo "KERNEL PATCH NOT APPLIED, NOT ALL TESTS WILL RUN"
	exit -1
fi

# get the bits
IMAGE="ImageMagick-5.4.8-2"
PERLTIME="Time-HiRes-1.35"
PROCPS="procps-2.0.11"
if [ $LINUX2_4 -eq 0 ]; then
	VMBITS="vmregress-0.7"
else
	VMBITS="vmregress-0.7_2.5"
fi
cd $MYHOME
if [ ! -d results ]; then mkdir results; fi
RESDIR=$MYHOME/results; export RESDIR

# Wget section --------------------------------
	wget -q http://stp/data/vm_regress/${IMAGE}.tar.bz2
	wget -q http://stp/data/vm_regress/${PERLTIME}.tar.gz
#	wget -q http://stp/data/vm_regress/${VMBITS}.tar.gz
#	wget -q http://stp.data/vm_regress/${PROCPS}.tar.bz2
	wget -q http://www.osdl.org/archive/dmo/VMREGRESS/${PROCPS}.tar.bz2
	wget -q http://www.osdl.org/archive/dmo/VMREGRESS/${VMBITS}.tar.gz
# install the Timers 
if [ -f ${PERLTIME}.tar.gz ]; then
	tar xzf ${PERLTIME}.tar.gz
	cd $PERLTIME
	perl Makefile.PL
	make
	make install
	cd $MYHOME
else
	echo "Perl timers not found"
	exit -1
fi
# install ImageMagick
if [ -f ${IMAGE}.tar.bz2 ]; then
	tar xjf ${IMAGE}.tar.bz2
	cd ./ImageMagick-5.4.8
	./configure 
	make
	make install
	cd $MYHOME
else
	echo "ImageMagick not found"
	exit -1
fi

#install vmstat?
if [ $LINUX2_4 ] ; then
	if [ -f ${PROCPS}.tar.bz2 ] ; then
		bunzip2 ${PROCPS}.tar.bz2
		tar xjf ${PROCPS}.tar
		cd ./procps-2.0.11
		make
		make install
		ldconfig -v
		cd $MYHOME
	else
		echo "procps not found"
		exit -1
	fi
fi

# unpack the bits 
if [ -f ${VMBITS}.tar.gz ]; then	
	tar xzf ${VMBITS}.tar.gz
	cd ${VMBITS}
	./configure --with-linux=$KERNDIR
	if [ $LINUX2_4 -eq 0 ]; then
		make 
		make install
		DPRES=`depmod -a` 
		if [ $? -ne 0 ];then 
			echo "vm_regress modules problem: $DPRES"
			exit -1
		fi
	else
		cd $KERNDIR
		make SUBDIRS=$MYHOME/${VMBITS} modules
		make SUBDIRS=$MYHOME/${VMBITS} modules_install
	fi
	cd $MYHOME
else
	echo "vm regress not found"
	exit -1
fi

#Okay now we run the test. 
# simple for now
./run_fullset.sh

# Now we must build a results page
# For now, this is going to be very quick and dirty
echo "<html> <head> <title>VM Regression Test</title></head><body> " > $MYHOME/index.html
echo "<p><h1>VM Regression Test</h1>" >>  $MYHOME/index.html
echo "<br><b>Written by Mel Gorman      (mel@csn.ul.ie)<b><br>" >> $MYHOME/index.html
echo "<h2>List of Results</h2><br>" >> $MYHOME/index.html
cd $MYHOME
for i in `find ./results -name '*.html'`
do
	echo "<a href="$i">$i</a><br>" >> $MYHOME/index.html
	
done
printf "<ul>Other Information<p>" >> $MYHOME/index.html
printf "<li><a href=\"environment/machine_info\">Summary Information on Machine</a></li>\n"  >> $MYHOME/index.html
printf "<li><a href=\"environment/\">System Environment Documentation</a></li>\n"  >> $MYHOME/index.html
printf "<li><a href=\"COPYING\">Results Copyright License</a></li> </ul> <p> <br> \n"  >> $MYHOME/index.html
echo "<pre>" >> $MYHOME/index.html
	
cat ${VMBITS}/docs/vmregress.txt >> $MYHOME/index.html
echo "</pre>" >> $MYHOME/index.html

echo "</body></html>" >> $MYHOME/index.html

exit 0




