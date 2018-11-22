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
//pid=1����init���ں����֮�������ĵ�һ�����̣�Ȼ��init����/etc/inittab��������ȥ������������ 
//0 == pid
	if (n !=1 || pid == 0 || pid == getpid()) {
		return 0;
	}

//pid������ѡ������������
//
//	1. pid������ʱ��pid���ź��������Ľ��̵ı�ʶ��
//	2. pid������ʱ���źŽ��������������kill()���Ǹ�������ͬһ��ʹ����Ľ��̡�
//	3. pid���� - 1ʱ���źŽ��������е��ý�����Ȩ���䷢���źŵĽ��̣����˽���1(init)��
//	4. pidС�� - 1ʱ���źŽ������� - pidΪ���ʶ�Ľ��̡�
//
//	sig��׼�����͵��źŴ��룬������ֵΪ����û���κ��ź��ͳ�������ϵͳ��ִ�д����飬ͨ��������sigֵΪ��������ĳ�������Ƿ�����ִ�С�
//
//	����ֵ˵���� �ɹ�ִ��ʱ������0��ʧ�ܷ��� - 1��errno����Ϊ���µ�ĳ��ֵ EINVAL��ָ�����ź�����Ч������ sig ���Ϸ��� EPERM��Ȩ�޲����޷������źŸ�ָ������ ESRCH������ pid ��ָ���Ľ��̻�����鲻����
//ESRCH No such process
	if (kill(pid, 0) && errno == ESRCH)
		return 0;

	return pid;
}

static int 
write_pid(const char *pidfile) {
	FILE *f;
	int pid = 0;
	//�Կɶ�д��ʽ���ļ������û���򴴽��ļ�
	int fd = open(pidfile, O_RDWR|O_CREAT, 0644);
	if (fd == -1) {
		fprintf(stderr, "Can't create %s.\n", pidfile);
		return 0;
	}
	//�ļ�������ת���ļ�ָ��
	f = fdopen(fd, "r+");
	if (f == NULL) {
		fprintf(stderr, "Can't open %s.\n", pidfile);
		return 0;
	}
	//�����ļ����޷���������ʱ���˲����ɲ�����ϣ�-1,���ش���
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
	//���»�����
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
	//unlink()��ɾ������pathnameָ�����ļ���
	//������ļ���Ϊ������ӵ㣬�����������̴��˴��ļ����������й��ڴ��ļ����ļ������ʽԹرպ�Ż�ɾ����
	//�������pathnameΪһ�������ӣ�������ӻᱻɾ����
	return unlink(pidfile);
}
