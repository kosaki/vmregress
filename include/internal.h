/*
 * internal.h
 *
 * Auto-Generated. See core/Makefile and extract_struct.pl
 * Not all structs are available outside of a c file such 
 * as the kmem_cache_s struct for instance. For vmregress
 * to work with them, it has to know what the structs look
 * like. This include file 'cheats' by extracting out the
 * structs we are interested in...
 *
 * Mel Gorman 2002
 */
   
/* extract_struct.pl: Struct struct pte_chain not found. */
typedef unsigned int kmem_bufctl_t;
/* From: /usr/src/patchset-0.5/kernels/linux-2.6.16-rc6-zbuddy-v7/mm/slab.c */
struct array_cache {
	unsigned int avail;
	unsigned int limit;
	unsigned int batchcount;
	unsigned int touched;
	spinlock_t lock;
	void *entry[0];		/*
				 * Must have this definition in here for the proper
				 * alignment of array_cache. Also simplifies accessing
				 * the entries.
				 * [0] is for gcc 2.95. It should really be [].
				 */
};

/* From: /usr/src/patchset-0.5/kernels/linux-2.6.16-rc6-zbuddy-v7/mm/slab.c */
struct kmem_list3 {
	struct list_head slabs_partial;	/* partial list first, better asm code */
	struct list_head slabs_full;
	struct list_head slabs_free;
	unsigned long free_objects;
	unsigned long next_reap;
	int free_touched;
	unsigned int free_limit;
	unsigned int colour_next;	/* Per-node cache coloring */
	spinlock_t list_lock;
	struct array_cache *shared;	/* shared per node */
	struct array_cache **alien;	/* on other nodes */
};

/* extract_struct.pl: Struct struct cpucache_s not found. */
/* extract_struct.pl: Struct struct kmem_cache_s not found. */
/* From: /usr/src/patchset-0.5/kernels/linux-2.6.16-rc6-zbuddy-v7/mm/slab.c */
struct kmem_cache {
/* 1) per-cpu data, touched during every alloc/free */
	struct array_cache *array[NR_CPUS];
	unsigned int batchcount;
	unsigned int limit;
	unsigned int shared;
	unsigned int buffer_size;
/* 2) touched by every alloc & free from the backend */
	struct kmem_list3 *nodelists[MAX_NUMNODES];
	unsigned int flags;	/* constant flags */
	unsigned int num;	/* # of objs per slab */
	spinlock_t spinlock;

/* 3) cache_grow/shrink */
	/* order of pgs per slab (2^n) */
	unsigned int gfporder;

	/* force GFP flags, e.g. GFP_DMA */
	gfp_t gfpflags;

	size_t colour;		/* cache colouring range */
	unsigned int colour_off;	/* colour offset */
	struct kmem_cache *slabp_cache;
	unsigned int slab_size;
	unsigned int dflags;	/* dynamic flags */

	/* constructor func */
	void (*ctor) (void *, struct kmem_cache *, unsigned long);

	/* de-constructor func */
	void (*dtor) (void *, struct kmem_cache *, unsigned long);

/* 4) cache creation/removal */
	const char *name;
	struct list_head next;

/* 5) statistics */
#if STATS
	unsigned long num_active;
	unsigned long num_allocations;
	unsigned long high_mark;
	unsigned long grown;
	unsigned long reaped;
	unsigned long errors;
	unsigned long max_freeable;
	unsigned long node_allocs;
	unsigned long node_frees;
	atomic_t allochit;
	atomic_t allocmiss;
	atomic_t freehit;
	atomic_t freemiss;
#endif
#if DEBUG
	/*
	 * If debugging is enabled, then the allocator can add additional
	 * fields and/or padding to every object. buffer_size contains the total
	 * object size including these internal fields, the following two
	 * variables contain the offset to the user object and its size.
	 */
	int obj_offset;
	int obj_size;
#endif
};

/* From: /usr/src/patchset-0.5/kernels/linux-2.6.16-rc6-zbuddy-v7/mm/slab.c */
struct slab {
	struct list_head list;
	unsigned long colouroff;
	void *s_mem;		/* including colour offset */
	unsigned int inuse;	/* num of objs active in slab */
	kmem_bufctl_t free;
	unsigned short nodeid;
};

/* extract_struct.pl: Struct struct slab_s not found. */
#define HAVE_NEED_RESCHED
