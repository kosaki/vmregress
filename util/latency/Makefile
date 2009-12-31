CC=gcc
CFLAGS=-Wall -g -I. -D_GNU_SOURCE
LDFLAGS=-lefence
MEASURE_LATENCY_OBJ = measure_latency.o nanotime.o
MMAPTRASH_OBJ = mmaptrash.o
ALL_OBJ = $(MMAPTRASH_OBJ) $(MEASURE_LATENCY_OBJ)
DEPS = nanotime.h

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

all: measure_latency mmap_trash

measure_latency: $(MEASURE_LATENCY_OBJ)
	gcc $(LDFLAGS) -o $@ $^ $(CFLAGS)

mmap_trash: $(MMAPTRASH_OBJ)
	gcc $(LDFLAGS) -o $@ $^ $(CFLAGS)

clean:
	rm $(ALL_OBJ) measure_latency mmaptrash core
