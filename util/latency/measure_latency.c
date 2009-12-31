#include <stdio.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "nanotime.h"

#define PAGE_SIZE 4096

struct stride_test {
	char *name;
	int stride;
	int preread;
	int write;
	int num_ops;
	int flushtlb;
};

struct stride_test test_list[] = {
	  /* name               stride          preread	write 		num_ops,	flushtlb*/
	{ "L1 Cache hit", 	1, 		1, 	0,		PAGE_SIZE,	0 },
	{ "L1 Cache miss", 	1, 		0, 	0,		PAGE_SIZE,	0 },
	{ "Zero read fault", 	PAGE_SIZE, 	0, 	0,		PAGE_SIZE,	0 },
	{ "Fault zero write", 	PAGE_SIZE, 	0, 	1,		PAGE_SIZE,	0 },
	{ "TLB hit 16", 	PAGE_SIZE, 	1, 	1,		16,		0 },
	{ "TLB hit 64", 	PAGE_SIZE, 	1, 	1,		64,		0 },
	{ "TLB hit 256", 	PAGE_SIZE, 	1, 	1,		256,		0 },
	{ "TLB miss", 		PAGE_SIZE, 	1, 	1,		PAGE_SIZE,	1 },
	{ "", -1, -1, -1, -1, -1}
};

static unsigned long read_stride(int fd, int stride, int num_ops, int preread, int write, int flushtlb) {
	unsigned long long st, et;
	unsigned long x, i;
	unsigned long *region, *ptr;
	unsigned long flags = PROT_READ;
	unsigned long long retval;
	i=0;
	if (write) flags |= PROT_WRITE;
	
	region = mmap(NULL, stride * num_ops * sizeof(unsigned long), 
			flags, 
			MAP_PRIVATE|MAP_ANONYMOUS,
			0,0);
	if (region == MAP_FAILED) {
		perror("Failed to map region");
		exit(-1);
	}

	/* Preread if requested */
	if (preread) {
		ptr = region;
		while (i++ < num_ops) {
			x = *ptr;
			if (write) *ptr = 1;
			ptr += stride;
		}
	}

	if (flushtlb) sleep(1);

	ptr = region;
	i=0;
	if (write) {
		st = rdtsc();
		while (++i < num_ops) {
			ptr += stride;
			*ptr = 1;
		}
		et = rdtsc();
	} else {
		st = rdtsc();
		while (++i < num_ops) {
			x = *ptr;
			ptr += stride;
		}
		et = rdtsc();
	}


	if (munmap(region, stride * num_ops * sizeof(unsigned long)) == -1) {
		perror("Failed to unmap region");
		exit(-1);
	}
	retval = (et-st) / num_ops;
	return retval;
}

static unsigned long measure_latency(unsigned long long cpms) {
	unsigned long long st, tt, et, lt;
	unsigned long long cycles = 0;
	unsigned long long *times;
	int iteration=0;
	int testnum=0;
	lt = 0;

	times = (unsigned long long *)malloc((sizeof(test_list) / sizeof(struct stride_test)) * sizeof(unsigned long long));

	while (test_list[testnum].stride != -1) {
		int seconds=1;
		while (seconds < 4) { 
			iteration = 0;
			cycles = 0;

			et = seconds * (cpms * 1000);
			st = rdtsc();
			tt = st;
			et += st;

			while (tt < et) {
				cycles += read_stride(0, test_list[testnum].stride,
							test_list[testnum].num_ops,
							test_list[testnum].preread,
							test_list[testnum].write,
							test_list[testnum].flushtlb);
			
				iteration++;
				tt = rdtsc();
			}

			cycles /= (double)iteration;

			if (seconds != 1) {
				printf("%-20s %6d %8d %10d %12f %24llu\n",
					test_list[testnum].name,
					test_list[testnum].stride,
					test_list[testnum].num_ops,
					iteration,
					cycles / (double)cpms,
					cycles);
			}

			seconds <<= 1;
		}
		times[testnum] = cycles;
		testnum++;
	}

	free(times);
	return 0;
}


int main() {
	unsigned long delay_tlbmiss;
	unsigned long long cpms;

	cpms = cycles_per_ms();

	printf("%-20s %6s %8s %10s %12s %24s\n",
			"Test Name",
			"Stride",
			"NumOps",
			"Iterations",
			"Time/ms",
			"Cycles/Iteration");

	printf("%-20s %6s %8s %10s %12s %24s\n",
			"---------",
			"------",
			"------",
			"----------",
			"-------",
			"----------------");

	delay_tlbmiss = measure_latency(cpms);
	printf("Report\n------\n");
	printf("Delay from TLB Miss: %lu clockcycles\n", delay_tlbmiss);

	exit(0);
		
}



