///
/// \file skynet_error.c
/// \brief ������
///
#include "skynet.h"
#include "skynet_handle.h"
#include "skynet_mq.h"
#include "skynet_server.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define LOG_MESSAGE_SIZE 256///< �����־��Ϣ�ĳ���

/// ������
/// \param[in] *context
/// \param[in] *msg
/// \param[in] ...
/// \return void
void 
skynet_error(struct skynet_context * context, const char *msg, ...) {
	static uint32_t logger = 0;
	if (logger == 0) {
		logger = skynet_handle_findname("logger");
	}
	if (logger == 0) {
		return;
	}

	char tmp[LOG_MESSAGE_SIZE];
	char *data = NULL;
	/*
	<Step 1> �ڵ��ò�����֮ǰ������һ�� va_list ���͵ı�����(����va_list ���ͱ���������Ϊap)��

	<Step 2> Ȼ��Ӧ�ö�ap ���г�ʼ��������ָ��ɱ����������ĵ�һ������������ͨ�� va_start ��ʵ�ֵģ�
	         ��һ�������� ap �����ڶ����������ڱ�α�ǰ������ŵ�һ������, ����...��֮ǰ���Ǹ�������

	<Step 3> Ȼ���ǻ�ȡ����������va_arg�����ĵ�һ��������ap���ڶ���������Ҫ��ȡ�Ĳ�����ָ�����ͣ�
	         Ȼ�󷵻����ָ�����͵�ֵ�����Ұ� ap ��λ��ָ���α����һ������λ�ã�

	<Step 4> ��ȡ���еĲ���֮�������б�Ҫ����� ap ָ��ص������ⷢ��Σ�գ������ǵ��� va_end��
	         ��������Ĳ��� ap ��Ϊ NULL��Ӧ�����ɻ�ȡ�������֮��ر�ָ���ϰ�ߡ�
	          ˵���ˣ����������ǵĳ�����н�׳�ԡ�ͨ��va_start��va_end�ǳɶԳ��֡�
	*/
	va_list ap;

	va_start(ap,msg);
	int len = vsnprintf(tmp, LOG_MESSAGE_SIZE, msg, ap);
	va_end(ap);
	if (len >=0 && len < LOG_MESSAGE_SIZE) {
		data = skynet_strdup(tmp);
	} else {/* vsnprintf����ʧ��(n<0)������p�Ŀռ䲻�㹻����size��С���ַ���(n>=size)�������������Ŀռ�*/
		int max_size = LOG_MESSAGE_SIZE;
		for (;;) {
			max_size *= 2;
			data = skynet_malloc(max_size);
			va_start(ap,msg);
			len = vsnprintf(data, max_size, msg, ap);
			va_end(ap);
			if (len < max_size) {
				break;
			}
			skynet_free(data);
		}
	}
	if (len < 0) {
		skynet_free(data);
		perror("vsnprintf error :");
		return;
	}


	struct skynet_message smsg;
	if (context == NULL) {
		smsg.source = 0;
	} else {
		//�����ľ��
		smsg.source = skynet_context_handle(context);
	}
	smsg.session = 0;
	smsg.data = data;
	smsg.sz = len | ((size_t)PTYPE_TEXT << MESSAGE_TYPE_SHIFT);
	skynet_context_push(logger, &smsg);
}

