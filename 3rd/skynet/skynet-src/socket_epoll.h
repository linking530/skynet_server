#ifndef poll_socket_epoll_h
#define poll_socket_epoll_h

#include <netdb.h>
#include <unistd.h>
#include <sys/epoll.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
//可以发现Skynet在Linux下使用了 epoll 来管理网络并发
//错误检测接口（fd: 检测的文件描述符(句柄)，返回true表示有错误）
/*
17. * 统一的错误检测接口.
18. * fd        : 检测的文件描述符(句柄)
19. *             : 返回 true表示有错误
20. */
static bool 
sp_invalid(int efd) {
	return efd == -1;
}

// 用于产生一个 epoll fd，1024是用来建议内核监听的数目，自从 linux 2.6.8 之后，该参数是被忽略的，即可以填大于0的任意值。  
static int
sp_create() {
	return epoll_create(1024);
}

// 释放 epoll fd  
static void
sp_release(int efd) {
	close(efd);
}

/*
* 在轮序句柄fd中添加一个指定sock文件描述符，用来检测该socket
* fd    : sp_create() 返回的句柄
* sock  : 待处理的文件描述符, 一般为socket()返回结果
* ud    : 自己使用的指针地址特殊处理
*       : 返回0表示添加成功, -1表示失败
*/
static int 
sp_add(int efd, int sock, void *ud) {
	struct epoll_event ev;
	ev.events = EPOLLIN;
	ev.data.ptr = ud;
	if (epoll_ctl(efd, EPOLL_CTL_ADD, sock, &ev) == -1) {
		return 1;
	}
	return 0;
}

/*
39. * 删除 epoll 中监听的 fd
40. * fd    : sp_create()创建的fd
41. * sock  : 待删除的fd
42. */
static void 
sp_del(int efd, int sock) {
	epoll_ctl(efd, EPOLL_CTL_DEL, sock , NULL);
}


/*
* 在轮序句柄fd中修改sock注册类型
* fd    : 轮询句柄
* sock  : 待处理的句柄
* ud    : 用户自定义数据地址
* enable: true表示开启写, false表示还是监听读
*/
static void 
sp_write(int efd, int sock, void *ud, bool enable) {
	struct epoll_event ev;
	ev.events = EPOLLIN | (enable ? EPOLLOUT : 0);
	ev.data.ptr = ud;
	epoll_ctl(efd, EPOLL_CTL_MOD, sock, &ev);
}

/*
64. * 轮询句柄,等待有结果的时候构造当前用户层结构struct event 结构描述中
65. * efd   : sp_create()创建的fd
66. * e     : 一段struct event内存的首地址
67. * max   : e内存能够使用的最大值
68. *       : 返回监听到事件的fd数量，write与read分别对应写和读事件flag，值为true时表示该事件发生
69. */
static int 
sp_wait(int efd, struct event *e, int max) {
	struct epoll_event ev[max];
	int n = epoll_wait(efd , ev, max, -1);
	int i;
	// 用指针遍历速度快一些, 最后返回得到的变化量n
	for (i=0;i<n;i++) {
		e[i].s = ev[i].data.ptr;
		unsigned flag = ev[i].events;
		e[i].write = (flag & EPOLLOUT) != 0;
		e[i].read = (flag & EPOLLIN) != 0;
	}

	return n;
}

/*
70. * 为套接字描述符设置为非阻塞的
71. * sock        : 文件描述符
72. */
static void
sp_nonblocking(int fd) {
	//返回一个正的进程ID或负的进程组ID
	int flag = fcntl(fd, F_GETFL, 0);
	if ( -1 == flag ) {
		return;
	}
	//获得／设置文件状态标记(cmd=F_GETFL或F_SETFL). 
	fcntl(fd, F_SETFL, flag | O_NONBLOCK);
}

#endif
