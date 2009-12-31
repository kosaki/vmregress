/*
 * sizes
 *
 * This module will print out the sizes of various structs so it can be seen 
 * how much memory is been consumed by some kernel structures. This is handy 
 * for seeing how much savings are made or penalties accrued for changes to 
 * the structs
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
#include <linux/mmzone.h>
#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <linux/spinlock.h>
#include <linux/highmem.h>
#include <vmregress_core.h>
#include <procprint.h>
#include <vmr_mmzone.h>
#include <asm/page.h>
#include <asm/rmap.h>		/* Included only if available */
#include <internal.h>		/* Kernel internal data structures */

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Prints out the sizes of various VM structs");
MODULE_LICENSE("GPL");

#define MODULENAME "sense_structsizes"
#define NUM_PROC_ENTRIES 1

/* Sense modules */
#define SENSE_STRUCTS 0
static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(SENSE_STRUCTS, MODULENAME, vmr_read_proc, NULL)
};

/**
 *
 * sizes_getproc - Get information for the proc entry and fill the buffer
 *
 * This is the callback function called to fill a buffer when the proc
 * entry is being read
 */
void sizes_getproc(int procentry) {
	int ncount, zcount, pcount;	/* No. nodes, zones and pages */
	int tcount, mcount, vcount;	/* No. tasks, mm_structs, vma structs */
	int highmem, reserved, cached;  /* No. High mem pages, Reserved pages, Cached pages */
	int shared;			/* No shared pages */
	int present_pages, spanned_pages; /* zone info */
	int total;			/* Total memory usage */
	pg_data_t *pgdat;
	struct mm_struct *mm;
	struct vm_area_struct *vma;
	struct page *page;
	C_ZONE *zone;
	int i;

	/* Initialize to avoid compiler warning */
	mm = NULL;
	vma = NULL;

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(&testinfo[procentry])) BUG();

	vmrproc_openbuffer(&testinfo[procentry]);

	/* Physical memory representation structs and memory use */
	printp("\nLinux Kernel " UTS_RELEASE "\n\n");
	printp("\nPhysical memory representation\n");
	printp("o pg_data_t: %d\n", sizeof(pg_data_t));
	printp("o zone:      %d\n", sizeof(C_ZONE));
	printp("o page:      %d\n", sizeof(struct page));
#ifdef _I386_RMAP_H
	printp("o pte_chain: %d\n", sizeof(struct pte_chain));
#endif
	printp("\n");

	printp("\nVirtual memory representation\n");
	printp("o vm_struct: %d\n", sizeof(struct vm_struct));
	printp("\n");

	/* Process related structs */
	printp("Process related structs\n");
	printp("o task:           %d\n", sizeof(struct task_struct));
	printp("o mm_struct:      %d\n", sizeof(struct mm_struct));
	printp("o vm_area_struct: %d\n", sizeof(struct vm_area_struct));
	printp("\n");

	/* Buddy System */
	printp("Buddy related\n");
	printp("o free_area: %d\n", sizeof(C_FREE_AREA));
	printp("\n");

	/* Slab */
	printp("Slab allocator related\n");
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,6,15))
	printp("o kmem_cache_s:   %d\n", sizeof(struct kmem_cache_s));
#else
	printp("o kmem_cache:     %d\n", sizeof(struct kmem_cache));
#endif
	printp("o slab:           %d\n", sizeof(C_SLAB));
	printp("\n");

	printp("Live System Memory Usage\n");
	pcount = ncount = zcount = 0;
	tcount = mcount = vcount = 0;
	highmem = reserved = cached = 0;
	present_pages = spanned_pages = 0;
	shared = 0;
	total=0;

	/*
	 * Calculate how many nodes, zones and pages are in the system to see
	 * how much memory is used to represent them
	 */
	pgdat = get_pgdat_list();

	if (pgdat) {
		for_each_pgdat(pgdat) {
			ncount++;
			zcount += pgdat->nr_zones;
			for (i = 0; i < NODE_SIZE(pgdat); ++i) {
				page = pgdat_page_nr(pgdat, i);
				pcount++;
				if (PageHighMem(page))
					highmem++;
				if (PageReserved(page))
					reserved++;
				else if (PageSwapCache(page))
					cached++;
				else if (page_count(page))
					shared += page_count(page) - 1;

			}
			for (i=pgdat->nr_zones-1; i >= 0; i--) {
			            zone = pgdat->node_zones + i;
			            present_pages += vmr_zone_size(zone);
			            spanned_pages += vmr_zone_spanned(zone);
			}
		}
	
		printp("nodes * %d\t = %d\n", ncount, ncount * sizeof(pg_data_t));
		printp("zones * %d\t = %d\n", zcount, zcount * sizeof(C_ZONE));
		printp("pages * %d\t = %d\n", pcount, pcount * sizeof(struct page));
		printp("highpages %d reserved %d shared %d swap cached %d\n",
				highmem, reserved, shared, cached);
		printp("present_pages %d spanned_pages %d\n", present_pages, spanned_pages);
#ifdef _I386_RMAP_H
		printp("pte_chain \t = See /proc/slabinfo for details\n");
#endif
		printp("\n");
		total += ncount * sizeof(pg_data_t) +
			zcount * sizeof(C_ZONE) +
			pcount * sizeof(struct page);
	} else {

		printp("Note: Cannot show systemwide stats without pgdat_list exported\n");
		printp("pte_chain: See /proc/slabinfo for details for total memory usage\n");
		printp("      It is the the first column multiplied by sizeof(pte_chain)\n");
		printp("      printed above\n");
	}


#ifdef MMLIST_LOCK_EXPORTED
	/* Calculate how much memory is been used */
	mm = &init_mm;

	spin_lock(&mmlist_lock);
	do {
		/* Each mm implies one task */
		tcount++;
		mcount++;

		/* Count number of vma's */
		spin_lock(&mm->page_table_lock);
		vma = mm->mmap;
		if (vma) {
			for (;;) {
				vcount++;
				vma = vma->vm_next;
				if (!vma) break;
			}
		}
		spin_unlock(&mm->page_table_lock);

		/* Move to next MM */
		mm = list_entry(mm->mmlist.next, struct mm_struct, mmlist);
	} while (mm != &init_mm);
	spin_unlock(&mmlist_lock);

	printp("tasks * %d\t = %d\n", tcount, tcount * sizeof(struct task_struct));
	printp("mm    * %d\t = %d\n", mcount, mcount * sizeof(struct mm_struct));
	printp("vma   * %d\t = %d\n", vcount, vcount * sizeof(struct vm_area_struct));

	total += tcount * sizeof(struct task_struct) +
		mcount * sizeof(struct mm_struct) +
		vcount * sizeof(struct vm_area_struct);

#else
	printp("Note: Cannot show systemwide stats without mmlist_lock exported\n");
#endif

	printp("\ntotal usage = %d bytes\n", total);
}

/* Include functions for reading proc entries */
#define VMR_READ_PROC_CALLBACK sizes_getproc
#include "../init/proc.c"

/* Module init code */
#include "../init/init.c"
