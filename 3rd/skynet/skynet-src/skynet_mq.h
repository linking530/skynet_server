#ifndef SKYNET_MESSAGE_QUEUE_H
#define SKYNET_MESSAGE_QUEUE_H

#include <stdlib.h>
#include <stdint.h>

struct skynet_message {
	uint32_t source;        // 消息源(sc)的句柄。
	int session;            // 用来做上下文的标识
	void * data;            // 消息指针
	size_t sz;              // 数据的长度,消息的请求类型定义在高8位
};

// type is encoding in skynet_message.sz high 8bit
//在64位系统中sizeof(size_t)值是8，32位系统中是4。
//SIZE_MAX定义于stdint.h中，表示size_t类型的最大值，64位系统中，SIZE_MAX值为2^64-1，32位系统中值为2^32-1。
#define MESSAGE_TYPE_MASK (SIZE_MAX >> 8)	//	SIZE_MAX=0xffffffff	右移8位=》	0x00ffffff
#define MESSAGE_TYPE_SHIFT ((sizeof(size_t)-1) * 8) //32位位移24，64位位移56位

struct message_queue;

void skynet_globalmq_push(struct message_queue * queue);
struct message_queue * skynet_globalmq_pop(void); // 弹出全局消息队列

struct message_queue * skynet_mq_create(uint32_t handle); // 创建消息队列
void skynet_mq_mark_release(struct message_queue *q); // 标记释放消息队列

typedef void (*message_drop)(struct skynet_message *, void *);

void skynet_mq_release(struct message_queue *q, message_drop drop_func, void *ud); // 释放消息队列
uint32_t skynet_mq_handle(struct message_queue *); // 消息队列的句柄

// 0 for success
int skynet_mq_pop(struct message_queue *q, struct skynet_message *message); // 弹出消息队列
void skynet_mq_push(struct message_queue *q, struct skynet_message *message); // 压入消息队列

// return the length of message queue, for debug
int skynet_mq_length(struct message_queue *q); // 消息队列的长度
int skynet_mq_overload(struct message_queue *q);

void skynet_mq_init(); // 初始化消息队列

#endif
