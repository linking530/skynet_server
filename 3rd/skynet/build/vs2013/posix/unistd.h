#pragma once
#include <stdio.h>
#include <fcntl.h>
#include <assert.h>
#include <pthread.h>

#define random rand
#define srandom srand
#define snprintf _snprintf
typedef int ssize_t;

#ifndef inline
	#define inline __inline
#endif

//typedef long pid_t;
pid_t getpid();
int kill(pid_t pid, int exit_code);

// defined in WinSock2.h
__declspec(dllimport) int __stdcall gethostname(char *buffer, int len);
void usleep(size_t us);



void sleep(size_t ms);

//typedef struct timespec {
//	int tv_sec;
//	int tv_nsec;
//} timespec;

//CLOCK_REALTIME:系统实时时间, 随系统实时时间改变而改变, 即从UTC1970 - 1 - 1 0 : 0 : 0开始计时, 中间时刻如果系统时间被用户该成其他, 则对应的时间相应改变
//CLOCK_MONOTONIC : 从系统启动这一刻起开始计时, 不受系统时间被用户改变的影响
//CLOCK_PROCESS_CPUTIME_ID : 本进程到当前代码系统CPU花费的时间
//CLOCK_THREAD_CPUTIME_ID : 本线程到当前代码系统CPU花费的时间
enum { CLOCK_THREAD_CPUTIME_ID, CLOCK_REALTIME, CLOCK_MONOTONIC };
int clock_gettime(int what, struct timespec *ti);

enum { LOCK_EX, LOCK_NB };
int flock(int fd, int flag);


struct sigaction {
	void (*sa_handler)(int);
	int sa_flags;
	int sa_mask;
};
enum { SIGPIPE, SIGHUP, SA_RESTART };
void sigfillset(int *flag);
void sigaction(int flag, struct sigaction *action, int param);

int pipe(int fd[2]);
int daemon(int a, int b);

char *strsep(char **stringp, const char *delim);

int write(int fd, const void *ptr, size_t sz);
int read(int fd, void *buffer, size_t sz);
int close(int fd);
