/*
 * mmap.c - Map regions of memory on behalf of a user process
 *
 * This is intended for scripts that want to benchmark page faulting and
 * replacement code. It focuses on the use mmaped regions, either anonymous
 * or file descriptors. 6 proc entries are provided. 
 *
 * mapanon_open		
 * mapfd_open
 * map_read
 * map_write
 * map_close
 * map_addr
 *
 * mapanon_anon takes takes one parameter, the number of bytes to map.
 * The address is stored in mapanon_addr for the process until it is picked
 * up. 
 *
 * mapfd_open takes 5 parameters. The length to map, the protection flags,
 * the mapping flags, the file descriptor and the offset within the file
 * to map. This is directly related to the parameters mmap takes.
 *
 * read takes two parameters. The address to reference and the length
 * to read. The bytes are the location will be read but not returned. The
 * module is only interested in affecting the pages. 
 *
 * write takes two parameters as well except it will write instead of read
 * the address. Remember that if the file is memory mapped, it will be 
 * overwritten.
 *
 * close takes two parameters, the address to unmap and the length
 *
 * addr is a hack and a weird one at that. When a caller uses open to create
 * a mapped region, there is no way to return the address. Returning the
 * addr through procfs gets lost in the ether. What happens is that when
 * an address is opened, it is placed in the map_addr and the buffer
 * locked for the calling pid until the proc entry can be read.
 *
 * This module is provided so userland test scripts can perform testing and
 * use VM Regress to dump kernel information about the process when it
 * is finished
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
#include <pagetable.h>
#include <procprint.h>
#include <linux/spinlock.h>
#include <linux/file.h>
#include <linux/mm.h>
#include <linux/highmem.h>
#include <asm/uaccess.h>
#include <asm/mman.h>

#define MODULENAME "map"

/* Tests */ 
#define MAPANON_OPEN  0
#define MAPFD_OPEN    1
#define MAP_READ      2
#define MAP_WRITE     3
#define MAP_CLOSE     4
#define MAP_ADDR      5

static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(MAPANON_OPEN, MODULENAME "anon_open", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(MAPFD_OPEN,   MODULENAME "fd_open",   vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(MAP_READ,     MODULENAME "_read",     vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(MAP_WRITE,    MODULENAME "_write",    vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(MAP_CLOSE,    MODULENAME "_close",    vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(MAP_ADDR,     MODULENAME "_addr",     vmr_read_proc, vmr_write_proc)
};

/* Module information */
MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Benchmark module for mmap'ed memory");
MODULE_LICENSE("GPL");

/**
 * map_help - Print help message to proc buffer
 * @procentry: Which proc buffer to write to
 */
void map_help(int procentry) {
	/* Efficively clear the proc buffer */
	vmrproc_openbuffer(&testinfo[procentry]);

	printp("%s%s\n\n", MODULENAME, testinfo[procentry].name);
	switch(procentry) {
		case MAPANON_OPEN:
		printp("This will mmap a region in anonymous memory on behalf of the process\n");
		printp("Open the entry for write and pass in the number of bytes to map\n");
		printp("Use readmap/writemap to read/write to the region and closemap to remove\n");
		break;

		case MAPFD_OPEN:
		printp("This will map a file into the memory of the process. It takes 5 parameters\n");
		printp("which are directly related to the normal mmap parameters. They are the\n");
		printp("length in bytes to map, the protection flags, the map flags, the file\n");
		printp("descriptor and the offset within the file to start mapping at. See the\n");
		printp("mmap man page for more details\n");
		
		case MAP_READ:
		printp("This takes two parameters. The first is an address that should be\n");
		printp("within a region that has been mmaped by openmap. The second is the\n");
		printp("number of bytes to read\n");
		break;

		case MAP_WRITE:
		printp("This takes the same parameters as read except the number of bytes is\n");
		printp("written, not read\n");
		break;

		case MAP_CLOSE:
		printp("The two parameters are the address and length to unmap. The first\n");
		printp("should be the address returned by mapopen and the second the\n");
		printp("length of the mapping\n");

	}

	vmrproc_closebuffer(&testinfo[procentry]);
}

/**
 *
 * do_mapping - Wrapper around do_mmap
 */
inline unsigned long do_mapping(size_t length,
				int prot,
				int flags,
				struct file *file,
				off_t offset)
{
	unsigned long addr;
	int procentry;

	/* Try to lock the addr proc entry */
	if (!vmrproc_openbuffer(&testinfo[MAP_ADDR])) {
		vmr_printk("Failed to lock addr buffer. no mapping occured.\n");
		return -1;
	}

	/* MMap an area on behalf of the user */
	addr =  do_mmap(file,			/* No struct file */
		0,				/* No starting address */
		length,				/* Length of address space */
		prot, 				/* Protection */
		flags,				/* Private mapping */
		offset);

	vmr_printk("Mapped: 0x%lX - 0x%lX (%lu pages)\n", addr, addr+length, length / PAGE_SIZE);
			
	if (addr == -1) {
		vmr_printk("Failed to mmap %d bytes PID %d\n", 
				length,
				current->pid);
		return -1;
	}

	/* Print the address */
	procentry = MAP_ADDR;
	printp("%d %lu 0x%lX\n", current->pid, addr, addr);

	return addr;
}

/**
 *
 * map_runtest - Perform the requested action from userspace
 * @params: Parameters read from the proc entry
 * @argc:   Number of parameters actually entered
 * @procentry: Proc buffer to write to
 *
 * 4 proc entries determine what the module will do on behalf of the userspace
 * program. procentry determines what the action will be and the two parameters
 * are arguements. The diffenent entries are described at the beginning of
 * the source
 *
 * Return value
 * Depends on the entry. openmap returns the address opened for example
 *
 */
unsigned long map_runtest(unsigned long *params, int argc, int procentry) {
	unsigned long addr=0;		/* Address mapped area starts */
	unsigned long length;
	struct file *file;
	char *kernbuf;			/* Buffer to read/write to/from userspace */
	int bytes;			/* Bytes to read/write */

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[procentry])) BUG();

	switch(procentry) {
		case MAPANON_OPEN:
			return do_mapping(params[0], 
					PROT_WRITE | PROT_READ,
					MAP_PRIVATE | MAP_ANONYMOUS,
					0, 0);
			break;

		case MAPFD_OPEN:
			file = fget(params[3]);
			if (!file) {
				vmr_printk("Could not find struct file\n");
				return -1;
			}

			/* Parameters are ordered as the mmap man page */
			return do_mapping(
				   params[0],	/* length */
				   params[1],	/* prot */
				   params[2],	/* flags */
				   file,	/* struct file for fd */
				   params[4]);	/* offset */
					
			break;
		
		case MAP_READ:
			/* Read the requested number of bytes */ 
			addr   = params[0];
			length = params[1];
			
			kernbuf=kmalloc(PAGE_SIZE, GFP_KERNEL);
			if (!kernbuf) {
				vmr_printk("Could not alloc buffer %lu for reading\n", length);
				return -1;
			}

			/* Simulate a read in maxiumum amounts of PAGE_SIZE */
			bytes = length;

			while (length != 0) {
				if (bytes > PAGE_SIZE) bytes = PAGE_SIZE;
				else bytes = length;
			
				copy_from_user((unsigned long *)addr, 
						kernbuf, 
						bytes);

				addr += bytes;
				length -= bytes;
			}
			
			kfree(kernbuf);
			return 1;

			break;

		case MAP_WRITE:
			/* Write the requested number of bytes */ 
			addr   = params[0];
			length = params[1];

			kernbuf=kmalloc(PAGE_SIZE, GFP_KERNEL);
			if (!kernbuf) {
				vmr_printk("Could not alloc buffer %lu for writing\n", length);
				return -1;
			}
			/* Put data in the buffer */
			memset(kernbuf, 0xFF, PAGE_SIZE-1);

			/* Simulate a write in maxiumum amounts of PAGE_SIZE */
			bytes = length;
			while (length != 0) {
				if (bytes > PAGE_SIZE) bytes = PAGE_SIZE;
				else bytes = length;
				
				copy_to_user((unsigned long *)addr, kernbuf, bytes);

				addr   += bytes;
				length -= bytes;
			}

			kfree(kernbuf);
			return 1;

			break;

		case MAP_CLOSE:
			/* Unmap a region */
			addr = params[0];
			length = params[1];
			vmr_printk("Unmap:  0x%lX - 0x%lX (%lu pages)\n", addr, addr + length, length/PAGE_SIZE);
			return do_munmap(current->mm, addr, length);
			break;

		case MAP_ADDR:
			vmr_printk("mapanon_addr should not be written to\n");
			break;

		default:
			vmr_printk("HOW DID I GET HERE?!?\n");
			return -1;
			break;
	}

	return -1;
}

#define VMR_READ_PROC_ENDCALLBACK if (procentry == MAP_ADDR) vmrproc_closebuffer_nocheck(&testinfo[MAP_ADDR])
#define VMR_WRITE_CALLBACK map_runtest
#define PARAM_TYPE unsigned long
#define NUM_PROC_ENTRIES 6
#define NUMBER_PROC_WRITE_PARAMETERS 6
#define VMR_HELP_PROVIDED map_help
#include "../init/proc.c"
#include "../init/init.c"
