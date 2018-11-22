#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/file.h>
#include <signal.h>
#include <errno.h>
#include <stdlib.h>

#include "skynet_daemon.h"

static int
check_pid(const char *pidfile) {
	int pid = 0;
	FILE *f = fopen(pidfile,"r");
	if (f == NULL)
		return 0;
	int n = fscanf(f,"%d", &pid);
	fclose(f);
//pid=1的是init，内核完成之后启动的第一个进程，然后init根据/etc/inittab的内容再去启动其它进程 
//0 == pid
	if (n !=1 || pid == 0 || pid == getpid()) {
		return 0;
	}

//pid：可能选择有以下四种
//
//	1. pid大于零时，pid是信号欲送往的进程的标识。
//	2. pid等于零时，信号将送往所有与调用kill()的那个进程属同一个使用组的进程。
//	3. pid等于 - 1时，信号将送往所有调用进程有权给其发送信号的进程，除了进程1(init)。
//	4. pid小于 - 1时，信号将送往以 - pid为组标识的进程。
//
//	sig：准备发送的信号代码，假如其值为零则没有任何信号送出，但是系统会执行错误检查，通常会利用sig值为零来检验某个进程是否仍在执行。
//
//	返回值说明： 成功执行时，返回0。失败返回 - 1，errno被设为以下的某个值 EINVAL：指定的信号码无效（参数 sig 不合法） EPERM；权限不够无法传送信号给指定进程 ESRCH：参数 pid 所指定的进程或进程组不存在
//ESRCH No such process
	if (kill(pid, 0) && errno == ESRCH)
		return 0;

	return pid;
}

static int 
write_pid(const char *pidfile) {
	FILE *f;
	int pid = 0;
	//以可读写方式打开文件，如果没有则创建文件
	int fd = open(pidfile, O_RDWR|O_CREAT, 0644);
	if (fd == -1) {
		fprintf(stderr, "Can't create %s.\n", pidfile);
		return 0;
	}
	//文件描述符转成文件指针
	f = fdopen(fd, "r+");
	if (f == NULL) {
		fprintf(stderr, "Can't open %s.\n", pidfile);
		return 0;
	}
	//锁定文件，无法建立锁定时，此操作可不被阻断，-1,返回错误
	if (flock(fd, LOCK_EX|LOCK_NB) == -1) {
		int n = fscanf(f, "%d", &pid);
		fclose(f);
		if (n != 1) {
			fprintf(stderr, "Can't lock and read pidfile.\n");
		} else {
			fprintf(stderr, "Can't lock pidfile, lock is held by pid %d.\n", pid);
		}
		return 0;
	}
	
	pid = getpid();
	if (!fprintf(f,"%d\n", pid)) {
		fprintf(stderr, "Can't write pid.\n");
		close(fd);
		return 0;
	}
	//更新缓冲区
	fflush(f);

	return pid;
}

int
daemon_init(const char *pidfile) {
	int pid = check_pid(pidfile);

	if (pid) {
		fprintf(stderr, "Skynet is already running, pid = %d.\n", pid);
		return 1;
	}

#ifdef __APPLE__
	fprintf(stderr, "'daemon' is deprecated: first deprecated in OS X 10.5 , use launchd instead.\n");
#else
	if (daemon(1,0)) {
		fprintf(stderr, "Can't daemonize.\n");
		return 1;
	}
#endif

	pid = write_pid(pidfile);
	if (pid == 0) {
		return 1;
	}

	return 0;
}

int 
daemon_exit(const char *pidfile) {
	//unlink()会删除参数pathname指定的文件。
	//如果该文件名为最后连接点，但有其他进程打开了此文件，则在所有关于此文件的文件描述词皆关闭后才会删除。
	//如果参数pathname为一符号连接，则此连接会被删除。
	return unlink(pidfile);
}
