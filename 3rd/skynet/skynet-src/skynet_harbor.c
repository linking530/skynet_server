///
/// \file skynet_harbor.c
/// \brief �ڵ����
///
#include "skynet.h"
#include "skynet_harbor.h"
#include "skynet_server.h"
#include "skynet_mq.h"
#include "skynet_handle.h"

#include <string.h>
#include <stdio.h>
#include <assert.h>

static struct skynet_context * REMOTE = 0;///< Զ�̽ڵ�� Context �ṹָ��
static unsigned int HARBOR = ~0;///< �ڵ��ȫ�ֱ���

// ������Ϣ��ͬʱ���Ϸ����ߵ�id
/// \param[in] *rmsg
/// \param[in] source
/// \param[in] session
/// \return void
void 
skynet_harbor_send(struct remote_message *rmsg, uint32_t source, int session) {
	//ͨ����sz������24λ��ȡ��8λ�Ļ���ʶ����
	int type = rmsg->sz >> HANDLE_REMOTE_SHIFT;
	//��ͨ����0xffffff������ȡ��24λ��id
	rmsg->sz &= HANDLE_MASK;
	assert(type != PTYPE_SYSTEM && type != PTYPE_HARBOR); // ����

	// ������Ϣ
	skynet_context_send(REMOTE, rmsg, sizeof(*rmsg) , source, type , session);
}

/// �ڵ���Ϣ�Ƿ�ΪԶ��
//// ������������ж���Ϣ�����Ա����������ⲿ����
//�����ü򵥵��ж��㷨�Ϳ���֪��һ�� id ��Զ�� id ���Ǳ��� id ��ֻ��Ҫ�Ƚϸ� 8 λ�Ϳ����ˣ�����
/// \param[in] handle
/// \return int
int 
skynet_harbor_message_isremote(uint32_t handle) {
	assert(HARBOR != ~0);
	int h = (handle & ~HANDLE_MASK);
	return h != HARBOR && h !=0;
}

/// ��ʼ���ڵ�
/// \param[in] harbor
/// \return void
void
skynet_harbor_init(int harbor) {
	HARBOR = (unsigned int)harbor << HANDLE_REMOTE_SHIFT;// ����24λ�����ýڵ���
}

/// �����ڵ�
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
