/*
 * trace_alloccount
 *
 * This module is used for tracing physical page allocations. The objective is
 * to record the number of allocations of each order for either userspace of
 * kernel space allocations. This is intended to help decide what sort of
 * physical page allocation algorithm should be used
 *
 * Mel Gorman 2002
 */

#include <linux/config.h>
#include <linux/kernel.h>
#include <linux/module.h>

/* Module specific */
#include <linux/mmzone.h>
#include <linux/fs.h>
#include <linux/proc_fs.h>
#include <linux/sched.h>
#include <linux/mm.h>
#include <asm/uaccess.h>
#include <vmregress_core.h>
#include <procprint.h>
#include <vmr_mmzone.h>

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Trace physical page allocations");
MODULE_LICENSE("GPL");

#define MODULENAME "trace_alloccount"
#define NUM_PROC_ENTRIES 1

/* Trace module description */
#define TRACE_PAGEALLOC 0
static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(TRACE_PAGEALLOC, MODULENAME, vmr_read_proc, vmr_write_proc)
};

/* Set if the kernel patch is applied. */
#ifdef TRACE_PAGE_ALLOCS

/* 
 * VM Regress allocation counters. These are kept in mm/page_alloc.c and
 * exported
 */
extern unsigned long kernrclm_allocs[MAX_ORDER];
extern unsigned long userrclm_allocs[MAX_ORDER];
extern unsigned long kernnorclm_allocs[MAX_ORDER];
extern unsigned long kernrclm_free[MAX_ORDER];
extern unsigned long userrclm_free[MAX_ORDER];
extern unsigned long kernnorclm_free[MAX_ORDER];

/**
 *
 * tracealloc_readproc - Get information for the proc entry and fill the buffer
 *
 */
void tracealloc_readproc(int procentry) {
	int order;
	unsigned long net[MAX_ORDER];
	memset(net, 0, sizeof(net));
	
	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) {
		vmr_printk("PROC BUFFER EMPTY\n");
		return;
	}

	vmrproc_openbuffer(&testinfo[procentry]);
	printp("Allocations\n");
	printp("-----------\n");
	printp("KernNoRclm ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", kernnorclm_allocs[order]);
		net[order] += kernnorclm_allocs[order];
	}
	printp("\n");
		
	
	printp("KernRclm   ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", kernrclm_allocs[order]);
		net[order] += kernrclm_allocs[order];
	}
	printp("\n");

	printp("UserRclm   ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", userrclm_allocs[order]);
		net[order] += userrclm_allocs[order];
	}
	printp("\n");
	printp("Total      ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", net[order]);
	}

	printp("\n");
	printp("\n");

	memset(net, 0, sizeof(net));
	printp("Frees\n");
	printp("-----\n");
	printp("KernNoRclm ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", kernnorclm_free[order]);
		net[order] += kernnorclm_free[order];
	}
	printp("\n");
		
	
	printp("KernRclm   ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", kernrclm_free[order]);
		net[order] += kernrclm_free[order];
	}
	printp("\n");

	printp("UserRclm   ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", userrclm_free[order]);
		net[order] += userrclm_free[order];
	}

	printp("\n");
	printp("Total      ");
	for (order=0; order<MAX_ORDER; order++) {
		printp("%8lu ", net[order]);
	}

	printp("\n");

}

/**
 *
 * tracealloc_writeproc - Zero out the counters
 */
int tracealloc_writeproc(int *params, int argc, int procentry) {
	printk("Resetting counters\n");
	memset(kernnorclm_allocs, 0, sizeof(kernnorclm_allocs));
	memset(kernrclm_allocs, 0, sizeof(kernrclm_allocs));
	memset(userrclm_allocs, 0, sizeof(userrclm_allocs));

	memset(kernnorclm_free, 0, sizeof(kernnorclm_free));
	memset(kernrclm_free, 0, sizeof(kernrclm_free));
	memset(userrclm_free, 0, sizeof(userrclm_free));
	return 0;
}

#else

/* 
 * These print out simple messages to show the kernel patch was not applied 
 */
void tracealloc_readproc(int procentry) {
	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) {
		vmr_printk("PROC BUFFER EMPTY\n");
		return;
	}

	vmrproc_openbuffer(&testinfo[procentry]);

	printp("Kernel patch trace_pagealloc.diff needs to be applied from kernel_patches/ directory\n");
}

int tracealloc_writeproc(int *params, int argc, int procentry) {
	return 0;
}

#endif

int vmr_sanity(int *params, int noread) { return 1; }

#define VMR_READ_PROC_CALLBACK  tracealloc_readproc
#define NUMBER_PROC_WRITE_PARAMETERS 1
#define CHECK_PROC_PARAMETERS vmr_sanity
#define VMR_WRITE_CALLBACK tracealloc_writeproc

#include "../init/proc.c"
#include "../init/init.c"
