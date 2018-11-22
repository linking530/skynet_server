#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>

#include <time.h>

#if defined(__APPLE__)
#include <mach/task.h>
#include <mach/mach.h>
#endif
//1秒 = 1000毫秒
//1毫秒 = 1000微秒
//1微秒 = 1000纳秒
#define NANOSEC 1000000000
#define MICROSEC 1000000

// #define DEBUG_LOG

static double
get_time() {
#if  !defined(__APPLE__)
	struct timespec ti;
	clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ti);//本线程到当前代码系统CPU花费的时间

	int sec = ti.tv_sec & 0xffff;
	int nsec = ti.tv_nsec;

	return (double)sec + (double)nsec / NANOSEC;	
#else
	struct task_thread_times_info aTaskInfo;
	mach_msg_type_number_t aTaskInfoCount = TASK_THREAD_TIMES_INFO_COUNT;
	if (KERN_SUCCESS != task_info(mach_task_self(), TASK_THREAD_TIMES_INFO, (task_info_t )&aTaskInfo, &aTaskInfoCount)) {
		return 0;
	}

	int sec = aTaskInfo.user_time.seconds & 0xffff;
	int msec = aTaskInfo.user_time.microseconds;

	return (double)sec + (double)msec / MICROSEC;
#endif
}

static inline double 
diff_time(double start) {
	double now = get_time();
	if (now < start) {
		return now + 0x10000 - start;
	} else {
		return now - start;
	}
}

//upvalues of lstart/lstop: table->totaltime, table->starttime, nil
static int
lstart(lua_State *L) {
	if (lua_type(L,1) == LUA_TTHREAD) {
		lua_settop(L,1);
	} else {
		lua_pushthread(L);
	}
	lua_rawget(L, lua_upvalueindex(2));
	if (!lua_isnil(L, -1)) {
		return luaL_error(L, "Thread %p start profile more than once", lua_topointer(L, 1));
	}
	lua_pushthread(L);
	lua_pushnumber(L, 0);
	lua_rawset(L, lua_upvalueindex(2));//更新start time

	lua_pushthread(L);
	double ti = get_time();
#ifdef DEBUG_LOG
	fprintf(stderr, "PROFILE [%p] start\n", L);
#endif
	lua_pushnumber(L, ti);
	lua_rawset(L, lua_upvalueindex(1));//更新total time

	return 0;
}

//upvalues of lstart/lstop: table->totaltime, table->starttime, nil
static int
lstop(lua_State *L) {
	if (lua_type(L,1) == LUA_TTHREAD) {
		lua_settop(L,1);
	} else {
		lua_pushthread(L);
	}
	lua_rawget(L, lua_upvalueindex(1));//获得totaltime
	if (lua_type(L, -1) != LUA_TNUMBER) {
		return luaL_error(L, "Call profile.start() before profile.stop()");
	} 
	double ti = diff_time(lua_tonumber(L, -1));
	lua_pushthread(L);
	lua_rawget(L, lua_upvalueindex(2));
	double total_time = lua_tonumber(L, -1);

	lua_pushthread(L);
	lua_pushnil(L);
	lua_rawset(L, lua_upvalueindex(1));//更新table->totaltime为nil

	lua_pushthread(L);
	lua_pushnil(L);
	lua_rawset(L, lua_upvalueindex(2));//更新table->starttime为nil

	total_time += ti;
	lua_pushnumber(L, total_time);
#ifdef DEBUG_LOG
	fprintf(stderr, "PROFILE [%p] stop (%lf / %lf)\n", L, ti, total_time);
#endif

	return 1;
}


//upvalues of lresume: table->totaltime, table->starttime, co_resume (coroutine.resume)
static int
timing_resume(lua_State *L) {
#ifdef DEBUG_LOG
	lua_State *from = lua_tothread(L, -1);
#endif
	lua_rawget(L, lua_upvalueindex(2));
	if (lua_isnil(L, -1)) {		// check total time
		lua_pop(L,1);
	} else {
		lua_pop(L,1);
		lua_pushvalue(L,1);
		double ti = get_time();
#ifdef DEBUG_LOG
		fprintf(stderr, "PROFILE [%p] resume\n", from);
#endif
		lua_pushnumber(L, ti);
		lua_rawset(L, lua_upvalueindex(1));	// set start time
	}

	lua_CFunction co_resume = lua_tocfunction(L, lua_upvalueindex(3));

	return co_resume(L);
}

static int
lresume(lua_State *L) {

	lua_pushvalue(L,1);	
	return timing_resume(L);

}

static int
lresume_co(lua_State *L) {

	luaL_checktype(L, 2, LUA_TTHREAD);
	lua_rotate(L, 2, -1);

	return timing_resume(L);
}

static int
timing_yield(lua_State *L) {
#ifdef DEBUG_LOG
	lua_State *from = lua_tothread(L, -1);
#endif
	lua_rawget(L, lua_upvalueindex(2));	// check total time
	if (lua_isnil(L, -1)) {
		lua_pop(L,1);
	} else {
		double ti = lua_tonumber(L, -1);
		lua_pop(L,1);

		lua_pushthread(L);
		lua_rawget(L, lua_upvalueindex(1));
		double starttime = lua_tonumber(L, -1);
		lua_pop(L,1);

		double diff = diff_time(starttime);
		ti += diff;
#ifdef DEBUG_LOG
		fprintf(stderr, "PROFILE [%p] yield (%lf/%lf)\n", from, diff, ti);
#endif

		lua_pushthread(L);
		lua_pushnumber(L, ti);
		lua_rawset(L, lua_upvalueindex(2));
	}

	lua_CFunction co_yield = lua_tocfunction(L, lua_upvalueindex(3));

	return co_yield(L);
}

static int
lyield(lua_State *L) {
	lua_pushthread(L);

	return timing_yield(L);
}

static int
lyield_co(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTHREAD);
	lua_rotate(L, 1, -1);
	
	return timing_yield(L);
}


//coroutine.resume和coroutine.yield作为upvalue打进了DIY的lresume和lyield，
//并把协程启动时间和累计运行时间作为upvalue打进lstart / lstop / lresume / lyield
//coroutine.create(..)    创建协程, 参数：协程要执行的main函数；返回值：thread对象，指向协程
//
//coroutine.resume(..) 启动 / 恢复协程, 第一个参数是thread对象，启动时其他参数传递给协程对应的main函数，恢复时其他参数赋值给中断时yield赋值的对象
//
//coroutine.yield(..)       挂起协程，导致coroutine.resume()立即返回，返回值：true + yield的参数；

int
luaopen_profile(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "start", lstart },
		{ "stop", lstop },
		{ "resume", lresume },
		{ "yield", lyield },
		{ "resume_co", lresume_co },
		{ "yield_co", lyield_co },
		{ NULL, NULL },
	};
	luaL_newlibtable(L,l);//创建能容纳l的空表
	lua_newtable(L);	//创建一张空表，并将其压栈 table thread->start time
	lua_newtable(L);	//创建一张空表，并将其压栈 table thread->total time
	/*
	*  table -> total time
	*  table -> start time
	*  table -> libtable
	*/

	lua_newtable(L);	//创建一张空表，并将其压栈 weak table
	lua_pushliteral(L, "kv");
	lua_setfield(L, -2, "__mode");	//weak["__mode"] = "kv"   设置为弱表 
	/*
	*  table -> weak table
	*  table -> total time
	*  table -> start time
	*  table -> libtable
	*/

	lua_pushvalue(L, -1);//把栈顶元素作一个副本压栈。
	/*
	*  table -> weak table copy
	*  table -> weak table
	*  table -> total time
	*  table -> start time
	*  table -> libtable
	*/

	lua_setmetatable(L, -3); //把weak table copy表弹出栈，并将其设为total time的元表
	/*
	*  table -> weak table
	*  table -> total time
	*  table -> start time
	*  table -> libtable
	*/

	lua_setmetatable(L, -3);//把weak table表弹出栈，并将其设为start time的元表
	/*
	*  table -> total time with weak metatable
	*  table -> start time with weak metatable
	*  table -> libtable
	*/

	lua_pushnil(L);	// cfunction (coroutine.resume or coroutine.yield)
	luaL_setfuncs(L,l,3);
	/*
	*  3个上值 start time 、total time、nil,栈顶的上值清除出栈
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lresume/lyield: table->starttime, table->totaltime, nil
	*/

	int libtable = lua_gettop(L);//libtable = 1 

	lua_getglobal(L, "coroutine");//获取lua默认的coroutine库
	/*
	*  table -> coroutine
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lresume/lyield: table->starttime, table->totaltime, nil
	*/

	lua_getfield(L, -1, "resume");//获取lua默认的coroutine.resume函数  
	/*
	*  function -> coroutine.resume
	*  table -> coroutine
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lresume/lyield: table->starttime, table->totaltime, nil
	*/

	lua_CFunction co_resume = lua_tocfunction(L, -1);//co_resume=lua默认的coroutine.resume函数    
	if (co_resume == NULL)
		return luaL_error(L, "Can't get coroutine.resume");
	lua_pop(L, 1); // 把lua默认的coroutine.resume从stack中弹出去
	/*
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lresume/lyield: table->starttime, table->totaltime, nil
	*/
	lua_getfield(L, libtable, "resume");
	/*
	*  cfunction -> libtable.lresume
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lresume/lyield: table->starttime, table->totaltime, nil
	*/
	lua_pushcfunction(L, co_resume);
	/*
	*  cfunction -> co_resume (lua default coroutine.resume)
	*  cfunction -> lresume
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lresume/lyield: table->starttime, table->totaltime, nil
	*/

	lua_setupvalue(L, -2, 3);

	/*
	*  cfunction -> lresume with upvalues: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_pop(L,1);
	/*
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_getfield(L, libtable, "resume_co");
	/*
	*  cfunction -> libtable.resume_co
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_pushcfunction(L, co_resume);
	/*
	*  cfunction -> co_resume
	*  cfunction -> libtable.resume_co
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_setupvalue(L, -2, 3);
	/*
	*  cfunction -> lresume_co with upvalues: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_pop(L,1);
	/*
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_getfield(L, -1, "yield");
	/*
	*  cfunction -> coroutine.yield
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_CFunction co_yield = lua_tocfunction(L, -1);
	if (co_yield == NULL)
		return luaL_error(L, "Can't get coroutine.yield");
	lua_pop(L,1);
	/*
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*	   upvalues of lstart/lstop/lyield: table->totaltime, table->starttime, nil
	*	   upvalues of lresume: table->totaltime, table->starttime, co_resume (coroutine.resume)
	*/
	lua_getfield(L, libtable, "yield");
	/*
	*  cfunction libtable.yield
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_pushcfunction(L, co_yield);
	/*
	*  cfunction co_yield
	*  cfunction libtable.yield
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/
	lua_setupvalue(L, -2, 3);
	/*
	*  cfunction -> lyield with upvalues: table->starttime, table->totaltime, co_yield
	*  coroutine -> (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_pop(L,1);
	/*
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/

	lua_getfield(L, libtable, "yield_co");
	/*
	*  cfunction libtable.yield_co
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/
	lua_pushcfunction(L, co_yield);
	/*
	*  cfunction co_yield
	*  cfunction libtable.yield_co
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*           upvalues of lstart/lstop/lyield: table->starttime, table->totaltime, nil
	*           upvalues of lresume: table->starttime, table->totaltime, co_resume (coroutine.resume)
	*/
	lua_setupvalue(L, -2, 3);

	/*
	*  cfunction lyield with upvalues: table->totaltime, table->starttime, co_yield (coroutine.yield)
	*  coroutine (lua coroutine table)
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*	   upvalues of lstart/lstop: table->totaltime, table->starttime, nil
	*	   upvalues of lresume: table->totaltime, table->starttime, co_resume (coroutine.resume)
	*	   upvalues of lyield: table->totaltime, table->starttime, co_yield (coroutine.yield)
	*/
	lua_pop(L,1);

	lua_settop(L, libtable);
	/*
	*  table -> libtable: {start=lstart, stop=lstop, resume=lresume, yield=lyield};
	*	   upvalues of lstart/lstop: table->totaltime, table->starttime, nil
	*	   upvalues of lresume: table->totaltime, table->starttime, co_resume (coroutine.resume)
	*	   upvalues of lyield: table->totaltime, table->starttime, co_yield (coroutine.yield)
	*/
	return 1;
}
