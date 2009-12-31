/*
 * fault - Test alloc/frees from page fault type behaviouir
 *
 * These tests are on references from userspace memory. The module allocates
 * a region of memory sized based on watermarks in a zone with do_mmap.
 * If CONFIG_HIGHMEM is set, the zone will be ZONE_HIGHMEM otherwise
 * ZONE_NORMAL is used.
 *
 * Within that region, it uses copy_to_user to refer to the pages and force
 * page faults if necessary. This will test straight references made to
 * anonymous memory.
 *
 * There is four proc entries opened for the three tests that can be run
 *
 * test_fault_fast
 * test_fault_low
 * test_fault_min
 * test_fault_zero
 *
 * Fast will remain above the pages_high watermark
 * low will allocate somewhere between pages->low and pages->min
 * min will allocate somewhere between pages->min and 0 pages
 * zero will try and use more pages than are free in the zone to place pressure
 *
 * With low and min, it should be noticed that the free pages after was more
 * after the test than before. This reflects the fact that kswapd should have
 * been called to prune caches slightly. The most stressful test is 
 * test_fault_zero which has to do a lot of work to swap out pages.
 * 
 * All tests take two parameters. The first is the number of passes. Once the
 * area is mapped, all the pages in it will be referenced "passes" number of 
 * times. The second optional parameter is the number of pages to use to build 
 * the zone
 *
 * echo nopasses [nopages] > /proc/vmregres/test_fault_X
 *
 * where X is the test to run
 * 
 * Mel Gorman 2002
 */

#include <linux/version.h>
#include <linux/config.h>
#include <linux/fs.h>
#include <linux/types.h>
#include <linux/proc_fs.h>
#include <linux/kernel.h>
#include <linux/version.h>
#include <linux/module.h>
#include <asm/uaccess.h>

/* Module specific */
#include <vmregress_core.h>
#include <pagetable.h>
#include <procprint.h>
#include <linux/mmzone.h>
#include <linux/mm.h>
#include <linux/vmalloc.h>
#include <linux/spinlock.h>
#include <linux/highmem.h>
#include <asm/uaccess.h>
#include <asm/mman.h>
#include <asm/rmap.h>		/* Included only if available */
#include <vmr_mmzone.h>

#define MODULENAME "test_fault"
#define NUM_PROC_ENTRIES 4

/* Tests */ 
#define TEST_FAST 0
#define TEST_LOW  1
#define TEST_MIN  2
#define TEST_ZERO 3

static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(TEST_FAST, MODULENAME "_fast", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_LOW,  MODULENAME "_low", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_MIN,  MODULENAME "_min", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(TEST_ZERO, MODULENAME "_zero", vmr_read_proc, vmr_write_proc)
};

/* Simple function to give the full name of the test */
inline char *makename(char *fullname, char *testname) {
	strcpy(fullname, MODULENAME); 
	strcat(fullname, testname);
	return fullname;
}

/* Module information */
MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Test page fault paths");
MODULE_LICENSE("GPL");

/* Test string to copy to user space */
static char test_string[] = "Mel";

/*
 * Select which zone to base the test on. mmaps are normally highmem so if
 * highmem is available, select it
 *
 */
#ifdef CONFIG_HIGHMEM
#define ZONE_TEST ZONE_HIGHMEM
#else
#define ZONE_TEST ZONE_NORMAL
#endif

/**
 * test_fault_help - Print help message to proc buffer
 * @procentry: Which proc buffer to write to
 */
void test_fault_help(int procentry) {
	/* Efficively clear the proc buffer */
	vmrproc_openbuffer(&testinfo[procentry]);

	printp("%s%s\n\n", MODULENAME, testinfo[procentry].name);
	printp("To run test, run \n");
	printp("echo numpasses [numpages] > /proc/vmregress/%s%s\n\n", MODULENAME, testinfo[procentry].name);
	printp("Where numpasses is how many times to reference all the pages within\n");
	printp("a mapped area in memory numpages is an optional parameter of how many\n");
	printp("pages to allocate. When the test completes, cat this proc entry again\n");
	printp("to see the results.\n");
	printp("For more information, read the comment at the top of src/test/fault.c\n\n");

	vmrproc_closebuffer(&testinfo[procentry]);

	/* Set flags */
	testinfo[procentry].flags |= VMR_PRINTMAP;
}

/**
 * test_fault_calculate_parameters - Calculate the parameters of the test
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
int test_fault_calculate_parameters(int procentry, C_ZONE **rzone,
				    unsigned long *rnopages, unsigned long *rfreelimit) {
	pg_data_t *pgdat;		/* node to allocate from */
	unsigned long flags;		/* IRQ flags */
	C_ZONE	  *zone=NULL;
	unsigned long nopages, freelimit;

	nopages = *rnopages;
	
	/* Get the zone we are to alloc from */
	pgdat = get_pgdat_list();
	if (pgdat) zone = &pgdat->node_zones[ZONE_TEST]; 
	if (!zone) {
		printp("ERROR: Could not find zone\n");
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
		if (procentry != TEST_ZERO && nopages > zone->free_pages - freelimit) {
			printp("Requested test of %lu pages where %lu is the limit\n", 
					nopages,
					zone->free_pages - freelimit);
			spin_unlock_irqrestore(&zone->lock, flags);
			goto failed;
		}
	} else {
		nopages = zone->free_pages - freelimit;

		/*
	 	 * TEST_ZERO is a special case for nopages because we are trying
	 	 * to alloc all pages in the zone so the number of pages to 
	 	 * allocate is half way between zone->free_pages and the total
	 	 * size of the zone. This will place the zone under extreme
	 	 * pressure
	 	 */
		if (procentry == TEST_ZERO) 
			nopages = zone->free_pages + ( (vmr_zone_size(zone) - zone->free_pages) / 2);
	}
	/* 
	 * Because we are deliberatly allocating memory that will
	 * not be freed in the normal way, we block all signals
	 * to reduce the chance we are killed
	 */
	sigfillset(&current->blocked);

	/* Unlock zone */
	spin_unlock_irqrestore(&zone->lock, flags);

	*rzone = zone;
	*rnopages = nopages;
	*rfreelimit = freelimit;
	return 0;

failed:
	return -1;
}

/**
 * touch_pte - Touches a pte page and returns 1 if it was swapped out
 * @pte: The pte been touched
 * @addr: The address the pte is at
 * @data: Pointer to user data (unused)
 * 
 * This function is used as a callback to forall_pages_mm in the pagetables
 * module
 */
unsigned long touch_pte(pte_t *pte, unsigned long addr, void *data) {

	if (pte_present(*pte)) return 0;

	/*
	 * Copy a string into the page. This will force a
	 * page fault and swap in a real page for this
	 * entry in the memory mapped area
	 */
	copy_to_user((unsigned long *)addr,
			test_string,
			strlen(test_string));

	/* Return 1 indicating the page has been swapped in */
	return 1;
}


/**
 *
 * test_fault_runtest - Allocate and free a number of pages from a zone
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
int test_fault_runtest(int *params, int argc, int procentry) {
	unsigned long nopages;		/* Number of pages to allocate */
	int nopasses;			/* Number of times to run test */
	C_ZONE *zone;			/* Zone been tested on */
	unsigned long freelimit;	/* The min no. free pages in zone */
	unsigned long alloccount;	/* Number of pages alloced */
	unsigned long present;		/* Number of pages present */
	unsigned long addr=0;		/* Address mapped area starts */
	unsigned long len;		/* Length of mapped area */
	unsigned long sched_count;	/* How many times schedule is called */
	unsigned long start;		/* Start of a test in jiffies */
	int totalpasses;		/* Total number of passes */
	int failed=0;			/* Failed mappings */

	/* Get the parameters */
	nopasses = params[0];
	nopages  = params[1];

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) BUG();
	vmrproc_openbuffer(&testinfo[procentry]);

	/* Make sure passes is valid */
	if (nopasses <= 0)
	{
		vmr_printk("Cannot make 0 or negative number of passes\n");
		return -1;
	}

	/* Print header */
	printp("%s Test Results (" UTS_RELEASE ").\n\n", testinfo[procentry].name);

	/* Get the parameters for the test */
	if (test_fault_calculate_parameters(procentry, &zone, &nopages, &freelimit) == -1) {
		printp("Test failed\n");
		return -1;
	}
	len = nopages * PAGE_SIZE;

	/*
	 * map a region of memory where our pages are going to be stored 
	 * This is the same as the system call to mmap
	 *
	 */
	addr =  do_mmap(NULL,		/* No struct file */
			0,		/* No starting address */
			len,		/* Length of address space */
			PROT_WRITE | PROT_READ, /* Protection */
			MAP_PRIVATE | MAP_ANONYMOUS,	/* Private mapping */
			0);
			
	/* get_unmapped area has a horrible way of returning errors */
	if (addr == -1) {
		printp("Failed to mmap");
		return -1;
	}

	/* Print area information */
	printp("Mapped Area Information\n");
	printp("o address:  0x%lX\n", addr);
	printp("o length:   %lu (%lu pages)\n", len, nopages);
	printp("\n");

	/* Begin test */
	printp("Test Parameters\n");
	printp("o Passes:	       %d\n",  nopasses);
	printp("o Starting Free pages: %lu\n", zone->free_pages);
	printp("o Free page limit:     %lu\n", freelimit);
	printp("o References:	       %lu\n", nopages);
	printp("\n");

	printp("Test Results\n");
	printp("Pass       Refd     Present   Time\n");
	totalpasses = nopasses;

	/* Copy the string into every page once to alloc all ptes */
	alloccount=0;
	start = jiffies;
	while (nopages-- > 0) {
		check_resched(sched_count);

		copy_to_user((unsigned long *)(addr + (nopages * PAGE_SIZE)),
			test_string,
			strlen(test_string));

		alloccount++;
	}

	/*
	 * Step through the page tables pass number of times swapping in
	 * pages as necessary
	 */
	for (;;) {

		/* Count the number of pages present */
		present = countpages_mm(current->mm, addr, len, &sched_count);

		/* Print test info */
		printp("%-8d %8lu %8lu %8lums\n", totalpasses-nopasses,
							alloccount,
							present,
							jiffies_to_ms(start));

		if (nopasses-- == 0) break;

		/* Touch all the pages in the mapped area */
		start = jiffies;
		alloccount = forall_pte_mm(current->mm, addr, len, 
				&sched_count, NULL, touch_pte);

	}
	
	printp("\nPost Test Information\n");
	printp("o Finishing Free pages: %lu\n", zone->free_pages);
	printp("o Schedule() calls:     %lu\n", sched_count);
	printp("o Failed mappings:      %u\n",  failed);
	printp("\n");

	printp("Test completed successfully\n");

	/* Print out a process map */
	vmr_printmap(current->mm, addr, len, &sched_count, &testinfo[procentry]);
	/* Unmap the area */
	if (do_munmap(current->mm, addr, len) == -1) {
		printp("WARNING: Failed to unmap memory area"); }

	vmrproc_closebuffer(&testinfo[procentry]);
	return 0;
}

#define NUMBER_PROC_WRITE_PARAMETERS 2
#define VMR_WRITE_CALLBACK test_fault_runtest
#include "../init/proc.c"

#define VMR_HELP_PROVIDED test_fault_help
#include "../init/init.c"
