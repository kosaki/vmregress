/*
 * pagemap - Print out all address space page information
 *
 * This module will cycle through all address spaces in the current process 
 * and print out an encoded page map which determines which pages are present
 * and which are free. See pagetable.c for details on the encoding
 *
 * Mel Gorman 2002
 */

#include <linux/version.h>
#include <linux/config.h>
#include <linux/fs.h>
#include <linux/types.h>
#include <linux/proc_fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/sched.h>
#include <linux/mm.h>
#include <linux/spinlock.h>
#include <linux/highmem.h>

/* Module specific */
#include <vmregress_core.h>
#include <procprint.h>
#include <pagetable.h>

/* Module declarations */
#define MODULENAME "pagemap"

/* Test names */ 
#define SENSE_PAGEMAP 0

/* Proc functions */
static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(SENSE_PAGEMAP, MODULENAME "_read", vmr_read_proc, NULL),
};

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Print out all pages present/swapped for a process");
MODULE_LICENSE("GPL");

/**
 *
 * pagemap_runtest - Run a test function
 * @procentry: Proc buffer to write to
 * @argument: Parameters of the test
 *
 * Returns
 * 0  on success
 * -1 on failure
 *
 */
int pagemap_runtest(int procentry) {
	struct mm_struct *mm;		/* mm struct of current */
	struct vm_area_struct *start;	/* Starting vma */
	struct vm_area_struct *vma;	/* VMA been dumped */
	unsigned long sched_count;	/* Schedule count */

	/* Check we have an MM (pretty much impossible not to) */
	if (!current->mm) return 0;

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) BUG();
	vmrproc_openbuffer(&testinfo[procentry]);

	mm = current->mm;

	/* Print header */
	printp("Process Page Address Test Results.\n\n");
	printp("o PID:       %d\n",  current->pid);
	printp("o VMA count: %d\n",  mm->map_count);
	printp("o RSS:       Unknown, need to update tool to calculate\n");
	printp("o Total VM:  %lu\n", mm->total_vm);
	printp("\n");

	/* Get the first area */
	start = vma = mm->mmap;

	do {
		/* Print out the address map */
		vmr_printmap(current->mm, 
			     vma->vm_start, 
			     vma->vm_end - vma->vm_start,
			     &sched_count,
			     &testinfo[procentry]);

		/* Move to next VMA */
		vma = vma->vm_next;
	} while (vma && vma != start); 

	return 0;
}

#define NUM_PROC_ENTRIES 1
#define VMR_READ_PROC_CALLBACK pagemap_runtest
#include "../init/proc.c"
#include "../init/init.c"
