#include "skynet.h"
#include "skynet_env.h"
#include "spinlock.h"

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <assert.h>

struct skynet_env {
	struct spinlock lock;
	lua_State *L;
};

// skynet 环境配置 主要是获取和设置lua的环境变量
static struct skynet_env *E = NULL;

const char * 
skynet_getenv(const char *key) { // 获取的是 lua 的全局变量 key 值
	SPIN_LOCK(E)

	lua_State *L = E->L;
	
	lua_getglobal(L, key);						// 获取lua全局变量key的值,并压入lua栈
	const char * result = lua_tostring(L, -1);	// 从lua栈中弹出该变量值并赋值给result
	lua_pop(L, 1);								// 弹出该变量值

	SPIN_UNLOCK(E)

	return result;
}

void 
skynet_setenv(const char *key, const char *value) {
	SPIN_LOCK(E)
	
	lua_State *L = E->L;
	lua_getglobal(L, key);		// 获取lua全局变量key的值,并压入lua栈
	assert(lua_isnil(L, -1));	// 断言该变量值一定是空的

	lua_pop(L,1);				// 弹出该变量值

	lua_pushstring(L,value);	// 将value压入lua栈
	lua_setglobal(L,key);		// 从lua栈中弹出value,将lua变量值设为value

	SPIN_UNLOCK(E)
}

void
skynet_env_init() {
	E = skynet_malloc(sizeof(*E));
	SPIN_INIT(E)
	E->L = luaL_newstate();//创建lua虚拟机
}
