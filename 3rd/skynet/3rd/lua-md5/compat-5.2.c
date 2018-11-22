#include "lua.h"
#include "lauxlib.h"
#include "compat-5.2.h"

#if !defined LUA_VERSION_NUM || LUA_VERSION_NUM==501
/*
** Adapted from Lua 5.2.0
*/
//把数组 l 中的所有函数 （参见 luaL_Reg） 注册到栈顶的表中（该表在可选的上值之下，见下面的解说）。
//若 nup 不为零， 所有的函数都共享 nup 个上值。 这些值必须在调用之前，压在表之上。 这些值在注册完毕后都会从栈弹出。
void luaL_setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
  luaL_checkstack(L, nup+1, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    lua_pushstring(L, l->name);
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -(nup + 1));
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_settable(L, -(nup + 3)); /* table must be below the upvalues, the name and the closure */
  }
  lua_pop(L, nup);  /* remove upvalues */
}
#endif
