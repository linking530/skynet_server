///
/// \file skynet_timer.c
/// \brief 定时器
///
#include "skynet.h"

#include "skynet_timer.h"
#include "skynet_mq.h"
#include "skynet_server.h"
#include "skynet_handle.h"
#include "spinlock.h"

#include <time.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#if defined(__APPLE__) // 苹果平台
#include <sys/time.h>
#endif
// skynet 定时器的实现为linux内核的标准做法  精度为 0.01s 对游戏一般来说够了 高精度的定时器很费CPU
typedef void (*timer_execute_func)(void *ud,void *arg); ///< 函数指针类型


// 对于内核最关心的、interval值在［0，255］
// 内核在处理是否有到期定时器时，它就只从定时器向量数组tv1.vec［256］中的某个定时器向量内进行扫描。
// （2）而对于内核不关心的、interval值在［0xff，0xffffffff］之间的定时器，
// 它们的到期紧迫程度也随其interval值的不同而不同。显然interval值越小，定时器紧迫程度也越高。
// 因此在将它们以松散定时器向量进行组织时也应该区别对待。通常，定时器的interval值越小，
// 它所处的定时器向量的松散度也就越低（也即向量中的各定时器的expires值相差越小）；而interval值越大，
// 它所处的定时器向量的松散度也就越大（也即向量中的各定时器的expires值相差越大）。

// 内核规定，对于那些满足条件：0x100≤interval≤0x3fff的定时器，
// 只要表达式（interval>>8）具有相同值的定时器都将被组织在同一个松散定时器向量中，
// 即以1》8＝256为一个基本单位。因此，为组织所有满足条件0x100≤interval≤0x3fff的定时器，
// 就需要2^6＝64个松散定时器向量。同样地，为方便起见，这64个松散定时器向量也放在一起形成数组，并作为数据结构timer_vec的一部分。
#define TIME_NEAR_SHIFT 8
#define TIME_NEAR (1 << TIME_NEAR_SHIFT)
#define TIME_LEVEL_SHIFT 6
#define TIME_LEVEL (1 << TIME_LEVEL_SHIFT)
#define TIME_NEAR_MASK (TIME_NEAR-1)
#define TIME_LEVEL_MASK (TIME_LEVEL-1)

/// 定时器事件
struct timer_event {
	uint32_t handle; //即是设置定时器的来源，又是超时消息发送的目标
	int session; ///< 会话 ，一个增ID，溢出了从1开始，所以不要设时间很长的timer
};

/// 定时器节点
struct timer_node {
	struct timer_node *next; ///< 下一个定时器节点
	uint32_t expire; ///< 到期时间 超时滴答计数 即超时间隔
};

/// 链表
struct link_list {
	struct timer_node head; ///< 链表头
	struct timer_node *tail; ///< 链表尾
};

///< 定时器
struct timer {
	struct link_list near[TIME_NEAR];//临近的定时器数组
	struct link_list t[4][TIME_LEVEL];//四个级别的定时器数组
	struct spinlock lock;//自旋锁
	uint32_t time; // 当前已经流过的滴答计数
	uint32_t starttime; //程序启动的时间点，timestamp，秒数
	uint64_t current;//从程序启动到现在的耗时，精度10毫秒级 当前时间，相对系统开机时间（相对时间）
	uint64_t current_point;//当前时间，精度10毫秒级
};

static struct timer * TI = NULL;///< 全局定时器指针变量

//清空链表，返回链表第一个结点
/// \param[in] *list
/// \return static inline struct timer_node *
static inline struct timer_node *
link_clear(struct link_list *list) {
	struct timer_node * ret = list->head.next; // 获得链表头的下一个节点
	list->head.next = 0; // 链表头的下一个节点为0
	list->tail = &(list->head);// 链表尾 = 链表头

	return ret;// 返回链表头的下一个节点
}

//将结点放入链表
static inline void
link(struct link_list *list,struct timer_node *node) {
	list->tail->next = node;
	list->tail = node;
	node->next=0;
}

//添加一个定时器结点
/// \param[in] *T
/// \param[in] *node
/// \return static void
static void
add_node(struct timer *T,struct timer_node *node) {
	uint32_t time=node->expire;// 超时的滴答数
	uint32_t current_time=T->time;
	//没有超时，或者说时间点特别近了	
	if ((time|TIME_NEAR_MASK)==(current_time|TIME_NEAR_MASK)) {
		link(&T->near[time&TIME_NEAR_MASK],node);// 将节点添加到对应的链表中
	} else { //这里有一种特殊情况，就是当time溢出，回绕的时候
		int i;
		uint32_t mask=TIME_NEAR << TIME_LEVEL_SHIFT;
		for (i=0;i<3;i++) {
			if ((time|(mask-1))==(current_time|(mask-1))) {
				break;
			}
			mask <<= TIME_LEVEL_SHIFT;
		}

		link(&T->t[i][((time>>(TIME_NEAR_SHIFT + i*TIME_LEVEL_SHIFT)) & TIME_LEVEL_MASK)],node);	
	}
}

/// 添加定时器
/// \param[in] *T
/// \param[in] *arg
/// \param[in] sz
/// \param[in] time
/// \return static void
static void
timer_add(struct timer *T,void *arg,size_t sz,int time) {
	struct timer_node *node = (struct timer_node *)skynet_malloc(sizeof(*node)+sz);
	memcpy(node+1,arg,sz);

	SPIN_LOCK(T);

		node->expire=time+T->time;//超时时间+当前计数
		add_node(T,node);

	SPIN_UNLOCK(T);
}

//移动某个级别的链表内容
static void
move_list(struct timer *T, int level, int idx) {
	struct timer_node *current = link_clear(&T->t[level][idx]);
	while (current) {
		struct timer_node *temp=current->next;
		add_node(T,current);
		current=temp;
	}
}

//这是一个非常重要的函数
//定时器的移动都在这里
static void
timer_shift(struct timer *T) {
	int mask = TIME_NEAR;
	uint32_t ct = ++T->time;
	if (ct == 0) {//time溢出了
		move_list(T, 3, 0);
	} else {
		uint32_t time = ct >> TIME_NEAR_SHIFT;
		int i=0;

		while ((ct & (mask-1))==0) {
			int idx=time & TIME_LEVEL_MASK;
			if (idx!=0) {
				move_list(T, i, idx);
				break;				
			}
			mask <<= TIME_LEVEL_SHIFT;
			time >>= TIME_LEVEL_SHIFT;
			++i;
		}
	}
}

//派发消息到目标服务消息队列
static inline void
dispatch_list(struct timer_node *current) {
	do {
		struct timer_event * event = (struct timer_event *)(current+1);
		struct skynet_message message;
		message.source = 0;
		message.session = event->session;//这个很重要，接收侧靠它来识别是哪个timer
		message.data = NULL;
		message.sz = (size_t)PTYPE_RESPONSE << MESSAGE_TYPE_SHIFT;
		//派发定显示器消息
		skynet_context_push(event->handle, &message);
		
		struct timer_node * temp = current;
		current=current->next;
		skynet_free(temp);	
	} while (current);
}


// 从超时列表中取到时的消息来分发
//派发消息
static inline void
timer_execute(struct timer *T) {
	int idx = T->time & TIME_NEAR_MASK;
	
	while (T->near[idx].head.next) {
		struct timer_node *current = link_clear(&T->near[idx]);
		SPIN_UNLOCK(T);
		// dispatch_list don't need lock T
		dispatch_list(current);
		SPIN_LOCK(T);
	}
}

//时间更新好了以后，这里检查调用各个定时器
// 时间每过一个滴答，执行一次该函数
/// \param[in] *T
/// \return static void
static void 
timer_update(struct timer *T) {
	SPIN_LOCK(T);

	// try to dispatch timeout 0 (rare condition)
	timer_execute(T);

	// shift time first, and then dispatch timer message
	timer_shift(T);

	timer_execute(T);

	SPIN_UNLOCK(T);
}

/// 创建定时器
/// \return static struct timer *
static struct timer *
timer_create_timer() {
	struct timer *r=(struct timer *)skynet_malloc(sizeof(struct timer)); // 分配内存
	memset(r,0,sizeof(*r)); // 清空结构

	int i,j; // 声明变量

	for (i=0;i<TIME_NEAR;i++) { // TIME_NEAR: 1<<8
		link_clear(&r->near[i]); // 清除链表
	}

	for (i=0;i<4;i++) {
		for (j=0;j<TIME_LEVEL;j++) { // TIME_LEVEL: 1<<6
			link_clear(&r->t[i][j]); // 清除链表
		}
	}

	SPIN_INIT(r)

	r->current = 0; // 当前时间

	return r; // 返回定时器的结构
}

/// 超时
/// \param[in] handle
/// \param[in] time
/// \param[in] session
/// \return int
int
skynet_timeout(uint32_t handle, int time, int session) {
	if (time <= 0) {//没有超时
		struct skynet_message message;
		message.source = 0;
		message.session = session;
		message.data = NULL;
		message.sz = (size_t)PTYPE_RESPONSE << MESSAGE_TYPE_SHIFT;
		//没有超时的直接发消息
		if (skynet_context_push(handle, &message)) {
			return -1;
		}
	} else {//有超时
		struct timer_event event;
		event.handle = handle;
		event.session = session;
		//有超时的加入定时器队列中
		timer_add(TI, &event, sizeof(event), time);
	}

	return session;
}

//1秒=1000毫秒 milliseconds
//1毫秒=1000微秒 microseconds
//1微秒=1000纳秒 nanoseconds
//整个timer中毫秒的精度都是10ms，
//也就是说毫秒的一个三个位，但是最小的位被丢弃
// centisecond: 1/100 second
static void
systime(uint32_t *sec, uint32_t *cs) {
#if !defined(__APPLE__)
	struct timespec ti;
	clock_gettime(CLOCK_REALTIME, &ti);
	*sec = (uint32_t)ti.tv_sec;		//把第一个数读出来，那就是从系统启动至今的时间，单位是秒
	*cs = (uint32_t)(ti.tv_nsec / 10000000);//10毫秒为单位
#else
	struct timeval tv;
	gettimeofday(&tv, NULL);
	*sec = tv.tv_sec;			//1970/1/1到现在的秒数
	*cs = tv.tv_usec / 10000;	//微秒转毫秒，精度10ms
#endif
}

// 返回系统开机到现在的时间，单位是百分之一秒 0.01s
static uint64_t
gettime() {
	uint64_t t;
#if !defined(__APPLE__) // 非苹果平台
	struct timespec ti;
	clock_gettime(CLOCK_MONOTONIC, &ti); // 获得时间
	t = (uint64_t)ti.tv_sec * 100;
	t += ti.tv_nsec / 10000000;
#else // 苹果平台
	struct timeval tv;
	gettimeofday(&tv, NULL);
	t = (uint64_t)tv.tv_sec * 100;
	t += tv.tv_usec / 10000;
#endif
	return t; // 返回 t
}

/// 更新时间
/// \param[in] void
/// \return void
void
skynet_updatetime(void) {
	uint64_t cp = gettime();
	if(cp < TI->current_point) {
		skynet_error(NULL, "time diff error: change from %lld to %lld", cp, TI->current_point);
		TI->current_point = cp;
	} else if (cp != TI->current_point) {
		uint32_t diff = (uint32_t)(cp - TI->current_point);
		TI->current_point = cp;
		TI->current += diff;
		int i;
		for (i=0;i<diff;i++) {
			timer_update(TI);
		}
	}
}

uint32_t
skynet_starttime(void) {
	return TI->starttime;
}

uint64_t 
skynet_now(void) {
	return TI->current;
}

/// 定时器初始化
/// \param[in] void
/// \return void
void 
skynet_timer_init(void) {
	TI = timer_create_timer(); // 创建定时器
	uint32_t current = 0;
	systime(&TI->starttime, &current);
	TI->current = current;
	TI->current_point = gettime();
}

