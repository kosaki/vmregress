/**
 * nanotime.c: Supprt for some fine-grained time analysis
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * cycles_per_ms: Read the number of cycles that pass in a millisecond
 */
unsigned long long cycles_per_ms(void) {
	FILE *fd = fopen("/proc/cpuinfo", "r");
	int size = 512;
	char *line;
	char *field, *value;
	
	if (fd == NULL) {
		perror("While opening cpuinfo");
		exit(-1);
	}

	line = malloc(size * sizeof(char));
	while (!feof(fd)) {
		memset(line, 0, size);
		getline(&line, &size, fd);
		field = line;
		field[7] = '\0';
		if (!strcmp(field, "cpu MHz")) {
			int i=0;
			unsigned long long retval;
			while (field[i] != ':' && i < size) i++;

			if (i == 512) {
				printf("Could not parse proc entry\n");
				exit(-1);
			}

			i += 2;
			value = &field[i];

			while (field[i] != '\n' && field[i] != ' ') i++;
			field[i] = '\0';

			fclose(fd);
			retval = (unsigned long long) (atof(value) * 1000);
			free(line);
			return retval;
		}
	}

	printf("Unable to determine cpu MHz from /proc/cpuinfo");
	fclose(fd);
	free(line);
	exit(-1);
}


