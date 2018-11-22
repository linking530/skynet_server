///
/// \file skynet_mq.c
/// \brief 消息队列
///
#include "skynet.h"
#include "skynet_mq.h"
#include "skynet_handle.h"
#include "spinlock.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>

#define DEFAULT_QUEUE_SIZE 64 ///< 默认队列大小
#define MAX_GLOBAL_MQ 0x10000 ///< 最大全局消息队列大小(64K)

// 0 means mq is not in global mq. 不是全局消息队列
// 1 means mq is in global mq , or the message is dispatching. 是全局消息队列或消息正在调度
// 2 means message is dispatching with locked session set. 消息正在调度，和设置会话为锁定。
// 3 means mq is not in global mq, and locked session has been set. 不是全局消息队列，和会话已设置为锁定。
//每个struct message_queue *q都必须在全局队列中
//if (q->in_global == 0) { // 如果在全局标志等于0
//	q->in_global = MQ_IN_GLOBAL; // 设置标志为在全局
//	skynet_globalmq_push(q); // 压入全局消息队列
//}
#define MQ_IN_GLOBAL 1 ///< 在全局队列中
#define MQ_OVERLOAD 1024

/// 消息队列的结构
struct message_queue {
	struct spinlock lock;
	uint32_t handle; ///对应的ctx->handle
	int cap; ///< 队列大小
	int head; ///< 队列头
	int tail; ///< 队列尾
	int release; //队列是否已被释放表示（0为未释放，1为已释放）
	int in_global; //是否存入全局消息队列标志
	int overload;
	int overload_threshold;
	//skynet_message消息队列（其实是一个数组通过queue[序号]从队列中获取指定的消息）
	struct skynet_message *queue; 
	//与其他消息队列的关联（非空表示在全局消息队列中）
	struct message_queue *next;
};

/// 全局队列的结构
struct global_queue {
	struct message_queue *head; ///< 队列头
	struct message_queue *tail; ///< 队列尾
	struct spinlock lock;
};

static struct global_queue *Q = NULL;///< 全局队列的指针变量

/// 压入全局消息队列
/// \param[in] *queue
/// \return static void
void 
skynet_globalmq_push(struct message_queue * queue) {
	struct global_queue *q= Q;// 全局队列

	SPIN_LOCK(q)
	assert(queue->next == NULL);
	if(q->tail) {
		//建立关联关系
		q->tail->next = queue;
		//最后一个压入二级队列指针指向当前压入的二级队列
		q->tail = queue;
	} else {
		//全局队列还为空时，则此时压入的二级队列即使取出队列指针指向地址，
		//也是最后一个压入的队列指针指向地址
		q->head = q->tail = queue;
	}
	SPIN_UNLOCK(q)
}


/// 弹出全局消息队列
/// \return struct message_queue *
struct message_queue * 
skynet_globalmq_pop() {
	struct global_queue *q = Q; // 全局队列

	SPIN_LOCK(q)
	struct message_queue *mq = q->head;
	if(mq) {
		//让取出指针指向全局队列中的下一个二级队列（以备后续继续取出，体现了轮询和公平的机制，每个二级队列轮流被取出）
		q->head = mq->next;
		if(q->head == NULL) {
			//断言方法：判断当前取出的消息队列是否是最后压入的消息队列（true则继续执行，false则停止继续执行）
			assert(mq == q->tail);
			q->tail = NULL;
		}
		//去掉被取出的二级队列与全局队列的关联性
		mq->next = NULL;
	}
	SPIN_UNLOCK(q)

	return mq;// 返回消息队列的指针
}

/// 创建消息队列
/// \param[in] handle
/// \return struct message_queue *
struct message_queue * 
skynet_mq_create(uint32_t handle) {
	struct message_queue *q = skynet_malloc(sizeof(*q)); // 分配内存
	q->handle = handle; // 句柄
	q->cap = DEFAULT_QUEUE_SIZE; // 默认队列大小
	q->head = 0; // 队列头
	q->tail = 0; // 队列尾
	SPIN_INIT(q)
	// When the queue is create (always between service create and service init) ,
	// set in_global flag to avoid push it to global queue .
	// If the service init success, skynet_context_new will call skynet_mq_push to push it to global queue.
	q->in_global = MQ_IN_GLOBAL;
	q->release = 0; // 释放
	q->overload = 0;
	q->overload_threshold = MQ_OVERLOAD;
	q->queue = skynet_malloc(sizeof(struct skynet_message) * q->cap); // 分配cap份内存
	q->next = NULL;

	return q;// 返回消息队列结构的指针
}

/// 释放
/// \param[in] *q
/// \return static void
static void 
_release(struct message_queue *q) {
	assert(q->next == NULL);
	SPIN_DESTROY(q)
	skynet_free(q->queue); // 释放消息队列的队列
	skynet_free(q);// 释放消息队列
}

/// 获得消息队列的句柄
/// \param[in] *q
/// \return uint32_t
uint32_t 
skynet_mq_handle(struct message_queue *q) {
	return q->handle; // 返回句柄的值
}

/// 获得消息队列的长度
/// \param[in] *q
/// \return int
/// 循环队列
int
skynet_mq_length(struct message_queue *q) {
	int head, tail,cap;

	SPIN_LOCK(q) // 加锁
	head = q->head; // 队列头
	tail = q->tail; // 队列尾
	cap = q->cap;   // 默认队列大小
	SPIN_UNLOCK(q) // 解锁
	
	if (head <= tail) { // 如果队列头小于等于队列尾
		return tail - head; // 返回队列尾 - 队列头
	}
	return tail + cap - head; // 否则返回队列尾 + 默认队列大小 - 队列头
}

//// 判断是否过载了
int
skynet_mq_overload(struct message_queue *q) {
	if (q->overload) {
		int overload = q->overload;
		q->overload = 0;
		return overload;
	} 
	return 0;
}

/// 弹出消息队列
/// \param[in] *q
/// \param[in] *message
/// \return int
int
skynet_mq_pop(struct message_queue *q, struct skynet_message *message) {
	int ret = 1; // 失败
	SPIN_LOCK(q) // 锁住

	if (q->head != q->tail) { //判断队列是否为空
		*message = q->queue[q->head++]; // 取出队列头
		ret = 0; // 弹出成功返回0
		int head = q->head;
		int tail = q->tail;
		int cap = q->cap;

		if (head >= cap) { // 如果队列头 >= 最大队列数
			q->head = head = 0; // 队列头 head = 0
		}
		//剩余消息数量统计
		int length = tail - head;
		if (length < 0) {
			length += cap;
		}
		while (length > q->overload_threshold) {
			q->overload = length;
			q->overload_threshold *= 2;
		}
	} else {
		// reset overload_threshold when queue is empty
		q->overload_threshold = MQ_OVERLOAD;
	}

	if (ret) { // 弹出成功
		q->in_global = 0; // 设置在全局状态为0
	}
	
	SPIN_UNLOCK(q) // 解锁

	return ret;
}

/// 扩张队列，将旧队列的数据复制到新队列
/// \param[in] *q
/// \return static void
//默认 q->head == q->tail
static void
expand_queue(struct message_queue *q) {
	struct skynet_message *new_queue = skynet_malloc(sizeof(struct skynet_message) * q->cap * 2); // 分配2倍cap内存
	int i;
	for (i=0;i<q->cap;i++) { // 循环所有
		new_queue[i] = q->queue[(q->head + i) % q->cap]; // 求余数，取出消息
	}
	q->head = 0; // 队列头
	q->tail = q->cap;// 队列尾
	q->cap *= 2; // 队列数
	
	skynet_free(q->queue); // 释放
	q->queue = new_queue; // 返回新的消息队列
}

/// 解锁
/// \param[in] *q
/// \return static void
/// 压入消息队列
/// \param[in] *q
/// \param[in] *message
/// \return void
void 
skynet_mq_push(struct message_queue *q, struct skynet_message *message) {
	assert(message);// 断言 消息是否存在
	SPIN_LOCK(q)// 锁住消息队列
	q->queue[q->tail] = *message; // 将消息压入消息队列的尾
	if (++ q->tail >= q->cap) {// 如果队列尾的值大于等于cap
		q->tail = 0;// 则，队列尾等于0
	}

	if (q->head == q->tail) { // 如果队列头等于队列尾，队列已满
		expand_queue(q);
	}

	if (q->in_global == 0) { // 如果在全局标志等于0
		q->in_global = MQ_IN_GLOBAL; // 设置标志为在全局
		skynet_globalmq_push(q); // 压入全局消息队列
	}
	
	SPIN_UNLOCK(q) // 解锁
}

/// 消息队列初始化
/// \return void
void 
skynet_mq_init() {
	struct global_queue *q = skynet_malloc(sizeof(*q)); // 分配内存
	memset(q,0,sizeof(*q)); // 清空结构
	SPIN_INIT(q);
	Q=q;
}

/// 标志释放消息队列
/// \param[in] *q
/// \return void
void 
skynet_mq_mark_release(struct message_queue *q) {
	SPIN_LOCK(q) // 锁住
	assert(q->release == 0); // assert的作用是现计算表达式 expression ，如果其值为假（即为0），那么它先向stderr打印一条出错信息，然后通过调用 abort 来终止程序运行。
	q->release = 1;
	if (q->in_global != MQ_IN_GLOBAL) { // 标志不为在全局
		skynet_globalmq_push(q); // 压缩全局消息队列
	}
	SPIN_UNLOCK(q) // 解锁
}

/// drop q中的所有数据
/// \param[in] *q
/// \return static int
static void
_drop_queue(struct message_queue *q, message_drop drop_func, void *ud) {
	struct skynet_message msg;
	//如果成功pop则Pop下一个
	while(!skynet_mq_pop(q, &msg)) {
		drop_func(&msg, ud);
	}
	_release(q);
}

/// 释放消息队列
//struct drop_t *d = ud;
//uint32_t source = d->handle;
void 
skynet_mq_release(struct message_queue *q, message_drop drop_func, void *ud) {
	SPIN_LOCK(q)	
	if (q->release) {
		SPIN_UNLOCK(q)
		_drop_queue(q, drop_func, ud);
	} else {
		skynet_globalmq_push(q); // 强行压入消息队列
		SPIN_UNLOCK(q)
	}
}
