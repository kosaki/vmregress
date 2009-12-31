/*
 * kvirtual
 *
 * This module will dump out what the linear address space looks like
 * to the kernel. The information is pretty static but serves as a 
 * useful illustration when trying to see where areas are located
 *
 * Mel Gorman 2002
 */

#include <linux/config.h>
#include <linux/fs.h>
#include <linux/types.h>
#include <linux/proc_fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <asm/uaccess.h>

/* Module specific */
#include <vmregress_core.h>
#include <procprint.h>
#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/highmem.h>

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Prints out the kernel virtual memory area");
MODULE_LICENSE("GPL");

/* Kernel internal data structures */
#include <internal.h>

#define MODULENAME "sense_kvirtual"
#define NUM_PROC_ENTRIES 1

/* Sense modules */
#define SENSE_STRUCTS 0
static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(SENSE_STRUCTS, MODULENAME, vmr_read_proc, NULL)
};

/**
 *
 * kvirtual_getproc - Get information for the proc entry and fill the buffer
 *
 * This is called at proc read to print out all the available information
 */
void kvirtual_getproc(int procentry) {
	
	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) {
		vmr_printk("PROC BUFFER EMPTY\n");
		return;
	}

	vmrproc_openbuffer(&testinfo[procentry]);

	/* Print out static information */
	printp("Linear Address Space\n");
	printp("--------------------\n");

#define K(x) (x)/(1024)
#define M(x) (x)/(1048576)

	printp("o Process address space: 0x00000000 - 0x%lX (%4lu MB)\n", PAGE_OFFSET, M((unsigned long)PAGE_OFFSET));
	printp("o Kernel image reserve:  0x%lX + 2 * PGD    (%4lu MB)\n", PAGE_OFFSET+0x00800000, M((unsigned long)0x00800000));
#ifndef CONFIG_NUMA
	printp("o Physical memory map:   0x%lX - 0x%lX (%4lu MB)\n", (unsigned long)mem_map, (unsigned long)high_memory, M((unsigned long)high_memory-(unsigned long)mem_map));
#endif
#ifdef VMALLOC_OFFSET
	printp("o VMalloc Gap:           0x%lX - 0x%lX (%4lu MB)\n", (unsigned long)high_memory, VMALLOC_START, M((unsigned long)VMALLOC_OFFSET));
	printp("o VMalloc address space: 0x%lX - 0x%lX (%4lu MB)\n", VMALLOC_START, VMALLOC_END, M(VMALLOC_END - VMALLOC_START) );
	printp("o 2 Page Gap:            0x%lX - 0x%lX (%4lu KB)\n", VMALLOC_END, VMALLOC_END + 2 * PAGE_SIZE, K((2 * PAGE_SIZE)));
#endif
#if CONFIG_HIGHMEM
	printp("o PKMap address space:   0x%lX - 0x%lX (%4lu MB)\n", PKMAP_BASE, PKMAP_BASE + (LAST_PKMAP-2) * PAGE_SIZE, M((LAST_PKMAP-2) * PAGE_SIZE));
	printp("o Unused pkmap space:    0x%lX - 0x%lX (%4lu MB)\n", PKMAP_BASE + (LAST_PKMAP-2) * PAGE_SIZE, FIXADDR_START, M((FIXADDR_START - (PKMAP_BASE + (LAST_PKMAP-2) * PAGE_SIZE))));
#endif
#ifdef FIXADDR_START
	printp("o Fixed virtual mapping: 0x%lX - 0x%lX (%4lu KB)\n", FIXADDR_START, FIXADDR_TOP, K(((unsigned long)__FIXADDR_SIZE)));
	printp("o 2 unused pages:        0x%lX - 0x%lX (%4lu KB)\n", FIXADDR_TOP, (unsigned long)0xFFFFFFFF, K(0xFFFFFFFF - FIXADDR_TOP + 1));
#endif
	printp("\n");

	return;
}

#define VMR_READ_PROC_CALLBACK kvirtual_getproc
#include "../init/proc.c"
#include "../init/init.c"
