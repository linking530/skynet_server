///
/// \file skynet_main.c
/// \brief 主函数
///
#include "skynet.h"

#include "skynet_imp.h"
#include "skynet_env.h"
#include "skynet_server.h"
#include "luashrtbl.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <signal.h>
#include <assert.h>

static int
optint(const char *key, int opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		char tmp[20];
		sprintf(tmp,"%d",opt);
		skynet_setenv(key, tmp);
		return opt;
	}
	//如果环境变量为空则设置环境变量，否则返回原来的值
	return strtol(str, NULL, 10);
}

/*
static int
optboolean(const char *key, int opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		skynet_setenv(key, opt ? "true" : "false");
		return opt;
	}
	return strcmp(str,"true")==0;
}
*/
//如果环境变量为空则设置环境变量，否则返回原来的值
static const char *
optstring(const char *key,const char * opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		if (opt) {
			skynet_setenv(key, opt);
			opt = skynet_getenv(key);
		}
		return opt;
	}
	return str;
}

static void
_init_env(lua_State *L) {
	lua_pushnil(L);  /* first key */
	while (lua_next(L, -2) != 0) {		// 弹出key并将全局变量表中的全局变量与全局变量值压入lua栈
		int keyt = lua_type(L, -2);		// 获取key类型
		if (keyt != LUA_TSTRING) {
			fprintf(stderr, "Invalid config table\n");
			exit(1);
		}
		const char * key = lua_tostring(L,-2);	// 获取key
		if (lua_type(L,-1) == LUA_TBOOLEAN) {
			int b = lua_toboolean(L,-1);
			skynet_setenv(key,b ? "true" : "false" );
		} else {
			const char * value = lua_tostring(L,-1);	// 获取value
			if (value == NULL) {
				fprintf(stderr, "Invalid config table key = %s\n", key);
				exit(1);
			}
			skynet_setenv(key,value);
		}
		lua_pop(L,1);	// 弹出value,保留key,以便下一次迭代
	}
	lua_pop(L,1);		// 弹出全局变量表
}


//为了避免进程退出, 可以捕获SIGPIPE信号, 或者忽略它, 给它设置SIG_IGN信号处理函数
int sigign() {
	struct sigaction sa;
	sa.sa_handler = SIG_IGN; // 忽略信号,安全的屏蔽SIGPIPE：
	sigaction(SIGPIPE, &sa, 0);
	return 0;
}

static const char * load_config = "\
	local config_name = ...\
	local f = assert(io.open(config_name))\
	local code = assert(f:read \'*a\')\
	local function getenv(name) return assert(os.getenv(name), \'os.getenv() failed: \' .. name) end\
	code = string.gsub(code, \'%$([%w_%d]+)\', getenv)\
	f:close()\
	local result = {}\
	assert(load(code,\'=(load)\',\'t\',result))()\
	return result\
";

int
main(int argc, char *argv[]) {
	const char * config_file = NULL ;// 设置配置的文件名
	if (argc > 1) {
		config_file = argv[1];
	} else {
		fprintf(stderr, "Need a config file. Please read skynet wiki : https://github.com/cloudwu/skynet/wiki/Config\n"
			"usage: skynet configfilename\n");
		return 1;
	}

	luaS_initshr();//初始化读写锁,SHRSTR_SLOT 0x10000
	skynet_globalinit();//初始化skynet_node

	skynet_env_init();//申请内存空间,初始化struct skynet_env、自旋锁、Lua虚拟机

	sigign();//设置信号处理

	struct skynet_config config;

	// lua 相关的一些初始化
	struct lua_State *L = luaL_newstate();
	luaL_openlibs(L);	// link lua lib 将lualib.h中定义的lua标准库加载到进lua_State

	int err = luaL_loadstring(L, load_config);//从文件中加载lua代码并编译，编译成功后的程序块被压入栈中，
	assert(err == LUA_OK);
	//把C读取的config配置文件内容串压入栈顶
	lua_pushstring(L, config_file);
	//执行栈顶的chunk，实际上就是加载config这个lua脚本字符串的内容
	err = lua_pcall(L, 1, 1, 0);// 执行配置文件
	if (err) {
		fprintf(stderr,"%s\n",lua_tostring(L,-1));
		lua_close(L);
		return 1;
	} 

	// 初始化 lua 环境初始化环境变量,通过 skynet_setenv() 将数据注入 skynet_env 中的lua虚拟机主表中
	//	向 struct skynet_config 设置配置信息
			/*
			struct skynet_config {
				int thread;
				int harbor;
				const char * daemon;
				const char * module_path;//lua库路径
				const char * bootstrap;
				const char * logger;
				const char * logservice;//optstring("logservice", "logger");
			};
			*/
	
	_init_env(L);

	// 加载配置项
	config.thread =  optint("thread",8);// 线程数
	config.module_path = optstring("cpath","./cservice/?.so");// C 服务的路径
	config.harbor = optint("harbor", 1);// 节点的编号
	config.bootstrap = optstring("bootstrap","snlua bootstrap");
	config.daemon = optstring("daemon", NULL);
	config.logger = optstring("logger", NULL);
	config.logservice = optstring("logservice", "logger");
	//关闭虚拟机L
	lua_close(L);

	skynet_start(&config);//基于 struct skynet_config 启动并阻塞
	//对应上面的skynet_globalinit()，用于删除 线程存储的Key。
	skynet_globalexit();
	luaS_exitshr();

	return 0;
}
