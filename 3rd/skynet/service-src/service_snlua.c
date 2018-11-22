#include "skynet.h"

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#define MEMORY_WARNING_REPORT (1024 * 1024 * 32)

struct snlua {
	lua_State * L;
	struct skynet_context * ctx;
	size_t mem;
	size_t mem_report;
	size_t mem_limit;
};

// LUA_CACHELIB may defined in patched lua for shared proto
// lua 服务生成器
// lua服务的消息　先到 service_snlua，再分发到lua服务中
// 每个lua服务其实　是一个service_snlua + 实际的lua服务　总和
#ifdef LUA_CACHELIB

#define codecache luaopen_cache

#else

static int
cleardummy(lua_State *L) {
  return 0;
}

//至此，栈中的情况是：  
//=================== 栈顶 ===================   
//  索引  类型      值  
//   4   int：      30   
//   3   string：   shun   
//   2   table:     tbl  
//   1   string:    I am so cool~  
//=================== 栈底 ===================  
static int 
codecache(lua_State *L) {
	luaL_Reg l[] = {
		{ "clear", cleardummy },
		{ "mode", cleardummy },
		{ NULL, NULL },
	};
	//创建一张新的表，并把列表 l 中的函数注册进去。
	luaL_newlib(L,l);
	//把全局变量 name 里的值("loadfile")压栈，返回该值的类型。
	lua_getglobal(L, "loadfile");// 获取函数，压入栈中 
	lua_setfield(L, -2, "loadfile");
	return 1;
}

#endif
// void luaL_traceback (lua_State *L, lua_State *L1, const char *msg,
// int level);
// 将栈 L1 的栈回溯信息压栈。 如果 msg 不为 NULL ，它会附加到栈回溯信息
// 之前。 level 参数指明从第几层开始做栈回溯。
static int 
traceback (lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg)
		luaL_traceback(L, L, msg, 1);
	else {
		lua_pushliteral(L, "(no error message)");
	}
	return 1;
}

static void
report_launcher_error(struct skynet_context *ctx) {
	// sizeof "ERROR" == 5
	skynet_sendname(ctx, 0, ".launcher", PTYPE_TEXT, 0, "ERROR", 5);
}

static const char *
optstring(struct skynet_context *ctx, const char *key, const char * str) {
	const char * ret = skynet_command(ctx, "GETENV", key);
	if (ret == NULL) {
		return str;
	}
	return ret;
}
// lua 状态机的初始化
//在_init方法里设置了一些虚拟机环境变量后，就加载执行了loader.lua文件，
//同时要把真正要加载的文件（这个时候是bootstrap）作为参数传给它，　控制权就开始转到lua层。
//loader.lua是用来加载lua文件的，在loader.lua中会判断是否需要preload，最终会加载执行bootstrap.lua文件：
static int
init_cb(struct snlua *l, struct skynet_context *ctx, const char * args, size_t sz) {
	lua_State *L = l->L;
	l->ctx = ctx;
	lua_gc(L, LUA_GCSTOP, 0);// 调用lua的一系列初始化函数来初始化lua的状态机
	lua_pushboolean(L, 1);  /* signal for libraries to ignore env. vars. */
	lua_setfield(L, LUA_REGISTRYINDEX, "LUA_NOENV");
	luaL_openlibs(L);
	lua_pushlightuserdata(L, ctx);
	lua_setfield(L, LUA_REGISTRYINDEX, "skynet_context");
	luaL_requiref(L, "skynet.codecache", codecache , 0);
	lua_pop(L,1);

	const char *path = optstring(ctx, "lua_path","./lualib/?.lua;./lualib/?/init.lua");
	lua_pushstring(L, path);
	lua_setglobal(L, "LUA_PATH");
	const char *cpath = optstring(ctx, "lua_cpath","./luaclib/?.so");
	lua_pushstring(L, cpath);
	lua_setglobal(L, "LUA_CPATH");
	const char *service = optstring(ctx, "luaservice", "./service/?.lua");
	lua_pushstring(L, service);
	lua_setglobal(L, "LUA_SERVICE");
	const char *preload = skynet_command(ctx, "GETENV", "preload");
	lua_pushstring(L, preload);
	lua_setglobal(L, "LUA_PRELOAD");

	lua_pushcfunction(L, traceback);// 设置了栈回溯函数
	assert(lua_gettop(L) == 1);

	const char * loader = optstring(ctx, "lualoader", "./lualib/loader.lua");

	int r = luaL_loadfile(L,loader);
	if (r != LUA_OK) {
		skynet_error(ctx, "Can't load %s : %s", loader, lua_tostring(L, -1));
		report_launcher_error(ctx);
		return 1;
	}
	lua_pushlstring(L, args, sz);
	r = lua_pcall(L,1,0,1);
	if (r != LUA_OK) {
		skynet_error(ctx, "lua loader error : %s", lua_tostring(L, -1));
		report_launcher_error(ctx);
		return 1;
	}
	lua_settop(L,0);
	if (lua_getfield(L, LUA_REGISTRYINDEX, "memlimit") == LUA_TNUMBER) {
		size_t limit = lua_tointeger(L, -1);
		l->mem_limit = limit;
		skynet_error(ctx, "Set memory limit to %.2f M", (float)limit / (1024 * 1024));
		lua_pushnil(L);
		lua_setfield(L, LUA_REGISTRYINDEX, "memlimit");
	}
	lua_pop(L, 1);

	lua_gc(L, LUA_GCRESTART, 0);

	return 0;
}

static int
launch_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source , const void * msg, size_t sz) {
	assert(type == 0 && session == 0);
	struct snlua *l = ud;
	//这个方法里把自己的回调函数给注销了，使它不再接收消息，为的是在lua层重新注册它，把消息通过lua接口来接收。
	skynet_callback(context, NULL, NULL);
	//_init这里面实际上就是找到要加载的lua文件，然后加载到lua虚拟机中
    //eg:在这里就是把 bootstrap.lua文件加在进来
	int err = init_cb(l, context, msg, sz);
	if (err) {
		skynet_command(context, "EXIT", NULL);
	}

	return 0;
}

int
snlua_init(struct snlua *l, struct skynet_context *ctx, const char * args) {
	int sz = strlen(args);
	char * tmp = skynet_malloc(sz);
	memcpy(tmp, args, sz);
	//注册一个回调函数，当有消息到来时，这个函数会被调用
	//把ctx->cb=_launch, ctx->cb是worker线程取出skynet_message时的处理函数
	skynet_callback(ctx, l , launch_cb);
	//查询自己的handle id
	const char * self = skynet_command(ctx, "REG", NULL);
	uint32_t handle_id = strtoul(self+1, NULL, 16);
	// it must be first message  ,然后在这里立即投递第一个请求
	skynet_send(ctx, 0, handle_id, PTYPE_TAG_DONTCOPY,0, tmp, sz);
	return 0;
}

static void *
lalloc(void * ud, void *ptr, size_t osize, size_t nsize) {
	struct snlua *l = ud;
	size_t mem = l->mem;
	l->mem += nsize;
	if (ptr)
		l->mem -= osize;
	if (l->mem_limit != 0 && l->mem > l->mem_limit) {
		if (ptr == NULL || nsize > osize) {
			l->mem = mem;
			return NULL;
		}
	}
	if (l->mem > l->mem_report) {
		l->mem_report *= 2;
		skynet_error(l->ctx, "Memory warning %.2f M", (float)l->mem / (1024 * 1024));
	}
	return skynet_lalloc(ptr, osize, nsize);
}
// lua服务生成器snlua的实现
struct snlua *
snlua_create(void) {
	struct snlua * l = skynet_malloc(sizeof(*l));
	memset(l,0,sizeof(*l));
	l->mem_report = MEMORY_WARNING_REPORT;
	l->mem_limit = 0;
	l->L = lua_newstate(lalloc, l);// 创建一个新的lua状态机
	return l;
}

void
snlua_release(struct snlua *l) {
	lua_close(l->L);
	skynet_free(l);
}

void
snlua_signal(struct snlua *l, int signal) {
	skynet_error(l->ctx, "recv a signal %d", signal);
	if (signal == 0) {
#ifdef lua_checksig
	// If our lua support signal (modified lua version by skynet), trigger it.
	skynet_sig_L = l->L;
#endif
	} else if (signal == 1) {
		skynet_error(l->ctx, "Current Memory %.3fK", (float)l->mem / 1024);
	}
}
