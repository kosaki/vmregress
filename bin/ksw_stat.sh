#!/bin/bash
pid_sw=`ps -ef | awk '/kswapd0]$/{print $2}'`
pid_bnch=`ps -ef | awk '/perl.*bench_mmap.*0$/{print $2}'`
rm -f bench_stat.csv
st=`date +%s`
echo #Start time: $st
schedstat_avail=0
if [ -e /proc/$pid_sw/schedstat ]; then
  schedstat_avail=1
fi
s=0
awk 'BEGIN{printf("#time1 kswapd2")}{printf(" %s%d", $1, NR+2)}END{print ""}' /proc/vmstat
while (:) do
	if [ $schedstat_avail = 1 ]; then
		s=`awk '{print $1}' /proc/$pid_sw/schedstat`
	fi
	dt_abs=`date +%s`
	((dt_rel=dt_abs - st))
	((swr = s - sold))
	echo -n "$dt_rel $swr"
	awk '{printf(" %s", $2)}END{print ""}' /proc/vmstat
	sold=$s
	sleep 1;
done
