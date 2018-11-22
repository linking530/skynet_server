///
/// \file skynet_monitor.c
/// \brief ����ļ�����
///
//skynet_monitor��Ҫ���ڼ��skynet_context�ڴ�����Ϣʱ�Ƿ�������ѭ����
#include "skynet.h"

#include "skynet_monitor.h"
#include "skynet_server.h"
#include "skynet.h"
#include "atomic.h"

#include <stdlib.h>
#include <string.h>

/// ���ӵĽṹ
struct skynet_monitor {
	int version;            ///< �汾
	int check_version;      ///< ���汾
	uint32_t source;        ///< ��Դ
	uint32_t destination;   ///< Ŀ��
};

/// �½�����
/// \return struct skynet_monitor *
struct skynet_monitor * 
skynet_monitor_new() {
	struct skynet_monitor * ret = skynet_malloc(sizeof(*ret));// ���ṹ�����ڴ�
	memset(ret, 0, sizeof(*ret)); // ��սṹ
	return ret;
}

/// ɾ������
/// \param[in] *sm ���ӵĽṹ
/// \return void
void 
skynet_monitor_delete(struct skynet_monitor *sm) {
	skynet_free(sm);// �ͷŽṹ������ڴ�
}

/// �������
/// \param[in] *sm
/// \param[in] source
/// \param[in] destination
/// \return void
void 
skynet_monitor_trigger(struct skynet_monitor *sm, uint32_t source, uint32_t destination) {
	sm->source = source;// ��Դ
	sm->destination = destination;// Ŀ��
	ATOM_INC(&sm->version);
}

/// �����
/// \param[in] *sm
/// \return void
void 
skynet_monitor_check(struct skynet_monitor *sm) {
	if (sm->version == sm->check_version) {// ����汾���ڼ��汾
		if (sm->destination) {// Ŀ���Ƿ����
			skynet_context_endless(sm->destination);
			skynet_error(NULL, "A message from [ :%08x ] to [ :%08x ] maybe in an endless loop (version = %d)", sm->source , sm->destination, sm->version);
		}
	} else {// ������汾���ڰ汾
		sm->check_version = sm->version;
	}
}
