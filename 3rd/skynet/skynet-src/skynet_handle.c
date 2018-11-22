///
/// \file skynet_handle.c
/*
SKYNET设计综述讲到模块被称为服务。“服务间可以自由发送消息。
每个模块可以向 Skynet 框架注册一个 callback 函数，用来接收发给它的消息。
”还提到“把一个符合规范的 C 模块，从动态库（so 文件）中启动起来，绑定一个永不重复（即使模块退出）的数字 id 做为其 handle 。
Skynet 提供了名字服务，还可以给特定的服务起一个易读的名字，而不是用 id 来指代它。id 和运行时态相关，无法保证每次启动服务，
都有一致的 id ，但名字可以。”今天要分析的两个文件skynet_handle.c和skynet_handle.h就是实现名字服务的。
而WIKI中的CLUSTER讲到的是harbor相关的内容，“每个 skynet 服务都有一个全网唯一的地址，这个地址是一个 32bit 数字，
其高 8bit 标识着它所属 slave 的号码。即 harbor id 。在 master/slave 网络中，
id 为 0 是保留的。所以最多可以有 255 个 slave 节点。”

代码中有个很巧妙的设计，就是s->slot_size-1，它的低位二进制永远都是1。
lot_size是4，4-1就是3，扩了以后是8，8-1就是7，然后16,32....。这样的话，和任何数字与操作，都不会丢失“有效的”低位。
*/

#include "skynet.h"

#include "skynet_handle.h"
#include "skynet_server.h"
#include "rwlock.h"

#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#define DEFAULT_SLOT_SIZE 4
#define MAX_SLOT_SIZE 0x40000000

struct handle_name {
	char * name; //服务名字
	uint32_t handle; //服务ID，下面以handle来称呼
};

struct handle_storage {
	struct rwlock lock; ///< 锁

	uint32_t harbor; ///< 节点 这就是wiki里提到的harbor 
	uint32_t handle_index; ///< 句柄引索 必须从1开始
	int slot_size; ///< 槽的大小,数组长度
	struct skynet_context ** slot; //数组，实际上里面存的是服务的上下文
	
	int name_cap;//名字数组最大容量
	int name_count;//注册了habor名字长度的服务器个数
	struct handle_name *name; ///< 句柄的名字数组
};

static struct handle_storage *H = NULL; ///< 全局结构变量的指针

//注册服务，返回给它一个handle
/// \param[in] *ctx
/// \return uint32_t
uint32_t
skynet_handle_register(struct skynet_context *ctx) {
	struct handle_storage *s = H; // 设置为全局变量

	rwlock_wlock(&s->lock); // 加锁
	
	for (;;) {
		int i;
		for (i=0;i<s->slot_size;i++) { //遍历服务列表，找个空位
			uint32_t handle = (i+s->handle_index) & HANDLE_MASK; //只取后24位
			int hash = handle & (s->slot_size-1);//类似(handle+s->slot_size)%s->slot_size的操作。
			if (s->slot[hash] == NULL) {////没有hash碰撞，好巧
				s->slot[hash] = ctx;
				s->handle_index = handle + 1;//handle_index增加了

				rwlock_wunlock(&s->lock); // 解锁

				handle |= s->harbor;// 位操作或，把harbor前8位，后24位为s->slot[hash] 
				return handle;
			}
		}
		assert((s->slot_size*2 - 1) <= HANDLE_MASK); //slot_size是不是达到0xffffff+1的一半了？
		struct skynet_context ** new_slot = skynet_malloc(s->slot_size * 2 * sizeof(struct skynet_context *)); // 分配内存
		memset(new_slot, 0, s->slot_size * 2 * sizeof(struct skynet_context *)); // 清空结构
		//把老数据拷过来，要重新hash，但是handle_index没增加
		for (i=0;i<s->slot_size;i++) {
			int hash = skynet_context_handle(s->slot[i]) & (s->slot_size * 2 - 1);
			//fprintf(stderr, "reset hash %d %d %d %d\n", skynet_context_handle(s->slot[i]), s->slot_size, hash, i);
			//reset hash 4 4 4 0
			//reset hash 1 4 1 1
			//reset hash 2 4 2 2
			//reset hash 3 4 3 3
			assert(new_slot[hash] == NULL); // 断言
			new_slot[hash] = s->slot[i];
		}
		skynet_free(s->slot); // 释放
		s->slot = new_slot;
		s->slot_size *= 2;
	}
}

/// 收回句柄
/// \param[in] handle
/// \return void
int
skynet_handle_retire(uint32_t handle) {
	int ret = 0;
	struct handle_storage *s = H; // 全局变量

	rwlock_wlock(&s->lock); // 加锁
	//取有效位hash
	uint32_t hash = handle & (s->slot_size-1);
	//取服务上下文，一会儿要释放的
	struct skynet_context * ctx = s->slot[hash];
	//较验这个服务是存在的，而且确实对应的就是这个handle
	if (ctx != NULL && skynet_context_handle(ctx) == handle) {
		s->slot[hash] = NULL;//把空位让出来
		ret = 1;
		int i;
		int j=0, n=s->name_count;
		for (i=0; i<n; ++i) {
			if (s->name[i].handle == handle) {
				skynet_free(s->name[i].name);//释放内存
				continue;
			} else if (i!=j) {//这里在做数组元素删除操作，把后面的都往前移一下
				s->name[j] = s->name[i];
			}
			++j;//元素删除辅助
		}
		s->name_count = j;
	} else {
		ctx = NULL;
	}

	rwlock_wunlock(&s->lock);
	//这里就释放服务了
	if (ctx) {
		// release ctx may call skynet_handle_* , so wunlock first.
		skynet_context_release(ctx);
	}

	return ret;
}

/// 回收所有句柄
/// return void
void 
skynet_handle_retireall() {
	struct handle_storage *s = H;
	for (;;) {
		int n=0;
		int i;
		for (i=0;i<s->slot_size;i++) {
			rwlock_rlock(&s->lock); // 加锁
			struct skynet_context * ctx = s->slot[i];
			uint32_t handle = 0;
			if (ctx)
				handle = skynet_context_handle(ctx);
			rwlock_runlock(&s->lock); // 解锁
			if (handle != 0) {
				if (skynet_handle_retire(handle))// 回收句柄
				 {
					++n;
				}
			}
		}
		if (n==0)
			return;
	}
}

/// 根据handle值返回对应的服务
/// \param[in] handle
/// \return struct skynet_context *
struct skynet_context * 
skynet_handle_grab(uint32_t handle) {
	struct handle_storage *s = H;
	struct skynet_context * result = NULL;

	rwlock_rlock(&s->lock);

	uint32_t hash = handle & (s->slot_size-1);
	struct skynet_context * ctx = s->slot[hash];
	if (ctx && skynet_context_handle(ctx) == handle) {
		result = ctx;
		skynet_context_grab(result);//引用计数+1
	}

	rwlock_runlock(&s->lock);

	return result;
}

/// 根据名字查找句柄
//算法是二分查找法
//二分查找法请自行googe/bing/baidu
/// \param[in] *name
/// \return uint32_t
uint32_t 
skynet_handle_findname(const char * name) {
	struct handle_storage *s = H; // 全局变量

	rwlock_rlock(&s->lock); // 加锁

	uint32_t handle = 0;

	int begin = 0;
	int end = s->name_count - 1;
	while (begin<=end) {
		int mid = (begin+end)/2;
		struct handle_name *n = &s->name[mid];
		int c = strcmp(n->name, name); //strcmp是个c系统函数
		if (c==0) {//找到匹配的名字
			handle = n->handle;
			break;
		}
		if (c<0) {//当前位置的名字 < 要查找的名字，到后半部分去找
			begin = mid + 1;
		} else {//当前位置的名字 > 要查找的名字，到前半部分去找
			end = mid - 1;
		}
	}

	rwlock_runlock(&s->lock);

	return handle;
}

//把name插入到name数组中before位置，再关联handle
/// 在之前插入名字
/// \param[in] *s
/// \param[in] *name
/// \param[in] handle
/// \param[in] before
/// \return static void
static void
_insert_name_before(struct handle_storage *s, char *name, uint32_t handle, int before) {
	//扩容
	if (s->name_count >= s->name_cap) {
		s->name_cap *= 2;//扩容
		assert(s->name_cap <= MAX_SLOT_SIZE);
		struct handle_name * n = skynet_malloc(s->name_cap * sizeof(struct handle_name));//开一个新数组，容量是老数据的2倍
		int i;
		for (i=0;i<before;i++) {//复制before位置前的数据
			n[i] = s->name[i];
		}
		for (i=before;i<s->name_count;i++) {//复制before及后面的数据
			n[i+1] = s->name[i];
		}
		skynet_free(s->name);//把老数据内存回收了
		s->name = n;//把新数组设进来
	} else {
		int i;
		for (i=s->name_count;i>before;i--) {//从后往前，一次一个移动数组元素，把before位置空出来
			s->name[i] = s->name[i-1];
		}
	}
	s->name[before].name = name;
	s->name[before].handle = handle;
	s->name_count ++;
}

//给handle绑定一个name
//name是由小到大顺序排列的
//二分查找法
/// \param[in] *s
/// \param[in] *name
/// \param[in] handle
static const char *
_insert_name(struct handle_storage *s, const char * name, uint32_t handle) {
	int begin = 0;
	int end = s->name_count - 1;
	while (begin<=end) {
		int mid = (begin+end)/2;
		struct handle_name *n = &s->name[mid];
		int c = strcmp(n->name, name);
		if (c==0) {
			return NULL;
		}
		if (c<0) {
			begin = mid + 1;
		} else {
			end = mid - 1;
		}
	}
	char * result = skynet_strdup(name);

	_insert_name_before(s, result, handle, begin);

	return result;
}

///
/// \param[in] handle
/// \param[in] *name
/// \return const char *
const char * 
skynet_handle_namehandle(uint32_t handle, const char *name) {
	rwlock_wlock(&H->lock);

	const char * ret = _insert_name(H, name, handle);

	rwlock_wunlock(&H->lock);

	return ret;
}

/// 初始化句柄
/// \param[in] harbor
/// \return void
//
void 
skynet_handle_init(int harbor) {
	assert(H==NULL); // 断言
	struct handle_storage * s = skynet_malloc(sizeof(*H)); // 分配内存
	s->slot_size = DEFAULT_SLOT_SIZE; // 设置默认槽的大小 =4
	s->slot = skynet_malloc(s->slot_size * sizeof(struct skynet_context *)); // 分配slot_size份内存
	memset(s->slot, 0, s->slot_size * sizeof(struct skynet_context *));

	rwlock_init(&s->lock); // 初始化锁
	// reserve 0 for system harbor放在高8位
	s->harbor = (uint32_t) (harbor & 0xff) << HANDLE_REMOTE_SHIFT;
	s->handle_index = 1;
	s->name_cap = 2;
	s->name_count = 0;
	s->name = skynet_malloc(s->name_cap * sizeof(struct handle_name)); // 分配内存

	H = s; // 设置全局变量

	// Don't need to free H ，不需要释放 H
}

