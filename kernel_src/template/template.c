/*
 * template - a basic templated module
 *
 * This module does no real work other than illustrating how a test module
 * should be structured. A test module is divided into following basic
 * sections
 *
 * o Module declarations, such as MODULENAME, the testinfo struct, the module
 *   description and the proc buffers
 * o Print help function
 * o Calibrate test function
 * o Run test function
 * o Proc read/write
 * o Module init/quit
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
#include <linux/mmzone.h>
#include <linux/mm.h>
#include <linux/vmalloc.h>
#include <linux/spinlock.h>
#include <linux/highmem.h>
#include <asm/rmap.h>		/* Included only if available */

/* Module declarations */
#define MODULENAME "template"
#define NUM_PROC_ENTRIES 4

/* Test names */ 
#define TEST_A 0
#define TEST_B 1
#define TEST_C 2
#define TEST_D 3

static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(TEST_A, MODULENAME "_A", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_B, MODULENAME "_B", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_C, MODULENAME "_C", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_D, MODULENAME "_D", vmr_read_proc, vmr_write_proc)
};

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Template module");
MODULE_LICENSE("GPL");

/**
 * template_alloc_help - Print help message to proc buffer
 * @procentry: Which proc buffer to write to
 */
void template_help(int procentry) {
	/* Efficively clear the proc buffer */
	testinfo[procentry].written = 0;

	printp("%s%s\n\n", MODULENAME, testinfo[procentry].name);
	printp("Here is where a basic help message should be printed\n");
	printp("for the module\n\n");
}

/**
 * template_calculate_parameters - Calculate the parameters of the test
 * @procentry: Indicates which test is been run
 * @argument: Arguements to calculate parameters with
 * @nopasses: Number of passes the test will take
 *
 * Most tests have to decide what the parameters of the test should be. They
 * will have a function with a name similiar to this
 *
 * Return value
 * 0  on success
 * -1 on failure
 */
int template_calculate_parameters(int procentry, int arguement, int nopasses) {

	printp("\no Calculated test parameters with arg %d\n", arguement);

	/* Check the arguements are valid */
	if (arguement == -1) {
		printp("o bogus arguement passed, failing");
		return -1;
	}

	/* Return success */
	return 0;
}

/**
 *
 * template_runtest - Run a test function
 * @params: Parameters read from the proc entry
 * @argc:   Number of parameters actually entered
 * @procentry: Proc buffer to write to
 *
 * Returns
 * 0  on success
 * -1 on failure
 *
 */
int template_runtest(int *params, int argc, int procentry) {
	int nopasses;			/* Number of passes to make */
	int arguement;			/* Arguement passed via proc */

	unsigned long start;		/* Start time in jiffies */
	unsigned long sched_count;	/* Number of schedule calls */

	/* Get the parameters */
	nopasses = params[0];
	arguement = params[1];

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) BUG();

	/* Make sure passes is valid */
	if (nopasses <= 0)
	{
		vmr_printk("Cannot make 0 or negative number of passes\n");
		return -1;
	}

	/* Print header */
	printp("%s%s Test Results.\n\n", MODULENAME, testinfo[procentry].name);
	printp("o Running test with arguement %d\n", arguement);
	
	/* Get the parameters for the test */
	if (template_calculate_parameters(procentry, arguement, nopasses) == -1) {
		printp("Test failed\n");
		return -1;
	}

	printp("Test Parameters\n");
	printp("o Print test parameters here\n");
	printp("\n");

	/* Begin test */
	printp("Test output\n");
	while (nopasses-- > 0) {

		printp("o Pass - %d", nopasses);
		start = jiffies;

		/* --- Perform test here --- */

		/* Call schedule() is necessary */
		check_resched(sched_count);

		/* Print how many milliseconds it took to allocate */
		printp("\t %lums\n", jiffies_to_ms(start));

	}
	
	printp("\nPost Test Information\n");
	printp("o Print post test information here\n");

	return 0;
}

/* Sanity check parameters */
int vmr_sanity(int *params, int noread) {
	if (params[0] == 0) params[0] = 1;
	return 1;
}

#define NUMBER_PROC_WRITE_PARAMETERS 2
#define CHECK_PROC_PARAMETERS vmr_sanity
#define VMR_WRITE_CALLBACK template_runtest
#include "../init/proc.c"

#define VMR_HELP_PROVIDED template_help
#include "../init/init.c"
