#include <stdio.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <pthread.h>
#include <string.h>

#define JOBS 2
#define MAX_JOBS JOBS*2

struct job {
	int *region;
	int *end;
	int *start;
	size_t size;
	int type;
	int sleep_time;
	pthread_t thread_id;
};

void *linear_read(void *arg) {
	struct job *job = (struct job *)arg;
	int *ptr;
	int stuff=0;

	/* Read in whole file */
	while (1) {
		for (ptr=job->start; ptr < job->end; ptr++) {
			stuff = *ptr;
			if (job->sleep_time != 0) {
				usleep(job->sleep_time);
			}
		}
	}

	return NULL;
}

void *rand_read(void *arg) {
	struct job *job = (struct job *)arg;
	int *ptr;
	int stuff=0;

	/* Read in whole file */
	while (1) {
		int index = rand() % (job->size/4096) ;
		ptr = (int *)((unsigned long)(job[0].region) + (index * 4096));
		stuff = *ptr;
		if (job->sleep_time != 0) usleep(job->sleep_time);
	}

	return NULL;
}



int main(int argc, char **argv) {
	struct stat buf;
	struct job job[MAX_JOBS];
	int fd;
	int i,index;
	printf("PID: %u\n", getpid());
	if (argc <= 1) {
		printf("Must specify a file to test with\n");
		exit(EXIT_FAILURE);
	}

	/* Get the file statistics */
	if (stat(argv[1], &buf) == -1) {
		perror("While statting file");
		exit(EXIT_FAILURE);
	}
	printf("File exists and is of size %lu\n", buf.st_size);
	job[0].size = buf.st_size;
	job[0].sleep_time = 0;

	/* Open the file */
	if ((fd = open(argv[1], O_RDWR)) == -1) {
		perror("While opening file");
		exit(EXIT_FAILURE);
	}

	/* MMap the file */
	job[0].region = mmap(0, job[0].size, PROT_READ|PROT_WRITE, MAP_PRIVATE, fd, 0);
	job[0].start = job[0].region;
	if ((void *)job[0].region == (void *)-1) {
		perror("While mmaping file");
		exit(EXIT_FAILURE);
	}
	job[0].end = (int *)((unsigned long)job[0].region + job[0].size);
	printf("Region mapped at 0x%lX to 0x%lX\n", 
			(unsigned long)job[0].region, 
			(unsigned long)job[0].end);

	printf("Starting main read thread\n");
	pthread_create(&job[0].thread_id, NULL, linear_read, &job[0]);

	srand((unsigned int)time(NULL));
	for (i=1; i < JOBS; i++) {
		memcpy(&job[i], &job[0], sizeof(struct job));
		index = rand() % (job[0].size/4096) ;
		job[i].start = (int *)((unsigned long)(job[0].region) + (index * 4096));
		job[i].sleep_time = 500000;
		if (job[1].start > job[1].end) {
			printf("BUG");
			exit(EXIT_FAILURE);
		}
		printf("Starting linear job at index: %d\n", index);
		pthread_create(&job[i].thread_id, NULL, linear_read, &job[i]);
	}

	for (i=JOBS; i < MAX_JOBS; i++) {
		memcpy(&job[i], &job[0], sizeof(struct job));
		printf("Starting random job\n");
		pthread_create(&job[i].thread_id, NULL, rand_read, &job[i]);
	}

	fflush(NULL);


	pthread_join(job[0].thread_id, NULL);

	/* Unmap the file and close */
	munmap(job[0].region, buf.st_size);
	close(fd);

	exit(EXIT_SUCCESS);
}


	

