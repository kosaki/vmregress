/*
 * zone
 *
 * This will print out all zone information in the system and what their
 * statistics are. This is handy for deciding how to run other tests and
 * to see the actual state of the system
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
#include <vmr_mmzone.h>
#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/highmem.h>
#include <asm/page.h>
#include <asm/rmap.h>		/* Included only if available */

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Prints out zone statistics");
MODULE_LICENSE("GPL");

/* Kernel internal data structures */
#include <internal.h>

#define MODULENAME "sense_zones"
#define NUM_PROC_ENTRIES 1

/* Sense modules */
#define SENSE_STRUCTS 0
static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(SENSE_STRUCTS, MODULENAME, vmr_read_proc, NULL)
};

/* Zone names */
static char *zone_names[MAX_NR_ZONES] = {
	"ZONE_DMA",
	"ZONE_NORMAL",
	"ZONE_HIGHMEM" };

/**
 *
 * zone_getproc - Get information for the proc entry and fill the buffer
 *
 * This is called at proc read to print out all the available information
 */
void zone_getproc(int procentry) {
	int ncount, zcount, pcount;	/* No. nodes, zones and pages */
	unsigned long flags;		/* IRQ flags */
	pg_data_t *pgdat=NULL;
	C_ZONE    *zone=NULL;
	
	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) {
		vmr_printk("PROC BUFFER EMPTY\n");
		return;
	}

	vmrproc_openbuffer(&testinfo[procentry]);

	/* Step through all nodes */
	pgdat = get_pgdat_list();
	pcount = ncount = zcount = 0;

	if (!pgdat) {
		printp("Could not find a node\n");
		return;
	}

	/*
	 * Step through all nodes 
	 * There is a for_each_pgdat() helper macro but it'll break
	 * in the event the symbol is not exported so we have to
	 * do it this way 
	 */
	do {
		printp("Node %d\n------\n", ncount);
		ncount++;

		/* Macro to read all zones in this node */
#define all_zones(print_info) for (zcount=0;zcount<pgdat->nr_zones; zcount++) {\
	zone = pgdat->node_zones + zcount; \
	if (zone) { \
		spin_lock_irqsave(&zone->lock, flags); \
		print_info \
		spin_unlock_irqrestore(&zone->lock, flags); \
	} else { printp("ZONE NULL\n"); } \
	} \
	printp("\n");

		/* Print Zone information */
		all_zones(printp("%-32s", zone_names[zcount]);)
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,5,62))
		all_zones(printp("zone->size          = %8lu  ", zone->size);)
#else
		all_zones(printp("zone->present_pages = %8lu  ", zone->present_pages);)
		all_zones(printp("zone->spanned_pages = %8lu  ", zone->spanned_pages);)
#endif
		all_zones(printp("zone->free_pages    = %8lu  ", zone->free_pages);)
		all_zones(printp("zone->pages_high    = %8lu  ", zone->pages_high);)
		all_zones(printp("zone->pages_low     = %8lu  ", zone->pages_low);)
		all_zones(printp("zone->pages_min     = %8lu  ", zone->pages_min);)
		printp("\n\n");

		/* Update node ID */
	} while ((vmr_next_pgdat(pgdat)));

}

#define VMR_READ_PROC_CALLBACK zone_getproc
#include "../init/proc.c"
#include "../init/init.c"
