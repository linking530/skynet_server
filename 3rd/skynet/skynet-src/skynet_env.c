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

// skynet �������� ��Ҫ�ǻ�ȡ������lua�Ļ�������
static struct skynet_env *E = NULL;

const char * 
skynet_getenv(const char *key) { // ��ȡ���� lua ��ȫ�ֱ��� key ֵ
	SPIN_LOCK(E)

	lua_State *L = E->L;
	
	lua_getglobal(L, key);						// ��ȡluaȫ�ֱ���key��ֵ,��ѹ��luaջ
	const char * result = lua_tostring(L, -1);	// ��luaջ�е����ñ���ֵ����ֵ��result
	lua_pop(L, 1);								// �����ñ���ֵ

	SPIN_UNLOCK(E)

	return result;
}

void 
skynet_setenv(const char *key, const char *value) {
	SPIN_LOCK(E)
	
	lua_State *L = E->L;
	lua_getglobal(L, key);		// ��ȡluaȫ�ֱ���key��ֵ,��ѹ��luaջ
	assert(lua_isnil(L, -1));	// ���Ըñ���ֵһ���ǿյ�

	lua_pop(L,1);				// �����ñ���ֵ

	lua_pushstring(L,value);	// ��valueѹ��luaջ
	lua_setglobal(L,key);		// ��luaջ�е���value,��lua����ֵ��Ϊvalue

	SPIN_UNLOCK(E)
}

void
skynet_env_init() {
	E = skynet_malloc(sizeof(*E));
	SPIN_INIT(E)
	E->L = luaL_newstate();//����lua�����
}
