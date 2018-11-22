///
/// \file skynet_start.c
/// \brief 这个文件用于初始化和启动 Skynet 的核心服务等。
///
#include "skynet.h"
#include "skynet_server.h"
#include "skynet_imp.h"
#include "skynet_mq.h"
#include "skynet_handle.h"
#include "skynet_module.h"
#include "skynet_timer.h"
#include "skynet_monitor.h"
#include "skynet_socket.h"
#include "skynet_daemon.h"
#include "skynet_harbor.h"

#include <pthread.h>
#include <unistd.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

/// 监视的结构
struct monitor {
	int count; ///< 线程总数
	struct skynet_monitor ** m; ///< 结构的指针
	pthread_cond_t cond; ///< 线程条件变量
	pthread_mutex_t mutex; ///< 线程互斥锁
	int sleep; ///< 睡眠
	int quit;
};

struct worker_parm {
	struct monitor *m; ////monitor，监控器，每个线程有一个
	int id; //线程编号
	int weight;////线程权重
};

static int SIG = 0;

static void
handle_hup(int signal) {
	if (signal == SIGHUP) {
		SIG = 1;
	}
}
/// 检查是否中断
///
/// 如果上下文总数为0
#define CHECK_ABORT if (skynet_context_total()==0) break;


/// 创建线程
/// \param[in] *thread 线程结构
/// \param[in] (void *)
/// \param[in] *arg 启动线程的参数
/// \return static void
static void
create_thread(pthread_t *thread, void *(*start_routine) (void *), void *arg) {
	if (pthread_create(thread,NULL, start_routine, arg)) { // 创建线程
		fprintf(stderr, "Create thread failed");
		exit(1);
	}
}

/// 唤醒线程
/// \param[in] monitor *m
/// \param[in] busy
/// \return static void
static void
wakeup(struct monitor *m, int busy) {
	if (m->sleep >= m->count - busy) {
		// signal sleep worker, "spurious wakeup" is harmless
		pthread_cond_signal(&m->cond);// 通过条件变量唤醒线程
	}
}


/// Socket 线程
/// \param[in] *p
/// \return static void
static void *
thread_socket(void *p) {
	struct monitor * m = p;
	skynet_initthread(THREAD_SOCKET);
	for (;;) {
		int r = skynet_socket_poll(); // 查看 Socket 消息
		if (r==0)
			break;
		if (r<0) {
			CHECK_ABORT	// 检查是否中断
			continue;
		}
		wakeup(m,0); // 唤醒线程
	}
	return NULL;
}

/// 释放监视
/// \param[in] monitor *m
/// \return static void
static void
free_monitor(struct monitor *m) {
	int i;
	int n = m->count;
	for (i=0;i<n;i++) {
		skynet_monitor_delete(m->m[i]); // 删除 监视
	}
	pthread_mutex_destroy(&m->mutex); // 销毁互斥锁
	pthread_cond_destroy(&m->cond); // 销毁条件变量
	skynet_free(m->m); // 释放 监视结构中的结构数组
	skynet_free(m); // 释放监视结构
}

/// 监视 线程
/// \param[in] *p
/// \return static void *
static void *
thread_monitor(void *p) {
	struct monitor * m = p;
	int i;
	int n = m->count; // 线程数
	skynet_initthread(THREAD_MONITOR);
	for (;;) {
		CHECK_ABORT	// 检查是否中断
		for (i=0;i<n;i++) {
			skynet_monitor_check(m->m[i]); // 检查 监视
		}
		for (i=0;i<5;i++) {
			CHECK_ABORT // 检查是否中断
			sleep(1); // 睡眠 1秒
		}
	}

	return NULL;
}

static void
signal_hup() {
	// make log file reopen

	struct skynet_message smsg;
	smsg.source = 0;
	smsg.session = 0;
	smsg.data = NULL;
	smsg.sz = (size_t)PTYPE_SYSTEM << MESSAGE_TYPE_SHIFT;
	uint32_t logger = skynet_handle_findname("logger");
	if (logger) {
		skynet_context_push(logger, &smsg);
	}
}
/// 定时器 线程
static void *
thread_timer(void *p) {
	struct monitor * m = p;
	skynet_initthread(THREAD_TIMER);
	for (;;) {
		skynet_updatetime(); // 更新 定时器 的时间
		CHECK_ABORT // 检查是否中断
		wakeup(m,m->count-1); // 唤醒线程
		usleep(2500); // 睡眠 2500 微妙（1秒=1000000微秒）
		if (SIG) {
			signal_hup();
			SIG = 0;
		}
	}
	// wakeup socket thread
	skynet_socket_exit(); // 退出 Socket
	// wakeup all worker thread
	pthread_mutex_lock(&m->mutex);
	m->quit = 1;
	pthread_cond_broadcast(&m->cond); // 广播条件变量
	pthread_mutex_unlock(&m->mutex);
	return NULL;
}

/// 工作 线程
/// \param[in] *p
/// \return static void *
static void *
thread_worker(void *p) {

	struct worker_parm *wp = p;
	int id = wp->id;
	int weight = wp->weight;

	struct monitor *m = wp->m;

	struct skynet_monitor *sm = m->m[id];

	skynet_initthread(THREAD_WORKER);
	struct message_queue * q = NULL;
	while (!m->quit) {
		q = skynet_context_message_dispatch(sm, q, weight); // 调度 Skynet 的上下文消息
		if (q == NULL) {
			if (pthread_mutex_lock(&m->mutex) == 0) { // 加锁
				++ m->sleep;
				// "spurious wakeup" is harmless,
				// because skynet_context_message_dispatch() can be call at any time.
				if (!m->quit)
					pthread_cond_wait(&m->cond, &m->mutex);
				-- m->sleep;
				if (pthread_mutex_unlock(&m->mutex)) { // 解锁
					fprintf(stderr, "unlock mutex error");
					exit(1);
				}
			}
		}
	}
	return NULL;
}

/// 启动线程
/// \param[in] thread 线程数
/// \return static void
static void
start(int thread) {
	pthread_t pid[thread+3]; // 线程编号的数组

	struct monitor *m = skynet_malloc(sizeof(*m)); // 分配 监视 结构的内存
	memset(m, 0, sizeof(*m)); // 清空结构
	m->count = thread;// 线程总数
	m->sleep = 0;// 不睡眠

	m->m = skynet_malloc(thread * sizeof(struct skynet_monitor *));
	int i;
	for (i=0;i<thread;i++) {
						//´´½¨ struct monitor *m£¬×¼±¸Ïß³ÌËø
						/*
						struct skynet_monitor {
							int version;
							int check_version;
							uint32_t source;
							uint32_t destination;
						};
						struct monitor {
							int count;
							struct skynet_monitor ** m;
							pthread_cond_t cond;
							pthread_mutex_t mutex;
							int sleep;
							int quit;
						};
						*/
		m->m[i] = skynet_monitor_new(); // 为每个线程新建一个监视
	}
	if (pthread_mutex_init(&m->mutex, NULL)) { // 初始化互斥锁
		fprintf(stderr, "Init mutex error");
		exit(1);
	}
	if (pthread_cond_init(&m->cond, NULL)) { // 初始化线程条件变量
		fprintf(stderr, "Init cond error");
		exit(1);
	}

	create_thread(&pid[0], thread_monitor, m);    // 创建 监视 线程
	create_thread(&pid[1], thread_timer, m);      // 创建 定时器 线程
	create_thread(&pid[2], thread_socket, m);     // 创建 网络 线程

	static int weight[] = { 
		-1, -1, -1, -1, 0, 0, 0, 0,
		1, 1, 1, 1, 1, 1, 1, 1, 
		2, 2, 2, 2, 2, 2, 2, 2, 
		3, 3, 3, 3, 3, 3, 3, 3, };
	struct worker_parm wp[thread];
	for (i=0;i<thread;i++) {
		wp[i].m = m;
		wp[i].id = i;
		if (i < sizeof(weight)/sizeof(weight[0])) {
			wp[i].weight= weight[i];
		} else {
			wp[i].weight = 0;
		}
		create_thread(&pid[i+3], thread_worker, &wp[i]); // 创建多个工作线程
	}

	for (i=0;i<thread+3;i++) {
		pthread_join(pid[i], NULL); 
	}

	free_monitor(m);
}

static void
bootstrap(struct skynet_context * logger, const char * cmdline) {
	int sz = strlen(cmdline);
	char name[sz+1];
	char args[sz+1];
	sscanf(cmdline, "%s %s", name, args);
	//bootstrap = "snlua bootstrap"   
	//ºÍ¼ÓÔØlogger·þÎñÀàËÆ£¬ÏÈÊÇ°Ñsnlua.soÎÄ¼þ×÷ÎªÄ£¿é¼ÓÔØ½øÀ´£¬µ÷ÓÃÄ£¿é×ÔÉíµÄ_createº¯Êý²úÉúÒ»¸ösnluaÊµÀý£¬ÔÚservice_snlua.cÎÄ¼þÖÐ¡£
	struct skynet_context *ctx = skynet_context_new(name, args); // 加载 master 服务
	if (ctx == NULL) {
		skynet_error(NULL, "Bootstrap error : %s\n", cmdline);
		skynet_context_dispatchall(logger);
		exit(1);
	}
}

/// Skynet 启动
/// \param[in] *config 配置文件名的字符串
/// \return void
void 
skynet_start(struct skynet_config * config) {
	// register SIGHUP for log file reopen
	struct sigaction sa;
	sa.sa_handler = &handle_hup;
	sa.sa_flags = SA_RESTART;
	sigfillset(&sa.sa_mask);
	sigaction(SIGHUP, &sa, NULL);

	//根据配置信息进行一系列初始化
	if (config->daemon) {
		if (daemon_init(config->daemon)) {
			exit(1);
		}
	}
	skynet_harbor_init(config->harbor); // 初始化节点模块，用于集群，转发远程节点的消息
	skynet_handle_init(config->harbor); // 初始化句柄模块，用于给每个Skynet服务创建一个全局唯一的句柄值
	skynet_mq_init(); // 初始化消息队列
	skynet_module_init(config->module_path); // 初始化模块
	skynet_timer_init();// 初始化定时器
	skynet_socket_init(); // 初始化网络
	// config.logservice 为 "logger" config->logger为要写入的log的路径(可无)
	struct skynet_context *ctx = skynet_context_new(config->logservice, config->logger); // 加载日志服务
	if (ctx == NULL) {
		fprintf(stderr, "Can't launch %s service\n", config->logservice);
		exit(1);
	}

	bootstrap(ctx, config->bootstrap);

	start(config->thread);

	// harbor_exit may call socket send, so it should exit before socket_free
	skynet_harbor_exit();
	skynet_socket_free();
	if (config->daemon) {
		daemon_exit(config->daemon);
	}
}
