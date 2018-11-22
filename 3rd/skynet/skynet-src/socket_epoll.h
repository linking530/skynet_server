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
//���Է���Skynet��Linux��ʹ���� epoll ���������粢��
//������ӿڣ�fd: �����ļ�������(���)������true��ʾ�д���
/*
17. * ͳһ�Ĵ�����ӿ�.
18. * fd        : �����ļ�������(���)
19. *             : ���� true��ʾ�д���
20. */
static bool 
sp_invalid(int efd) {
	return efd == -1;
}

// ���ڲ���һ�� epoll fd��1024�����������ں˼�������Ŀ���Դ� linux 2.6.8 ֮�󣬸ò����Ǳ����Եģ������������0������ֵ��  
static int
sp_create() {
	return epoll_create(1024);
}

// �ͷ� epoll fd  
static void
sp_release(int efd) {
	close(efd);
}

/*
* ��������fd�����һ��ָ��sock�ļ�����������������socket
* fd    : sp_create() ���صľ��
* sock  : ��������ļ�������, һ��Ϊsocket()���ؽ��
* ud    : �Լ�ʹ�õ�ָ���ַ���⴦��
*       : ����0��ʾ��ӳɹ�, -1��ʾʧ��
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
39. * ɾ�� epoll �м����� fd
40. * fd    : sp_create()������fd
41. * sock  : ��ɾ����fd
42. */
static void 
sp_del(int efd, int sock) {
	epoll_ctl(efd, EPOLL_CTL_DEL, sock , NULL);
}


/*
* ��������fd���޸�sockע������
* fd    : ��ѯ���
* sock  : ������ľ��
* ud    : �û��Զ������ݵ�ַ
* enable: true��ʾ����д, false��ʾ���Ǽ�����
*/
static void 
sp_write(int efd, int sock, void *ud, bool enable) {
	struct epoll_event ev;
	ev.events = EPOLLIN | (enable ? EPOLLOUT : 0);
	ev.data.ptr = ud;
	epoll_ctl(efd, EPOLL_CTL_MOD, sock, &ev);
}

/*
64. * ��ѯ���,�ȴ��н����ʱ���쵱ǰ�û���ṹstruct event �ṹ������
65. * efd   : sp_create()������fd
66. * e     : һ��struct event�ڴ���׵�ַ
67. * max   : e�ڴ��ܹ�ʹ�õ����ֵ
68. *       : ���ؼ������¼���fd������write��read�ֱ��Ӧд�Ͷ��¼�flag��ֵΪtrueʱ��ʾ���¼�����
69. */
static int 
sp_wait(int efd, struct event *e, int max) {
	struct epoll_event ev[max];
	int n = epoll_wait(efd , ev, max, -1);
	int i;
	// ��ָ������ٶȿ�һЩ, ��󷵻صõ��ı仯��n
	for (i=0;i<n;i++) {
		e[i].s = ev[i].data.ptr;
		unsigned flag = ev[i].events;
		e[i].write = (flag & EPOLLOUT) != 0;
		e[i].read = (flag & EPOLLIN) != 0;
	}

	return n;
}

/*
70. * Ϊ�׽�������������Ϊ��������
71. * sock        : �ļ�������
72. */
static void
sp_nonblocking(int fd) {
	//����һ�����Ľ���ID�򸺵Ľ�����ID
	int flag = fcntl(fd, F_GETFL, 0);
	if ( -1 == flag ) {
		return;
	}
	//��ã������ļ�״̬���(cmd=F_GETFL��F_SETFL). 
	fcntl(fd, F_SETFL, flag | O_NONBLOCK);
}

#endif
