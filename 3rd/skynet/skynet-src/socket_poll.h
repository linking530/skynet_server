#ifndef socket_poll_h
#define socket_poll_h

#include <stdbool.h>
//ͳһʹ�õľ������
typedef int poll_fd;

struct event {
	void * s;//֪ͨ�ľ��
	bool read;//true��ʾ�ɶ�
	bool write;//true��ʾ��д
};

static bool sp_invalid(poll_fd fd);
static poll_fd sp_create();
static void sp_release(poll_fd fd);
// ���һ���µ�socket���
static int sp_add(poll_fd fd, int sock, void *ud);
// ɾ����һ��socket�����ά��
static void sp_del(poll_fd fd, int sock);
// ��һ��socket�����write��Ϥ����ά��
static void sp_write(poll_fd, int sock, void *ud, bool enable);
// ѯ�ʵ�ǰ�Ĵ����¼�
static int sp_wait(poll_fd, struct event *e, int max);
// ����һ��socketΪ��������
static void sp_nonblocking(int sock);

#ifdef __linux__
#include "socket_epoll.h"
#endif

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined (__NetBSD__)
#include "socket_kqueue.h"
#endif

#endif
