/**
 * This is a simulated server. It creates a number of files of a fixed size
 * and waits for incoming connections. On each connection received, it
 * sends a random file back
 */

#include <stdio.h> 
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/types.h> 
#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>

#define FILESIZE (10 * 1048576)
#define FILEDIR "/usr/src/webserve"
#define FILENUM 200
#define PORT 8892
#define MAX_CLIENTS 5000

#define USE_FORK

#define dbg_printf(x, args...) printf(x, ## args)
#define dbg_perror(x) perror(x)

int serveFile(int socketfd, char *fileDir, int fileNumber)
{
	int length, result;
	off_t written = 0;

	length = strlen(fileDir) + 21 * sizeof(char);
	char *name = malloc(length);
	if (name == NULL) {
		dbg_printf("Failed to malloc memory\n");
		return -1;
	}

	snprintf(name, 255, "%s/%d", FILEDIR, fileNumber);
	length = strlen(name);

	dbg_printf("Serving file %s\n", name);
	int in_fd = open(name, O_RDONLY);
	if (in_fd == -1) {
		dbg_perror("Failed to open file");
		return -1;
	}

	while (written < length) {
		result = sendfile(socketfd, in_fd, &written, FILESIZE - written);
		if (result == -1) {
			dbg_perror("Error occured while calling sendfile\n");
			close(socketfd);
			return result;
		} 

	}

	close(socketfd);
	close(in_fd);
	free(name);
	return 0;

}

int createFiles(int fileSize, int fileNum, char *fileDir)
{
	int length = strlen(fileDir) + 21 * sizeof(char);
	char *name = malloc(length);
	if (name == NULL) {
		return ENOMEM;
	}

	dbg_printf("Creating files\n");
	while (--fileNum >= 0) {
		snprintf(name, length, "%s/%d", fileDir, fileNum);

		/* Create the file */
		int fd = open(name, O_CREAT|O_EXCL|O_RDWR|O_SYNC);
		if (fd == -1) {
			dbg_perror("While creating a file");
			free(name);
			return fd;
		}
		fchmod(fd, 0600);

		/* Size the file */
		int result = ftruncate(fd, FILESIZE);
		if (result != 0) {
			dbg_perror("While calling truncate");
			close(fd);
			free(name);
			return result;
		}

		/* MMap the file */
		void *buffer = mmap(0, FILESIZE, PROT_WRITE, MAP_SHARED, fd, 0);
		if (buffer == (void *)-1) {
			dbg_perror("While mmapping a file");
			close(fd);
			free(name);
			return EACCES;
		}
		
		/* Write data */
		memset(buffer, 0xDEADBEEF, FILESIZE);

		/* Close up the file */
		munmap(buffer, FILESIZE);
		fsync(fd);
		while (close(fd) != 0);
	}

	free(name);
	return 0;
}

int cleanupFiles(int fileNum, char *fileDir)
{
	int length = strlen(fileDir) + 21 * sizeof(char);
	char *name = malloc(length);
	if (name == NULL) {
		return ENOMEM;
	}

	printf("Cleaning up files\n");
	while (--fileNum >= 0) {
		struct stat buf;
		snprintf(name, length, "%s/%d", fileDir, fileNum);
		int retVal = stat(name, &buf);
		if (retVal == 0)
			unlink(name);
	}
	free(name);
	return 0;
}

int createSocket(int port, int maxClients)
{
	/* Create socket */
	int socketfd = socket(PF_INET, SOCK_STREAM, 0);
	if (socketfd == -1) {
		dbg_perror("While creating socket");
		return socketfd;
	}

	/* Connection information */
	struct sockaddr_in serv_addr;
	memset(&serv_addr, 0, sizeof(struct sockaddr_in));
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = INADDR_ANY;
	serv_addr.sin_port = htons(port);

	/* Bind */
	int retVal = bind(socketfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr));
	if (retVal == -1) {
		dbg_perror("While binding to socket");
		return -1;
	}

	/* Listen */
	if (listen(socketfd, maxClients) == -1) {
		dbg_perror("While calling listen");
		return -1;
	}

	return socketfd;
}

/* Simple signal handler */
int stayAlive = 1;
void signalHandle(int sig) {
	stayAlive = 0;
}

int main()
{
	/* Setup signal handler */
	signal(SIGINT, signalHandle);
	signal(SIGHUP, signalHandle);
	signal(SIGTERM, signalHandle);

	/* Create the socket */
	int socketfd = createSocket(PORT, MAX_CLIENTS);
	if (socketfd < 0) {
		fprintf(stderr, "Failed to create socket to listen on\n");
		exit(EXIT_FAILURE);
	}

	/* Create the files */
	int error = createFiles(FILESIZE, FILENUM, FILEDIR);
	if (error < 0) {
		cleanupFiles(FILENUM, FILEDIR);
		close(socketfd);
		exit(EXIT_FAILURE);
	}

	/* Some state variables */
	time_t thistime;
	time_t lastclean = time(NULL);
	fd_set fdset;
	FD_ZERO(&fdset);
	int filesend = 0;
	int children=0;

	/* Enter accept loop */
	while (stayAlive) {
		struct sockaddr_in client;
		socklen_t length;
		int status;

		/* Create FD set  and timeout */
		struct timeval timeout;
		timeout.tv_sec = 5;
		timeout.tv_usec = 0;

		/* Check for a connection */
		dbg_printf("Waiting for an incoming connection\n");
		FD_SET(socketfd, &fdset);
		status = select(socketfd+1, &fdset, &fdset, NULL, &timeout);
		if (status < 0) {
			dbg_perror("While calling select");
			continue;
		}

		/* Clean up dead children at least every 3 seconds */
		thistime = time(NULL);
		if (children > 20 || thistime - lastclean >= 3) {
			int waitstatus;
			dbg_printf("Cleaning up dead children\n");
			while (waitpid(-1, &waitstatus, WNOHANG) > 0) {
				children--;
			}
			lastclean = thistime;
		}

		/* If the socket is not waiting, loop and call select again */
		if (status == 0) {
			continue;
		}

		/* Accept a connection */
		while (status-- > 0) {
			dbg_printf("Accepting connection on fd %d\n", socketfd);
			length = sizeof(client);
			int newfd = accept(socketfd,
					(struct sockaddr *)&client,
					&length);
			if (newfd == -1) {
				fprintf(stderr, "Failed to accept connection: %s(%d)\n", strerror(errno), errno);
				continue;
			}
			dbg_printf("Connection accepted\n");

#ifdef USE_FORK
			children++;
			pid_t pid = fork();
			if (pid == 0) {
				dbg_printf("Child serving file\n");
				serveFile(newfd, FILEDIR, filesend);
				dbg_printf("Child exiting\n");
				exit(EXIT_SUCCESS);
			} else {
				close(newfd);
			}
		}
#else
#error Non-fork implementation does not exist
#endif
		filesend = (filesend + 1) % FILENUM;
	}

	cleanupFiles(FILENUM, FILEDIR);
	close(socketfd);
	exit(EXIT_SUCCESS);
}

