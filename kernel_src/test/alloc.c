/*
 * alloc - Test alloc/free physical page functions
 *
 * These tests are straight alloc/free tests. It tries to allocate or free as
 * many pages as possible before a watermark is hit. The objective is to make
 * sure that the three main situations alloc/free meets can be executed
 * successfully.
 *
 * The test runs on ZONE_NORMAL on the first node it can find. This is fine as
 * many architectures, including the x86, have only one node. alloc_pages is 
 * called with the GFP_ATOMIC parameter to ensure the test can get into the
 * really slow memory paths without entering other subsystems and leave this
 * module to decide when to sleep
 *
 * During module load, if gfp_kernel is set to 1, GFP_KERNEL will be used 
 * There is a  strong danger of really running OOM and killing the process 
 * with test_alloc_zero so be very careful. 
 *
 * an example load to use GFP_KERNEL is
 * insmod ./fault.o gfp_kernel=1
 * A message is printed at module load to indicate which GFP_ flags are used
 *
 * There is four proc entries opened for the three tests that can be run
 *
 * test_alloc_fast 
 * test_alloc_low
 * test_alloc_min
 * test_alloc_zero
 *
 * test_alloc_fast will alloc pages until it is close to pages_high. This test
 * is simply on fast allocs/frees . The only code paths tested are those 
 * dealing exclusively with physical pages
 *
 * test_alloc_low will alloc pages until the number of free pages is somewhere
 * between zone->pages_low and zone->pages_min . This will force the caller to
 * attempt to free some pages to do it's work
 *
 * test_alloc_min will alloc pages until the zone is in really tight memory
 * to see how the allocator will behave
 *
 * test_alloc_zero will alloc way more pages than are free. More accuratly, it
 * will allocate a number of pages half way between zone->free_pages and 
 * vmr_zone_size(zone). vmr_zone_size() is a macro which returns zone->size
 * in 2.4 kernels and zone->present_pages in later (> 2.5.62) kernels.
 * This will deliberatly put the page allocator under a lot of 
 * pressure probably forcing an OOM situation. Use with EXTREME care
 *
 * The tests all take two paramaters, the second one optional. The first
 * parameter is how many times to alloc/free a block of pages. The second
 * parameter is exactly how many pages should be allocated for each pass.
 * For test_alloc_fast, a test could be
 *                                                                            
 * echo numpasses > /proc/vmregress/test_alloc_fast                            
 * 
 * where numpasses is how many times to allocate as many pages as possible. If 
 * it is undesirable to allocate all the pages, pass a second parameter, the   
 * number of pages to allocate/free                                            
 *
 * echo numpasses numpages > /proc/vmregress/test_alloc_fast                   
 *                                                                           
 * Cat the /proc/vmregress/test_alloc_fast to read the results of the test.
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
#include <vmr_mmzone.h>

#define MODULENAME "test_alloc"
#define NUM_PROC_ENTRIES 4

/* Tests */ 
#define TEST_FAST 0
#define TEST_LOW  1
#define TEST_MIN  2
#define TEST_ZERO 3

static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(TEST_FAST, MODULENAME "_fast", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_LOW,  MODULENAME "_low",  vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_MIN,  MODULENAME "_min",  vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_ZERO, MODULENAME "_zero", vmr_read_proc, vmr_write_proc)
};

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Test alloc_pages fast path");
MODULE_LICENSE("GPL");

/* Boolean to indicate whether to use GFP_KERNEL or not */
static int gfp_kernel;
MODULE_PARM(gfp_kernel, "i");
MODULE_PARM_DESC(gfp_kernel, "Set to 1 if GFP_KERNEL is to be used with alloc_pages");

/* GFP flags to use with __alloc_pages. defaults to GFP_ATOMIC */
unsigned int gfp_flags=GFP_ATOMIC;

/**
 * test_alloc_help - Print help message to proc buffer
 * @procentry: Which proc buffer to write to
 */
void test_alloc_help(int procentry) {
	vmrproc_openbuffer(&testinfo[procentry]);

	printp("%s%s\n\n", MODULENAME, testinfo[procentry].name);
	printp("To run test, run \n");
	printp("echo numpasses [numpages] > /proc/vmregress/%s%s\n\n", MODULENAME, testinfo[procentry].name);
	printp("Where numpasses is how many times to allocate a block of pages\n");
	printp("and numpages is an optional parameter of how many pages to allocate\n");
	printp("When the test completes, cat this proc entry again to see the results.\n");
	printp("For more information, read the comment at the top of src/test/alloc.c\n\n");
	
	/* Set gfp_flags based on the module parameter */
	if (gfp_kernel) gfp_flags = GFP_KERNEL;
	
	if (gfp_flags == GFP_ATOMIC) {
		printp("This test will call __alloc_pages with GFP_ATOMIC. To use\n");
		printp("GFP_KERNEL, reload this module passing the parameter gfp_kernel=1\n\n");
	}

	if (procentry == TEST_ZERO) {
		printp("This test will deliberatly force an OOM situation and put the allocator\n");
		printp("under a LOT of pressure. Only run this if you are sure it is what you\n");
		printp("want to do\n\n");

		if (gfp_flags == GFP_KERNEL) {
			printp("GFP_KERNEL is been used so this test is exceptionally dangerous. If it gets aborted, you'll HAVE to reboot\n");
			printp("Only run this test if you are really sure it is what you want\n\n");
		}
	}

	vmrproc_closebuffer(&testinfo[procentry]);
}

/**
 * test_alloc_calculate_parameters - Calculate the parameters of the test
 * @procentry: Indicates which test is been run
 * @rzone: Return the zone been tested on
 * @rnopages: Return the number of pages to allocate
 * @rfreelimit: The number of pages that must be free for the test to continue
 *
 * nopages is the number of pages that should be allocated and
 * freed for the test. If passed in as 0, it will be the maximum
 * number of pages to allocate. If a value is provided, that 
 * number of pages will be used if possible
 *
 * The freelimit is a number of pages that must be free for the
 * test to continue running. It is defined as to be pages_high
 * plus 5% of the total number of pages that can be allocated 
 * at the beginning of the test. This is to give a safe margin
 *
 * Return value
 * 0  on success
 * -1 on failure
 */
int test_alloc_calculate_parameters(int procentry, C_ZONE **rzone,
				    unsigned long *rnopages, unsigned long *rfreelimit) {
	pg_data_t *pgdat;		/* node to allocate from */
	unsigned long       flags;	/* IRQ flags */
	C_ZONE	  *zone=NULL;
	unsigned long nopages, freelimit;

	nopages = *rnopages;
	
	/* Get the zone we are to alloc from */
	pgdat = get_pgdat_list();
	if (pgdat) zone = &pgdat->node_zones[ZONE_NORMAL]; 
	if (!zone) {
		printp("ERROR: Could not find ZONE_NORMAL\n");
		goto failed;
	}

	/* Lock the zone so we are sure the zone won't change */
	spin_lock_irqsave(&zone->lock, flags);

	/* Calculate watermark for test */
	switch (procentry) {
		case TEST_FAST:
			/*
			 * Watermark is pages_high so as to be sure kswapd is
			 * not involved 
			 */
			freelimit = zone->pages_high;
			break;

		case TEST_LOW:
			/*
			 * Watermark is half way between low and min so that
			 * kswapd will be woken up to do work
			 */
			freelimit = zone->pages_min + ( (zone->pages_low - zone->pages_min) / 2);
			break;

		case TEST_MIN:
			/*
			 * Watermark is half way between 0 pages and pages_min
			 * so that kswapd will have to work heavily
			 */
			freelimit = zone->pages_min / 2;
			break;

		case TEST_ZERO:
			freelimit = 0;

			/*
			 * GFP_KERNEL is a special case. There is too strong
			 * a chance of going totally OOM with a freelimit of
			 * 0 so it is set to 1.
			 */
			if (gfp_flags == GFP_KERNEL) freelimit = 1;
			break;

		default:
			printp("Test %d does not exist\n", procentry);
			spin_unlock_irqrestore(&zone->lock, flags);
			goto failed;
			break;
	}

	/* Check it is possible to even start the test */
	if (zone->free_pages <= freelimit) {
		printp("ERROR: Only %lu pages free on zone with watermark of %lu\n", 
			zone->free_pages,
			freelimit);
		spin_unlock_irqrestore(&zone->lock, flags);
		goto failed;
	}

	/* Calculate nopages */
	if (nopages)
	{
		/* If a specfic page request was made, make sure it's ok */
		if (nopages > zone->free_pages - freelimit) {
			printp("Requested test of %lu pages where %lu is the limit\n", 
					nopages,
					zone->free_pages - freelimit);
			spin_unlock_irqrestore(&zone->lock, flags);
			goto failed;
		}
	} else nopages = zone->free_pages - freelimit;

	/*
	 * TEST_ZERO is a special case for nopages because we are trying
	 * to alloc all pages in ZONE_NORMAL so the number of pages to 
	 * allocate is half way between zone->free_pages and the total
	 * size of the zone. This will place the zone under extreme
	 * pressure
	 */
	if (procentry == TEST_ZERO && gfp_flags != GFP_KERNEL) {
		nopages = zone->free_pages + ( (vmr_zone_size(zone) - zone->free_pages) / 2);

		/* 
		 * Because we are deliberatly allocating memory that will
		 * not be freed in the normal way, we block all signals
		 * to reduce the chance we are killed
		 */
		sigfillset(&current->blocked);
	}

	/*
	 * Adjust the number of pages to allocate to take into account the
	 * pages needed to store pointers to pages allocated for the test
	 */
	nopages -= (nopages * sizeof(struct page *)) / PAGE_SIZE + 1;

	/* Unlock zone */
	spin_unlock_irqrestore(&zone->lock, flags);

	/* Final sanity check */
	if (nopages > num_physpages) {
		printp("nopages exceeds the number of physical pages");
		goto failed;
	}

	*rzone = zone;
	*rnopages = nopages;
	*rfreelimit = freelimit;
	return 0;

failed:
	return -1;
}



/**
 *
 * test_alloc_runtest - Allocate and free a number of pages from a ZONE_NORMAL
 * @params: Parameters read from the proc entry
 * @argc:   Number of parameters actually entered
 * @procentry: Proc buffer to write to
 *
 * If pages is set to 0, pages will be allocated until the pages_high watermark
 * is hit
 * Returns
 * 0  on success
 * -1 on failure
 *
 */
int test_alloc_runtest(int *params, int argc, int procentry) {
	unsigned long nopages;		/* Number of pages to allocate */
	int nopasses;			/* Number of times to run test */
	C_ZONE *zone;			/* Zone been tested on */
	unsigned long freelimit;	/* The min no. free pages in zone */
	unsigned long alloccount;	/* Number of pages alloced */
	unsigned long failed=0;		/* Number of passes that alloc failed */
	struct page **pages;		/* An array of allocations */
	unsigned int sched_count=0;	/* Counts for schedule() */

	unsigned long start;		/* Start time of test in jiffies */
	unsigned long totalalloced=0;	/* Total count of pages allocated */
	unsigned long totalfreed=0;	/* Total count of pages freed */

	/* Get the parameters */
	nopasses = params[0];
	nopages = params[1];

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) BUG();
	vmrproc_openbuffer(&testinfo[procentry]);

	/* Make sure passes is valid */
	if (nopasses <= 0)
	{
		vmr_printk("Cannot make 0 or negative number of passes\n");
		return -1;
	}

	/* Get the parameters for the test */
	if (test_alloc_calculate_parameters(procentry, &zone, &nopages, &freelimit) == -1) {
		printp("Test failed\n");
		return -1;
	}

	/* Print header */
	printp("%s Test Results (" UTS_RELEASE ").\n\n", testinfo[procentry].name);

	/* 
	 * Allocate memory to store pointers to pages. This will slightly 
	 * pollute the test by causing page faults but it can't be helped
	 */
	pages = vmalloc((nopages+1) * sizeof(struct page **));
	if (!pages)
	{
		printp("ERROR: Unable to vmalloc memory (%lu pages) for page pointers\n", nopages);
		printp("Test failed\n");
		return -1;
	}
	memset(pages, 0, nopages*sizeof(struct page **));
	
	/* Begin test */
	printp("Test Parameters\n");
	printp("o Passes:               %d\n",  nopasses);
	printp("o Starting Free pages:  %lu\n", zone->free_pages);
	printp("o Allocations per pass: %lu\n", nopages);
	printp("o Free page limit:      %lu\n", freelimit);
	printp("\nTest Output (Time to alloc/free)\n");
	printp("\tAlloc\tFree\n");

	while (nopasses-- > 0) {

		/* Allocate all the pages */
		alloccount=0;
		start = jiffies-1;
		
		while (--nopages > 0 && zone->free_pages > freelimit)
		{
			/* Call schedule() is necessary */
			check_resched(sched_count);

			/* Allocate page */
			pages[alloccount] = alloc_pages(gfp_flags,0);
			if (pages[alloccount] == NULL) break;
	
			alloccount++;
			totalalloced++;
		}

		/* Print how many milliseconds it took to allocate */
		printp("\t %lums\t", jiffies_to_ms(start));

		/*
		 * Ideally, this won't happen but could if there is other
		 * processes allocating memory
		 */
		if (nopages) failed++;

		/* Reset nopages for next pass */
		nopages += alloccount;

		/* Free the pages */
		start=jiffies-1;
		do {
			alloccount--;
			if (pages[alloccount]) {
				__free_pages(pages[alloccount],0);
				totalfreed++;
			}
		} while (alloccount != 0);

		/* Print how many milliseconds it took to free */
		printp("%lums\n", jiffies_to_ms(start));
	}
	vfree(pages);
	
	printp("\nPost Test Information\n");
	printp("o Finishing Free pages: %lu\n", zone->free_pages);
	printp("o Schedule() calls:     %u\n",  sched_count);
	printp("o Aborted passes:       %lu\n", failed);
	printp("o Total alloced:        %lu\n", totalalloced);
	printp("o Total freed:          %lu\n", totalfreed);
	printp("\n");

	printp("Test completed successfully\n");

	vmrproc_closebuffer(&testinfo[procentry]);
	return 0;
}

/* Sanity check the parameters */
int vmr_sanity(int *params, int noread) {
	if (params[0] <= 0) params[0] = 1; /* Number passes */
	if (params[1] < 0)  params[1] = 0; /* Number pages  */
	return 1;
}
	
#define NUMBER_PROC_WRITE_PARAMETERS 2
#define CHECK_PROC_PARAMETERS vmr_sanity
#define VMR_WRITE_CALLBACK test_alloc_runtest
#include "../init/proc.c"

#define VMR_HELP_PROVIDED test_alloc_help
#include "../init/init.c"
