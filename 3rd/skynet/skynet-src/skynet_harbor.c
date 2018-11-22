///
/// \file skynet_harbor.c
/// \brief 节点服务
///
#include "skynet.h"
#include "skynet_harbor.h"
#include "skynet_server.h"
#include "skynet_mq.h"
#include "skynet_handle.h"

#include <string.h>
#include <stdio.h>
#include <assert.h>

static struct skynet_context * REMOTE = 0;///< 远程节点的 Context 结构指针
static unsigned int HARBOR = ~0;///< 节点的全局变量

// 发送消息，同时带上发送者的id
/// \param[in] *rmsg
/// \param[in] source
/// \param[in] session
/// \return void
void 
skynet_harbor_send(struct remote_message *rmsg, uint32_t source, int session) {
	//通过将sz向右移24位来取高8位的机器识别码
	int type = rmsg->sz >> HANDLE_REMOTE_SHIFT;
	//而通过与0xffffff相与来取低24位的id
	rmsg->sz &= HANDLE_MASK;
	assert(type != PTYPE_SYSTEM && type != PTYPE_HARBOR); // 断言

	// 发送消息
	skynet_context_send(REMOTE, rmsg, sizeof(*rmsg) , source, type , session);
}

/// 节点消息是否为远程
//// 这个函数用来判断消息是来自本机器还是外部机器
//我们用简单的判断算法就可以知道一个 id 是远程 id 还是本地 id （只需要比较高 8 位就可以了）。”
/// \param[in] handle
/// \return int
int 
skynet_harbor_message_isremote(uint32_t handle) {
	assert(HARBOR != ~0);
	int h = (handle & ~HANDLE_MASK);
	return h != HARBOR && h !=0;
}

/// 初始化节点
/// \param[in] harbor
/// \return void
void
skynet_harbor_init(int harbor) {
	HARBOR = (unsigned int)harbor << HANDLE_REMOTE_SHIFT;// 左移24位，设置节点编号
}

/// 启动节点
/// \param[in] *master
/// \param[in] *local
/// \return int
void
skynet_harbor_start(void *ctx) {
	// the HARBOR must be reserved to ensure the pointer is valid.
	// It will be released at last by calling skynet_harbor_exit
	skynet_context_reserve(ctx);
	REMOTE = ctx;
}

void
skynet_harbor_exit() {
	struct skynet_context * ctx = REMOTE;
	REMOTE= NULL;
	if (ctx) {
		skynet_context_release(ctx);
	}
}
