#ifndef socket_poll_h
#define socket_poll_h

#include <stdbool.h>
//统一使用的句柄类型
typedef int poll_fd;

struct event {
	void * s;//通知的句柄
	bool read;//true表示可读
	bool write;//true表示可写
};

static bool sp_invalid(poll_fd fd);
static poll_fd sp_create();
static void sp_release(poll_fd fd);
// 添加一个新的socket句柄
static int sp_add(poll_fd fd, int sock, void *ud);
// 删除对一个socket句柄的维护
static void sp_del(poll_fd fd, int sock);
// 对一个socket句柄的write熟悉进入维护
static void sp_write(poll_fd, int sock, void *ud, bool enable);
// 询问当前的触发事件
static int sp_wait(poll_fd, struct event *e, int max);
// 设置一个socket为非阻塞。
static void sp_nonblocking(int sock);

#ifdef __linux__
#include "socket_epoll.h"
#endif

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined (__NetBSD__)
#include "socket_kqueue.h"
#endif

#endif
