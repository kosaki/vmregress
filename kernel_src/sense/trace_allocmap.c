/*
 * trace_allocmap
 *
 * This module uses similar information to trace_alloc to plot a map of the
 * userspace/kernel allocations across all zones in the system. It can be used
 * to determine the spread of allocations through the system. This is important
 * as it is easier to reclaim userspace memory than kernel allocations so
 * kernel allocations mixed heavily with userspace will aggrevate fragmentation
 * problems.
 *
 * Mel Gorman 2004
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
MODULE_DESCRIPTION("Trace physical page allocation locations");
MODULE_LICENSE("GPL");

#define MODULENAME "trace_allocmap"
#define NUM_PROC_ENTRIES 1

/* Trace module description */
#define TRACE_PAGEALLOC 0
static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(TRACE_PAGEALLOC, MODULENAME, vmr_read_proc, vmr_write_proc)
};

/* Set if the kernel patch is applied. */
#ifdef TRACE_PAGE_ALLOCS

/* 
 * VMRegress allocation maps. Defined in mm/page_alloc.c
 */
extern unsigned int zonemap_sizes[MAX_NR_ZONES];
extern unsigned int *zone_maps[MAX_NR_ZONES];

/* Zone names */
static char *zone_names[MAX_NR_ZONES] = {
        "ZONE_DMA",
#ifdef ZONE_DMA32
	"ZONE_DMA32",
#endif
        "ZONE_NORMAL",          
        "ZONE_HIGHMEM" };

/* Duplicate of the additions in mm/page_alloc.c . Could be pushed to header
 * but aim is to have kernel patch minimally invasive */
#define VMRALLOC_FREE 0
#define VMRALLOC_USERRCLM 1
#define VMRALLOC_KERNRCLM 2
#define VMRALLOC_KERNNORCLM 3

int linewidth=70;

/**
 *
 * tracealloc_readproc - Get information for the proc entry and fill the buffer
 *
 */
void tracealloc_readproc(int procentry) {
	int i,j;
	int sizerequired = 0;
	int pagesrequired;
	
	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) {
		vmr_printk("PROC BUFFER EMPTY\n");
		return;
	}

	/* Make sure buffer is large enough */
	for (i=0; i<MAX_NR_ZONES; i++) {
		sizerequired += zonemap_sizes[i];
		sizerequired += zonemap_sizes[i]/linewidth;
	}
	sizerequired += 1024;
	if (sizerequired >= testinfo[procentry].procbuf_size) {
		/* Resize required */
		sizerequired -= testinfo[procentry].procbuf_size;
		pagesrequired = (sizerequired + PAGE_SIZE) / PAGE_SIZE;
		vmr_printk("Growing proc buffer by %d pages", pagesrequired);
		vmrproc_growbuffer(pagesrequired, &testinfo[procentry]);
	}

	/* Open the buffer for writing */
	vmrproc_openbuffer(&testinfo[procentry]);

	/* Cycle through all zones */
	for (i=0; i<MAX_NR_ZONES; i++) {
		printp("Node 0 Zone %s\n", zone_names[i]);

		/* Cycle through this map */
		for (j=0; j<zonemap_sizes[i]; j++) {
			int mask = zone_maps[i][j];
			
			/* Clear the higher bits where order is stored */
			mask &= 0x0000FFFF;
			switch (mask) {
				case VMRALLOC_FREE:
					printp(".");
					break;
				case VMRALLOC_USERRCLM:
					printp("u");
					break;
				case VMRALLOC_KERNNORCLM:
					printp("O");
					break;
				case VMRALLOC_KERNRCLM:
					printp("|");
					break;
				default:
					printp("?");
					break;
			}
			if ((j+1) % linewidth == 0) { printp("\n"); }
		}

		printp("\n");
	}
		
}

/**
 *
 * tracealloc_writeproc - Zero out the counters
 */
void tracealloc_writeproc(int *params, int argc, int procentry) {
	if (params != NULL && argc >= 1 && params[0] != 0) {
		vmr_printk("Setting print width to %d", params[0]);
		linewidth=params[0];
	}
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

void tracealloc_writeproc(int *params, int argc, int procentry) { return; }

#endif

#define VMR_READ_PROC_CALLBACK  tracealloc_readproc
#define NUMBER_PROC_WRITE_PARAMETERS 1
#define VMR_WRITE_CALLBACK tracealloc_writeproc
#include "../init/proc.c"
#include "../init/init.c"
