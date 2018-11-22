///
/// \file skynet_socket.c
/// \brief Socket 封装
///
//对struct skynet_context *ctx对应的socket进行操作
#include "skynet.h"

#include "skynet_socket.h"
#include "socket_server.h"
#include "skynet_server.h"
#include "skynet_mq.h"
#include "skynet_harbor.h"

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

static struct socket_server * SOCKET_SERVER = NULL; ///< 全局变量

/// 初始化 Socket
/// \return void
void 
skynet_socket_init() {
	SOCKET_SERVER = socket_server_create();// 创建 Socket Server
}

/// 退出 Socket
/// \return void
void
skynet_socket_exit() {
	socket_server_exit(SOCKET_SERVER);// 退出 Socket Server
}

/// 释放 Socket
/// \return void
void
skynet_socket_free() {
	socket_server_release(SOCKET_SERVER); // 释放 Socket Server
	SOCKET_SERVER = NULL; // 设置全局变量为空
}

// mainloop thread
/// 转发消息socket_message=》skynet_socket_message=》skynet_message
/// \param[in] type 类型
/// \param[in] padding 是否正在填充
/// \param[in] *result
/// \return static void
static void
forward_message(int type, bool padding, struct socket_message * result) {
	struct skynet_socket_message *sm; // Socket 消息
	size_t sz = sizeof(*sm);
	if (padding) { // 判断是否正在填充状态
		if (result->data) { // 是否有数据
			size_t msg_sz = strlen(result->data);
			if (msg_sz > 128) {
				msg_sz = 128;
			}
			sz += msg_sz;
		} else {
			result->data = "";
		}
	}
	sm = (struct skynet_socket_message *)skynet_malloc(sz); // 分配内存
	sm->type = type; // Socket 消息的类型
	sm->id = result->id; // Socket 的编号
	sm->ud = result->ud;
	if (padding) { // 判断是否正在填充状态
		sm->buffer = NULL; // 设置缓冲为空
		memcpy(sm+1, result->data, sz - sizeof(*sm));
	} else {
		sm->buffer = result->data;
	}

	struct skynet_message message; // Skynet 消息
	message.source = 0; // 来源为 0
	message.session = 0; // 会话为 0
	message.data = sm; // 数据为 Socket 消息
	//将类型 PTYPE_SOCKET 值置于 sz 的高8bit，再赋值给 message.sz  
	//sz的值最大不超过sizeof(struct skynet_socket_message) + 128，该值并不大，高八位并没有值，没有数据覆盖问题。  
	message.sz = sz | ((size_t)PTYPE_SOCKET << MESSAGE_TYPE_SHIFT);
	
	// 将 Skynet 消息压入消息队列
	// 看到 opaque 的作用了吧，其实就是上层handle的标记，按这个标记将信息向上层传递  
	if (skynet_context_push((uint32_t)result->opaque, &message)) {
		// todo: report somewhere to close socket
		// don't call skynet_socket_close here (It will block mainloop)
		skynet_free(sm->buffer);
		skynet_free(sm); //释放消息
	}
}


//skynet_socket_poll会调用 socket_server_poll获得取到的消息类型及消息体，然后根据返回的消息类型，转发消息forward_message。
//1.如果有控制命令，就是在管道中有消息。则会调用 ctrl_cmd进行对应的操作。比如开启、监听、绑定、关闭、打开一个套接字。 
//2.或者根据 epoll_wait 返回的事件，来进行操作。如果是读事件，获取事件的 socket结构，
//  s调用forward_message_tcp(ss, s, &l, result); 进行转发tcp消息。同样会返回一个消息体。

/// 检查 Socket
/// \return int
int 
skynet_socket_poll() {
	struct socket_server *ss = SOCKET_SERVER; // 设为全局变量
	assert(ss); // 断言
	struct socket_message result; // Socket 消息
	int more = 1;
	int type = socket_server_poll(ss, &result, &more); // 查看 Socket 消息
	switch (type) {
	case SOCKET_EXIT: // 退出 Socket
		return 0;
	case SOCKET_DATA: // Socket 数据到来
		forward_message(SKYNET_SOCKET_TYPE_DATA, false, &result);
		break;
	case SOCKET_CLOSE: // 关闭 Socket
		forward_message(SKYNET_SOCKET_TYPE_CLOSE, false, &result);
		break;
	case SOCKET_OPEN: // 打开 Socket
		forward_message(SKYNET_SOCKET_TYPE_CONNECT, true, &result);
		break;
	case SOCKET_ERROR:
		forward_message(SKYNET_SOCKET_TYPE_ERROR, true, &result);
		break;
	case SOCKET_ACCEPT:
		forward_message(SKYNET_SOCKET_TYPE_ACCEPT, true, &result);
		break;
	case SOCKET_UDP:
		forward_message(SKYNET_SOCKET_TYPE_UDP, false, &result);
		break;
	default:
		skynet_error(NULL, "Unknown socket message type %d.",type);
		return -1;
	}
	if (more) {
		return -1;
	}
	return 1;
}

static int
check_wsz(struct skynet_context *ctx, int id, void *buffer, int64_t wsz) {
	if (wsz < 0) {
		return -1;
	} else if (wsz > 1024 * 1024) {
		struct skynet_socket_message tmp;
		tmp.type = SKYNET_SOCKET_TYPE_WARNING;
		tmp.id = id;
		tmp.ud = (int)(wsz / 1024);
		tmp.buffer = NULL;
		skynet_send(ctx, 0, skynet_context_handle(ctx), PTYPE_SOCKET, 0 , &tmp, sizeof(tmp));
//		skynet_error(ctx, "%d Mb bytes on socket %d need to send out", (int)(wsz / (1024 * 1024)), id);
	}
	return 0;
}

int
skynet_socket_send(struct skynet_context *ctx, int id, void *buffer, int sz) {
	int64_t wsz = socket_server_send(SOCKET_SERVER, id, buffer, sz);
	return check_wsz(ctx, id, buffer, wsz);
}

/// 低优先级发送 Socket 数据
/// \param[in] *ctx Skynet上下文结构
/// \param[in] id
/// \param[in] *buffer 数据缓冲区
/// \param[in] sz 数据的大小
/// \return void
void
skynet_socket_send_lowpriority(struct skynet_context *ctx, int id, void *buffer, int sz) {
	socket_server_send_lowpriority(SOCKET_SERVER, id, buffer, sz);
}

/// 监听 Socket
/// \param[in] *ctx
/// \param[in] *host
/// \param[in] port
/// \param[in] backlog
/// \return int
int 
skynet_socket_listen(struct skynet_context *ctx, const char *host, int port, int backlog) {
	uint32_t source = skynet_context_handle(ctx);
	return socket_server_listen(SOCKET_SERVER, source, host, port, backlog);
}

/// Socket 连接
/// \param[in] *ctx
/// \param[in] *host
/// \param[in] port
/// \return int
int 
skynet_socket_connect(struct skynet_context *ctx, const char *host, int port) {
	uint32_t source = skynet_context_handle(ctx);
	return socket_server_connect(SOCKET_SERVER, source, host, port);
}

int 
/// 绑定事件
/// \param[in] *ctx
/// \param[in] fd
/// \return int
skynet_socket_bind(struct skynet_context *ctx, int fd) {
	uint32_t source = skynet_context_handle(ctx);
	return socket_server_bind(SOCKET_SERVER, source, fd);
}

/// 关闭 Socket
/// \param[in] *ctx
/// \param[in] id
/// \return void
void 
skynet_socket_close(struct skynet_context *ctx, int id) {
	uint32_t source = skynet_context_handle(ctx);
	socket_server_close(SOCKET_SERVER, source, id);
}

void 
skynet_socket_shutdown(struct skynet_context *ctx, int id) {
	uint32_t source = skynet_context_handle(ctx);
	socket_server_shutdown(SOCKET_SERVER, source, id);
}

/// 启动 Socket
/// \param[in] *ctx
/// \param[in] id
/// \return voids
void 
skynet_socket_start(struct skynet_context *ctx, int id) {
	uint32_t source = skynet_context_handle(ctx);
	socket_server_start(SOCKET_SERVER, source, id);
}

void
skynet_socket_nodelay(struct skynet_context *ctx, int id) {
	socket_server_nodelay(SOCKET_SERVER, id);
}

int 
skynet_socket_udp(struct skynet_context *ctx, const char * addr, int port) {
	uint32_t source = skynet_context_handle(ctx);
	return socket_server_udp(SOCKET_SERVER, source, addr, port);
}

int 
skynet_socket_udp_connect(struct skynet_context *ctx, int id, const char * addr, int port) {
	return socket_server_udp_connect(SOCKET_SERVER, id, addr, port);
}

int 
skynet_socket_udp_send(struct skynet_context *ctx, int id, const char * address, const void *buffer, int sz) {
	int64_t wsz = socket_server_udp_send(SOCKET_SERVER, id, (const struct socket_udp_address *)address, buffer, sz);
	return check_wsz(ctx, id, (void *)buffer, wsz);
}

const char *
skynet_socket_udp_address(struct skynet_socket_message *msg, int *addrsz) {
	if (msg->type != SKYNET_SOCKET_TYPE_UDP) {
		return NULL;
	}
	struct socket_message sm;
	sm.id = msg->id;
	sm.opaque = 0;
	sm.ud = msg->ud;
	sm.data = msg->buffer;
	return (const char *)socket_server_udp_address(SOCKET_SERVER, &sm, addrsz);
}
