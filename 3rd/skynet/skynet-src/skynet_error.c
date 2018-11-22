///
/// \file skynet_error.c
/// \brief 错误处理
///
#include "skynet.h"
#include "skynet_handle.h"
#include "skynet_mq.h"
#include "skynet_server.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define LOG_MESSAGE_SIZE 256///< 最大日志消息的长度

/// 错误处理
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
	<Step 1> 在调用参数表之前，定义一个 va_list 类型的变量，(假设va_list 类型变量被定义为ap)；

	<Step 2> 然后应该对ap 进行初始化，让它指向可变参数表里面的第一个参数，这是通过 va_start 来实现的，
	         第一个参数是 ap 本身，第二个参数是在变参表前面紧挨着的一个变量, 即“...”之前的那个参数；

	<Step 3> 然后是获取参数，调用va_arg，它的第一个参数是ap，第二个参数是要获取的参数的指定类型，
	         然后返回这个指定类型的值，并且把 ap 的位置指向变参表的下一个变量位置；

	<Step 4> 获取所有的参数之后，我们有必要将这个 ap 指针关掉，以免发生危险，方法是调用 va_end，
	         他是输入的参数 ap 置为 NULL，应该养成获取完参数表之后关闭指针的习惯。
	          说白了，就是让我们的程序具有健壮性。通常va_start和va_end是成对出现。
	*/
	va_list ap;

	va_start(ap,msg);
	int len = vsnprintf(tmp, LOG_MESSAGE_SIZE, msg, ap);
	va_end(ap);
	if (len >=0 && len < LOG_MESSAGE_SIZE) {
		data = skynet_strdup(tmp);
	} else {/* vsnprintf调用失败(n<0)，或者p的空间不足够容纳size大小的字符串(n>=size)，尝试申请更大的空间*/
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
		//上下文句柄
		smsg.source = skynet_context_handle(context);
	}
	smsg.session = 0;
	smsg.data = data;
	smsg.sz = len | ((size_t)PTYPE_TEXT << MESSAGE_TYPE_SHIFT);
	skynet_context_push(logger, &smsg);
}

