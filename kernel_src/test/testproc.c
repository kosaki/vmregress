/*
 * testproc
 *
 * This module tests the proc interface to make sure it can read and write 
 * data correctly. The principle aim is to make sure more than 4096k of 
 * data can be read easily via the interface. The second aim is to provide 
 * a template module for other modules to use.
 * Most of this can be copy and pasted for use elsewhere
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

/* Module specific */
#include <linux/sched.h>
#include <linux/vmalloc.h>
#include <asm/uaccess.h>
#include <asm/current.h>
#include <vmregress_core.h>
#include <procprint.h>

/* Name of the module that appears on printk messages */
#define MODULENAME "testproc"
#define NUM_PROC_ENTRIES 1
#define PROCFOOTER "\nProc Test Completed on %u pages...\n"

static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(0, MODULENAME, vmr_read_proc, vmr_write_proc)
};

/* Module Register */
MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Test /proc interface");
MODULE_LICENSE("GPL");

char *testproc_buf;
unsigned int testproc_size=0;

/**
 * testproc_runtest - Get information for the proc entry and fill the buffer
 *
 * testproc_readproc needs a buffer to read from if the output is going to be 
 * more than one page in size. This function populates a large buffer for 
 * printing out
 */
void testproc_runtest(int procentry) {
	char *procBlock;	/* Small 100k block to write out */
	int i;
	int written=0, endwrite;

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) {
		vmr_printk("Buffer is somehow invalid\n");
		return;
	}
	testproc_buf = testinfo[procentry].procbuf;
	testproc_size = testinfo[procentry].procbuf_size;

	/* malloc procBlock and fill it */
	procBlock = kmalloc(101, GFP_KERNEL);
	if (!procBlock) {
		vmr_printk("Failed to allocate memory for procBlock\n");
		return;
	}
	for (i=0;i<100;i++) procBlock[i] = '0' + (i % 10);
	procBlock[100] = '\0';

	/* Write almost two pages of data into buffer */
	written = sprintf(testproc_buf, "Testing proc interface \n\n");
	endwrite = testproc_size - 120 - strlen(PROCFOOTER);
	while (written < endwrite) {
		written += sprintf(&testproc_buf[written], "%d - %d: ", 
					written, 
					written+100);

		if (written < endwrite)
			written += sprintf(&testproc_buf[written], "%s\n", 
							procBlock);
	}
	
	/* Write out remainder */
	written += sprintf(&testproc_buf[written], PROCFOOTER, (int)(PAGE_ALIGN(testproc_size) / PAGE_SIZE));

	/* Free procBlock */
	kfree(procBlock);

	testinfo[procentry].written = written;
}

/* Callback function for proc write. Allocate a procentry and get it filled */
void testproc_fillproc(int *params, int argc, int procentry) {
	int pages = params[0];

	/* Allocate a new buffer and replace it with the old one */
	if (vmrproc_allocbuffer(pages, &testinfo[procentry]) != 0) return;
	vmr_printk("%d pages allocated for proc buffer\n", pages);

	testproc_runtest(procentry);
}

/* Callback function to initialise the test */
void testproc_init(int procentry) {
	int params[1];
	params[0] = 2;
	testproc_fillproc(params, 1, 0);
}

/* Sanity check parameters */
int vmr_sanity(int *params, int noread) {
	if (params[0] == 0) params[0] = 1;
	return 1;
}

#define NUMBER_PROC_WRITE_PARAMETERS 1
#define CHECK_PROC_PARAMETERS vmr_sanity
#define VMR_WRITE_CALLBACK testproc_fillproc
#include "../init/proc.c"

#define VMR_HELP_PROVIDED testproc_init
#include "../init/init.c"
