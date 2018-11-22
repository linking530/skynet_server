///
/// \file skynet_server.c
/// \brief Skynet核心服务
///
#include "skynet.h"

#include "skynet_server.h"
#include "skynet_module.h"
#include "skynet_handle.h"
#include "skynet_mq.h"
#include "skynet_timer.h"
#include "skynet_harbor.h"
#include "skynet_env.h"
#include "skynet_monitor.h"
#include "skynet_imp.h"
#include "skynet_log.h"
#include "spinlock.h"
#include "atomic.h"

#include <pthread.h>

#include <string.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>

#ifdef CALLING_CHECK

#define CHECKCALLING_BEGIN(ctx) if (!(spinlock_trylock(&ctx->calling))) { assert(0); }
#define CHECKCALLING_END(ctx) spinlock_unlock(&ctx->calling);
#define CHECKCALLING_INIT(ctx) spinlock_init(&ctx->calling);
#define CHECKCALLING_DESTROY(ctx) spinlock_destroy(&ctx->calling);
#define CHECKCALLING_DECL struct spinlock calling;

#else
//之所以到处有一些CALLINGCHECK宏，主要是为了检测调度是否正确，
//因为skynet调度时，每个actor只会被一个线程持有调度，也就是消息处理是单线程的。
#define CHECKCALLING_BEGIN(ctx)
#define CHECKCALLING_END(ctx)
#define CHECKCALLING_INIT(ctx)
#define CHECKCALLING_DESTROY(ctx)
#define CHECKCALLING_DECL

#endif

/// Skynet 上下文结构
struct skynet_context {
	void * instance; ///< 实例化
	struct skynet_module * mod; ///< 模块的指针
	void * cb_ud;	//回调函数的用户数据。
	skynet_cb cb;	//回调函数cb
	struct message_queue *queue; //actor的信箱，存放收到的消息。
	FILE * logfile;		//文件句柄，用与录像功能(将所有收到的消息记录与文件).
	char result[32];	//handle的16进制字符，便于传递。
	uint32_t handle;	//8位habor+24位handle_index
	int session_id;		//上一次分配的session,用于分配不重复的session。
	int ref;			//引用计数。
	bool init;			///< 是否成功实例化
	bool endless;		//是否在处理消息时死循环。

	CHECKCALLING_DECL
};

/// Skynet 节点
struct skynet_node {
	int total;
	int init;
	uint32_t monitor_exit;
	pthread_key_t handle_key;//THREAD_MAIN#define THREAD_SOCKET 2 #define THREAD_TIMER 3 #define THREAD_MONITOR 4
};

static struct skynet_node G_NODE;

/// 获得 Context 总数
/// \return int
int 
skynet_context_total() {
	return G_NODE.total;
}

/// Context数 +1
/// \return static void
static void
context_inc() {
	ATOM_INC(&G_NODE.total);
}

/// Context数 -1
/// \return static void
static void
context_dec() {
	ATOM_DEC(&G_NODE.total);
}

///* Types for `void *' pointers.  */
//#if __WORDSIZE == 64
//# ifndef __intptr_t_defined
//typedef long int        intptr_t;
//#  define __intptr_t_defined
//# endif
//typedef unsigned long int   uintptr_t;
//#else
//# ifndef __intptr_t_defined
//typedef int         intptr_t;
//#  define __intptr_t_defined
//# endif
//typedef unsigned int        uintptr_t;
//#endif
/// 获得当前的句柄
/// \param[in] void
/// \return uint32_t
uint32_t 
skynet_current_handle(void) {
	if (G_NODE.init) {
		void * handle = pthread_getspecific(G_NODE.handle_key);
		return (uint32_t)(uintptr_t)handle;
	} else {
		uint32_t v = (uint32_t)(-THREAD_MAIN);
		return v;
	}
}

/// 编号转十六进制字符串
/// \param[out] *str 字符串
/// \param[in] id 服务编号
/// \return static void
static void
id_to_hex(char * str, uint32_t id) {
	int i;
	static char hex[16] = { '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F' };
	str[0] = ':';
	for (i=0;i<8;i++) {
		str[i+1] = hex[(id >> ((7-i) * 4))&0xf];
	}
	str[9] = '\0';
}

struct drop_t {
	uint32_t handle;
};

//释放消息对应的内存，并对消息源发送PTYPE_ERROR消息
static void
drop_message(struct skynet_message *msg, void *ud) {
	struct drop_t *d = ud;
	skynet_free(msg->data);
	uint32_t source = d->handle;
	assert(source);
	// report error to the message source
	skynet_send(NULL, source, msg->source, PTYPE_ERROR, 0, NULL, 0);
}


/// 新建 Context，加载服务模块
/// \param[in] *name 模块的名称
/// \param[in] *param 传递给模块的参数
/// \return struct skynet_context *
struct skynet_context * 
skynet_context_new(const char * name, const char *param) {
	//fprintf(stderr, "skynet_context_new %s %s\n",name,param);
	//skynet_context_new snlua gamed
	//skynet_context_new snlua gate
	// 查询模块数组，找到则直接返回模块结构的指针
	struct skynet_module * mod = skynet_module_query(name);

	if (mod == NULL)// 没找到，则直接返回
		return NULL;
	
	void *inst = skynet_module_instance_create(mod);// 实例化 '_create' 函数
	if (inst == NULL) // 实例化失败，则直接返回
		return NULL;
	
	struct skynet_context * ctx = skynet_malloc(sizeof(*ctx)); // 分配内存
	CHECKCALLING_INIT(ctx)

	ctx->mod = mod; // 模块结构的指针
	ctx->instance = inst; // 实例化 '_create' 函数的指针
	//初始化完成会调用skynet_context_release将引用计数-1，ref变成1而不会被释放掉
	ctx->ref = 2;
	ctx->cb = NULL; // 返回函数
	ctx->cb_ud = NULL;
	ctx->session_id = 0; // 会话编号
	ctx->logfile = NULL;

	ctx->init = false;
	ctx->endless = false;
	// Should set to 0 first to avoid skynet_handle_retireall get an uninitialized handle
	ctx->handle = 0;
	ctx->handle = skynet_handle_register(ctx);
	// 创建 Context 结构中的消息队列
	struct message_queue * queue = ctx->queue = skynet_mq_create(ctx->handle);
	// init function maybe use ctx->handle, so it must init at last
	context_inc(); // Context数 +1

	CHECKCALLING_BEGIN(ctx)
	 // 实例化 '_init' 函数
	int r = skynet_module_instance_init(mod, inst, ctx, param);
	CHECKCALLING_END(ctx)
	if (r == 0) {
		struct skynet_context * ret = skynet_context_release(ctx);// 实例化 '_release' 函数
		if (ret) {
			ctx->init = true;// 实例化 '_init' 成功
		}
		// 强行压入消息队列
		skynet_globalmq_push(queue);
		if (ret) {
			skynet_error(ret, "LAUNCH %s %s", name, param ? param : "");
		}
		return ret;
	} else {
		skynet_error(ctx, "FAILED launch %s", name);
		uint32_t handle = ctx->handle;
		skynet_context_release(ctx);// 释放 Context 结构
		skynet_handle_retire(handle);
		struct drop_t d = { handle };
		skynet_mq_release(queue, drop_message, &d); // 释放 消息队列
		return NULL; // 返回空值
	}
}

/// 新会话
/// \param[in] *ctx
/// \return int 新的会话编号
int
skynet_context_newsession(struct skynet_context *ctx) {
	// session always be a positive number 会话永远是整数
	int session = ++ctx->session_id;
	if (session <= 0) {
		ctx->session_id = 1;
		return 1;
	}
	return session;
}

///
/// \param[in] *ctx
/// \return void
void 
skynet_context_grab(struct skynet_context *ctx) {
	ATOM_INC(&ctx->ref); // 先加再返回
}

void
skynet_context_reserve(struct skynet_context *ctx) {
	skynet_context_grab(ctx);
	// don't count the context reserved, because skynet abort (the worker threads terminate) only when the total context is 0 .
	// the reserved context will be release at last.
	context_dec();
}


/// 删除 Context 结构
/// \param[in] *ctx
/// \return static void
static void 
delete_context(struct skynet_context *ctx) {
	if (ctx->logfile) {
		fclose(ctx->logfile);
	}
	skynet_module_instance_release(ctx->mod, ctx->instance); // 执行模块中的 '_release' 函数
	skynet_mq_mark_release(ctx->queue); // 标记消息队列为释放状态
	CHECKCALLING_DESTROY(ctx)
	skynet_free(ctx); // 释放 Context 结构
	context_dec(); // Context 数 -1
}

/// 释放 Context 结构
/// \param[in] *ctx
/// \return struct skynet_context *
struct skynet_context * 
skynet_context_release(struct skynet_context *ctx) {
	if (ATOM_DEC(&ctx->ref) == 0) {
		delete_context(ctx); // 删除 Context 结构
		return NULL; // 返回空
	}
	return ctx; // 返回结构
}

/// 压入message到Context结构的消息队列
/// \param[in] handle 句柄
/// \param[in] *message 消息结构
/// \return int
int
skynet_context_push(uint32_t handle, struct skynet_message *message) {
	struct skynet_context * ctx = skynet_handle_grab(handle);
	if (ctx == NULL) {
		return -1;
	}
 	// 压入消息队列
	skynet_mq_push(ctx->queue, message);
	// 释放 Context 结构
	skynet_context_release(ctx);

	return 0;
}

///
/// \param[in] handle
/// \return void
void 
skynet_context_endless(uint32_t handle) {
	struct skynet_context * ctx = skynet_handle_grab(handle);
	if (ctx == NULL) {
		return;
	}
	ctx->endless = true;
	skynet_context_release(ctx);
}

///
/// \param[in] *ctx
/// \param[in] handle
/// \param[in] harbor
/// \return int
int 
skynet_isremote(struct skynet_context * ctx, uint32_t handle, int * harbor) {
	int ret = skynet_harbor_message_isremote(handle);
	if (harbor) {
		*harbor = (int)(handle >> HANDLE_REMOTE_SHIFT);
	}
	return ret;
}

/// 消息调度
/// \param[in] *ctx
/// \param[in] *msg
/// \return static void
static void
dispatch_message(struct skynet_context *ctx, struct skynet_message *msg) {
	//判断服务是否已经初始化过（有则继续执行，否则结束）
	assert(ctx->init);
	//开启服务锁住状态
	CHECKCALLING_BEGIN(ctx)
	//将pointer 的值(不是锁指的内容) 与key 相关联
	pthread_setspecific(G_NODE.handle_key, (void *)(uintptr_t)(ctx->handle));
	//从信息的sz字段的高8位获取消息类型信息
	int type = msg->sz >> MESSAGE_TYPE_SHIFT;
	//获得消息的有效数据大小
	size_t sz = msg->sz & MESSAGE_TYPE_MASK;
	//如果开启了录像功能，就将data的数据dump到日志文件
	if (ctx->logfile) {
		skynet_log_output(ctx->logfile, msg->source, type, msg->session, msg->data, sz);
	}
	// 执行服务模块中的返回函数,调用sc的回调函数,根据返回值觉得是否释放data,0释放，1不释放.
	if (!ctx->cb(ctx, ctx->cb_ud, type, msg->session, msg->source, msg->data, sz)) {
		skynet_free(msg->data);// 释放数据
	} 
	CHECKCALLING_END(ctx)
}

/// 调度 Context 消息
/// \param[in] *sm
/// \return int
void 
skynet_context_dispatchall(struct skynet_context * ctx) {
	// for skynet_error
	struct skynet_message msg;
	struct message_queue *q = ctx->queue;
	while (!skynet_mq_pop(q,&msg)) {
		dispatch_message(ctx, &msg);
	}
}

/*
skynet_context_message_dispatch这个函数实际上就是不停地从全局消息队列里取工作队列，
取到了以后呢，就一直处理这个队列里的消息。为了避免某个队列占用太多cpu，当前队列处理到一定的量，
就把机会让给全局消息队列里的其它工作队列，把自己又放回全局消息队列。
而这个处理的量是根据创建线程时thread_param里的weight权重来判定的，权重越大，流转的就越快，
也就是说处理某个队列的消息数量就越少。这就是消息处理的主流程机制。
*/
struct message_queue * 
skynet_context_message_dispatch(struct skynet_monitor *sm, struct message_queue *q, int weight) {
	//判断传入的二级队列是否为空
	if (q == NULL) {
		q = skynet_globalmq_pop();// 从全局队列中弹出消息队列
		if (q==NULL)
			return NULL;
	}
	//消息队列的handle，就是服务的标识
	uint32_t handle = skynet_mq_handle(q);
	//根据handle取出服务上下文，并将ctx引用计数+1
	struct skynet_context * ctx = skynet_handle_grab(handle);
	if (ctx == NULL) {
		struct drop_t d = { handle };
		// 释放消息队列
		skynet_mq_release(q, drop_message, &d);
		//返回global_queue里的下一个message_queue，以供skynet_context_message_dispatch下次调用
		return skynet_globalmq_pop();
	}

	int i,n=1;
	struct skynet_message msg;

	for (i=0;i<n;i++) {
		 // 弹出消息队列
		if (skynet_mq_pop(q,&msg)) {
			skynet_context_release(ctx);//工作队列是空的，ctx引用计数减1
			return skynet_globalmq_pop();//下一个工作队列
		} else if (i==0 && weight >= 0) {////weight:-1只处理一条消息，0处理完q中所有消息，>0处理长度右移weight位(1/(2*weight))条消息
			n = skynet_mq_length(q);
			n >>= weight;	//权重越大，给的处理时间越少
		}
		//取overlad值，然后把mq里的overload设为0
		//就是防止无限打下面这条日志
		int overload = skynet_mq_overload(q);
		if (overload) {
			skynet_error(ctx, "May overload, message queue length = %d", overload);
		}
		//在分析monitor时讲过
		//触发monitor，monitor线程会检查是不是进入死循环
		skynet_monitor_trigger(sm, msg.source , handle);
		//如果服务都没提供回调
		if (ctx->cb == NULL) {
			// 释放数据
			skynet_free(msg.data);
		} else {
			// 调度消息
			dispatch_message(ctx, &msg);
		}

		skynet_monitor_trigger(sm, 0,0);
	}
	//下面这段代码是时间片流转
	//把处理机会让给其它服务
	assert(q == ctx->queue);
    
	struct message_queue *nq = skynet_globalmq_pop();
	if (nq) {
		// 假如全局消息队列不为空，将当前处理的消息队列q放回全局消息队列，并返回下一个消息队列nq
		// 假如全局消息队列是空的或者阻塞,不将当前处理队列q放回全局消息队列,并再次将 q 返回(提供给下一次 dispatch操作)
		// If global mq is not empty , push q back, and return next queue (nq)
		// Else (global mq is empty or block, don't push q back, and return q again (for next dispatch)
		skynet_globalmq_push(q);
		q = nq;
	} 
	skynet_context_release(ctx);//ctx引用计数减1
	return q;
}

/// 复制名称
/// \param[in] name
/// \param[in] *addr
/// \return static void
static void
copy_name(char name[GLOBALNAME_LENGTH], const char * addr) {
	int i;
	for (i=0;i<GLOBALNAME_LENGTH && addr[i];i++) { // 循环每个字符
		name[i] = addr[i]; // 将 addr 复制到 name 中
	}
	for (;i<GLOBALNAME_LENGTH;i++) {
		name[i] = '\0';// 字符串最后 添加 '\0'
	}
}

/*
strtoul() 函数源自于“string to unsigned long”，用来将字符串转换成无符号长整型数(unsigned long)，其原型为：
unsigned long strtoul(const char* str, char** endptr, int base);

【参数说明】str 为要转换的字符串，endstr 为第一个不能转换的字符的指针，base 为字符串 str 所采用的进制。

【函数说明】strtoul() 会将参数 str 字符串根据参数 base 来转换成无符号的长整型数(unsigned long)。
参数 base 范围从2 至36，或0。参数 base 代表 str 采用的进制方式，如 base 值为10 则采用10 进制，若 base 值为16 则采用16 进制数等。

strtoul() 会扫描参数 str 字符串，跳过前面的空白字符（例如空格，tab缩进等，可以通过 isspace() 函数来检测），
直到遇上数字或正负符号才开始做转换，再遇到非数字或字符串结束时('\0')结束转换，并将结果返回。
*/
/// 查询名字
/// \param[in] *context
/// \param[in] *name
/// \return uint32_t
uint32_t 
skynet_queryname(struct skynet_context * context, const char * name) {
	switch(name[0]) { // 取名字的地一个字符
	case ':': // 如果为 ':' 冒号，表示为十六进制编号
		return strtoul(name+1,NULL,16);
	case '.':// 如果为 '.' 点号，表示为名称
		return skynet_handle_findname(name + 1);
	}
	skynet_error(context, "Don't support query global name %s",name);
	return 0;
}

/// 句柄退出
/// \param[in] context
/// \param[in] handle
/// \return static void
static void
handle_exit(struct skynet_context * context, uint32_t handle) {
	if (handle == 0) { // 如果句柄为0
		handle = context->handle;
		skynet_error(context, "KILL self"); // 杀死的是自己
	} else {
		skynet_error(context, "KILL :%0x", handle); // 杀死的是别人
	}
	if (G_NODE.monitor_exit) {
		skynet_send(context,  handle, G_NODE.monitor_exit, PTYPE_CLIENT, 0, NULL, 0);
	}
	skynet_handle_retire(handle);
}

// skynet command
struct command_func {
	const char *name;
	const char * (*func)(struct skynet_context * context, const char * param);
};

static const char *
cmd_timeout(struct skynet_context * context, const char * param) {
	char * session_ptr = NULL;
	int ti = strtol(param, &session_ptr, 10);
	int session = skynet_context_newsession(context);
	skynet_timeout(context->handle, ti, session);
	sprintf(context->result, "%d", session);
	return context->result;
}

//给自身起一个名字（支持多个）
static const char *
cmd_reg(struct skynet_context * context, const char * param) {
	if (param == NULL || param[0] == '\0') {
		sprintf(context->result, ":%x", context->handle);
		return context->result;
	} else if (param[0] == '.') {
		return skynet_handle_namehandle(context->handle, param + 1);
	} else {
		skynet_error(context, "Can't register global name %s in C", param);
		return NULL;
	}
}

//通过名字查找对应的handle，发送消息前先要找到对应的ctx，才能给ctx发送消息
static const char *
cmd_query(struct skynet_context * context, const char * param) {
	if (param[0] == '.') {
		uint32_t handle = skynet_handle_findname(param+1);
		if (handle) {
			sprintf(context->result, ":%x", handle);
			return context->result;
		}
	}
	return NULL;
}

static const char *
cmd_name(struct skynet_context * context, const char * param) {
	int size = strlen(param);
	char name[size+1];
	char handle[size+1];
	sscanf(param,"%s %s",name,handle);
	if (handle[0] != ':') {
		return NULL;
	}
	//将字符串转换成unsigned long(无符号长整型数)
	uint32_t handle_id = strtoul(handle+1, NULL, 16);
	if (handle_id == 0) {
		return NULL;
	}
	if (name[0] == '.') {
		return skynet_handle_namehandle(handle_id, name + 1);
	} else {
		skynet_error(context, "Can't set global name %s in C", name);
	}
	return NULL;
}

static const char *
cmd_exit(struct skynet_context * context, const char * param) {
	handle_exit(context, 0);
	return NULL;
}

static uint32_t
tohandle(struct skynet_context * context, const char * param) {
	uint32_t handle = 0;
	if (param[0] == ':') {
		handle = strtoul(param+1, NULL, 16);
	} else if (param[0] == '.') {
		handle = skynet_handle_findname(param+1);
	} else {
		skynet_error(context, "Can't convert %s to handle",param);
	}

	return handle;
}

static const char *
cmd_kill(struct skynet_context * context, const char * param) {
	uint32_t handle = tohandle(context, param);
	if (handle) {
		handle_exit(context, handle);
	}
	return NULL;
}

/*
char *strsep(char **stringp, const char *delim)
参数1：指向字符串的指针的指针，
参数2：指向字符的指针
功能：以参数2所指的字符作为分界符，将参数1的值所指的字符串分割开，返回值为被参数2分开的左边的那个字符串，
同时会导致参数1的值（指向位置）发生改变，即，
参数1的值会指向分隔符号右边的字符串的起始位置（这一点会比较有用，比如：“1999-12-14”，可以用这个方法很容易的被提取出各个项）！
*/
//cmd_launch，启动一个新服务，最终会通过skynet_context_new创建一个ctx，初始化ctx中各个数据。
static const char *
cmd_launch(struct skynet_context * context, const char * param) {
	size_t sz = strlen(param);
	char tmp[sz+1];
	strcpy(tmp,param);
	char * args = tmp;
	char * mod = strsep(&args, " \t\r\n");
	args = strsep(&args, "\r\n");
	struct skynet_context * inst = skynet_context_new(mod,args);
	if (inst == NULL) {
		return NULL;
	} else {
		id_to_hex(context->result, inst->handle);
		return context->result;
	}
}

static const char *
cmd_getenv(struct skynet_context * context, const char * param) {
	return skynet_getenv(param);
}

static const char *
cmd_setenv(struct skynet_context * context, const char * param) {
	size_t sz = strlen(param);
	char key[sz+1];
	int i;
	for (i=0;param[i] != ' ' && param[i];i++) {
		key[i] = param[i];
	}
	if (param[i] == '\0')
		return NULL;

	key[i] = '\0';
	param += i+1;
	
	skynet_setenv(key,param);
	return NULL;
}

static const char *
cmd_starttime(struct skynet_context * context, const char * param) {
	uint32_t sec = skynet_starttime();
	sprintf(context->result,"%u",sec);
	return context->result;
}

static const char *
cmd_endless(struct skynet_context * context, const char * param) {
	if (context->endless) {
		strcpy(context->result, "1");
		context->endless = false;
		return context->result;
	}
	return NULL;
}

static const char *
cmd_abort(struct skynet_context * context, const char * param) {
	skynet_handle_retireall();
	return NULL;
}

static const char *
cmd_monitor(struct skynet_context * context, const char * param) {
	uint32_t handle=0;
	if (param == NULL || param[0] == '\0') {
		if (G_NODE.monitor_exit) {
			// return current monitor serivce
			sprintf(context->result, ":%x", G_NODE.monitor_exit);
			return context->result;
		}
		return NULL;
	} else {
		handle = tohandle(context, param);
	}
	G_NODE.monitor_exit = handle;
	return NULL;
}

static const char *
cmd_mqlen(struct skynet_context * context, const char * param) {
	int len = skynet_mq_length(context->queue);
	sprintf(context->result, "%d", len);
	return context->result;
}

static const char *
cmd_logon(struct skynet_context * context, const char * param) {
	uint32_t handle = tohandle(context, param);
	if (handle == 0)
		return NULL;
	struct skynet_context * ctx = skynet_handle_grab(handle);
	if (ctx == NULL)
		return NULL;
	FILE *f = NULL;
	FILE * lastf = ctx->logfile;
	if (lastf == NULL) {
		f = skynet_log_open(context, handle);
		if (f) {
			if (!ATOM_CAS_POINTER(&ctx->logfile, NULL, f)) {
				// logfile opens in other thread, close this one.
				fclose(f);
			}
		}
	}
	skynet_context_release(ctx);
	return NULL;
}

static const char *
cmd_logoff(struct skynet_context * context, const char * param) {
	uint32_t handle = tohandle(context, param);
	if (handle == 0)
		return NULL;
	struct skynet_context * ctx = skynet_handle_grab(handle);
	if (ctx == NULL)
		return NULL;
	FILE * f = ctx->logfile;
	if (f) {
		// logfile may close in other thread
		if (ATOM_CAS_POINTER(&ctx->logfile, f, NULL)) {
			skynet_log_close(context, f, handle);
		}
	}
	skynet_context_release(ctx);
	return NULL;
}

//在skynet控制台，可以给指定的ctx发信号以完成相应的命令
static const char *
cmd_signal(struct skynet_context * context, const char * param) {
	uint32_t handle = tohandle(context, param);
	if (handle == 0)
		return NULL;
	struct skynet_context * ctx = skynet_handle_grab(handle);
	if (ctx == NULL)
		return NULL;
	param = strchr(param, ' ');
	int sig = 0;
	if (param) {
		sig = strtol(param, NULL, 0);
	}
	// NOTICE: the signal function should be thread safe.
	skynet_module_instance_signal(ctx->mod, ctx->instance, sig);

	skynet_context_release(ctx);
	return NULL;
}

static struct command_func cmd_funcs[] = {
	{ "TIMEOUT", cmd_timeout },
	{ "REG", cmd_reg },
	{ "QUERY", cmd_query },
	{ "NAME", cmd_name },
	{ "EXIT", cmd_exit },
	{ "KILL", cmd_kill },
	{ "LAUNCH", cmd_launch },
	{ "GETENV", cmd_getenv },
	{ "SETENV", cmd_setenv },
	{ "STARTTIME", cmd_starttime },
	{ "ENDLESS", cmd_endless },
	{ "ABORT", cmd_abort },
	{ "MONITOR", cmd_monitor },
	{ "MQLEN", cmd_mqlen },
	{ "LOGON", cmd_logon },
	{ "LOGOFF", cmd_logoff },
	{ "SIGNAL", cmd_signal },
	{ NULL, NULL },
};

const char * 
skynet_command(struct skynet_context * context, const char * cmd , const char * param) {
	struct command_func * method = &cmd_funcs[0];
	while(method->name) {
		if (strcmp(cmd, method->name) == 0) {
			return method->func(context, param);
		}
		++method;
	}

	return NULL;
}


/*1、(type & PTYPE_TAG_DONTCOPY) == 0
会将data复制一份用作实际发送, 这种情况下原来的data就要由调用者负责释放。

2、(type & PTYPE_TAG_ALLOCSESSION) > 0
会从sc的session计数器分配一个session.

处理完后，type会合并到sz的高8位。
*/
static void
_filter_args(struct skynet_context * context, int type, int *session, void ** data, size_t * sz) {
	int needcopy = !(type & PTYPE_TAG_DONTCOPY);
	int allocsession = type & PTYPE_TAG_ALLOCSESSION;
	type &= 0xff;

	if (allocsession) {
		//*session不为0则断言
		assert(*session == 0);
		*session = skynet_context_newsession(context);
	}

	if (needcopy && *data) {
		char * msg = skynet_malloc(*sz+1);
		memcpy(msg, *data, *sz);
		msg[*sz] = '\0';
		*data = msg;
	}
	//把type打包在sz的高8位*sz |= (size_t)type << MESSAGE_TYPE_SHIFT，
	*sz |= (size_t)type << MESSAGE_TYPE_SHIFT;
}

/// 发送消息给服务
/// \param[in] *context
/// \param[in] source
/// \param[in] destination
/// \param[in] type
/// \param[in] session
/// \param[in] *data
/// \param[in] sz
/// \return int
int
skynet_send(struct skynet_context * context, uint32_t source, uint32_t destination , int type, int session, void * data, size_t sz) {
	if ((sz & MESSAGE_TYPE_MASK) != sz) {
		skynet_error(context, "The message to %x is too large", destination);
		if (type & PTYPE_TAG_DONTCOPY) {
			skynet_free(data);
		}
		return -1;
	}
	_filter_args(context, type, &session, (void **)&data, &sz);

	if (source == 0) {
		source = context->handle;
	}

	if (destination == 0) {
		return session;
	}
	if (skynet_harbor_message_isremote(destination)) {
		struct remote_message * rmsg = skynet_malloc(sizeof(*rmsg));
		rmsg->destination.handle = destination;
		rmsg->message = data;
		rmsg->sz = sz;
		skynet_harbor_send(rmsg, source, session);
	} else {
		struct skynet_message smsg;
		smsg.source = source;
		smsg.session = session;
		smsg.data = data;
		smsg.sz = sz;

		if (skynet_context_push(destination, &smsg)) {
			skynet_free(data);
			return -1;
		}
	}
	return session;
}

/// 根据名称发生消息给服务
/// \param[in] *context
/// \param[in] *addr
/// \param[in] type
/// \param[in] session
/// \param[in] *data
/// \param[in] sz
/// \return int
int
skynet_sendname(struct skynet_context * context, uint32_t source, const char * addr , int type, int session, void * data, size_t sz) {
	if (source == 0) {
		source = context->handle;
	}
	uint32_t des = 0;
	if (addr[0] == ':') {
		des = strtoul(addr+1, NULL, 16);
	} else if (addr[0] == '.') {
		des = skynet_handle_findname(addr + 1);
		if (des == 0) {
			if (type & PTYPE_TAG_DONTCOPY) {
				skynet_free(data);//如果地址不存在，则释放不需要拷贝的消息的内存
			}
			return -1;
		}
	} else {
		_filter_args(context, type, &session, (void **)&data, &sz);

		struct remote_message * rmsg = skynet_malloc(sizeof(*rmsg));
		copy_name(rmsg->destination.name, addr);
		rmsg->destination.handle = 0;
		rmsg->message = data;
		rmsg->sz = sz;

		skynet_harbor_send(rmsg, source, session);
		return session;
	}

	return skynet_send(context, source, des, type, session, data, sz);
}

/// 获得 Context 句柄
/// \param[in] *ctx
/// \return uint32_t
uint32_t 
skynet_context_handle(struct skynet_context *ctx) {
	return ctx->handle;
}

/// 设置服务模块的返回函数
/// \param[in] *context
/// \param[in] *ud
/// \param[in] cb
/// \return void
void 
skynet_callback(struct skynet_context * context, void *ud, skynet_cb cb) {
	context->cb = cb;
	context->cb_ud = ud;
}

///
/// \param[in] *ctx
/// \param[in] *msg
/// \param[in] sz
/// \param[in] source
/// \param[in] type
/// \param[in] session
/// \return void
void
skynet_context_send(struct skynet_context * ctx, void * msg, size_t sz, uint32_t source, int type, int session) {
	struct skynet_message smsg;
	smsg.source = source;
	smsg.session = session;
	smsg.data = msg;
	smsg.sz = sz | (size_t)type << MESSAGE_TYPE_SHIFT;

	skynet_mq_push(ctx->queue, &smsg);
}

	
//初始化当前线程的G_NODE属性
void 
skynet_globalinit(void) {
	G_NODE.total = 0;
	G_NODE.monitor_exit = 0;
	G_NODE.init = 1;

	if (pthread_key_create(&G_NODE.handle_key, NULL)) {
		fprintf(stderr, "pthread_key_create failed");
		exit(1);
	}
	// set mainthread's key
	skynet_initthread(THREAD_MAIN);
}

void 
skynet_globalexit(void) {
	pthread_key_delete(G_NODE.handle_key);
}

void
skynet_initthread(int m) {
	uintptr_t v = (uint32_t)(-m);
	pthread_setspecific(G_NODE.handle_key, (void *)v);
}

