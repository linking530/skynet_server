///
/// \file skynet_main.c
/// \brief ������
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
	//�����������Ϊ�������û������������򷵻�ԭ����ֵ
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
//�����������Ϊ�������û������������򷵻�ԭ����ֵ
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
	while (lua_next(L, -2) != 0) {		// ����key����ȫ�ֱ������е�ȫ�ֱ�����ȫ�ֱ���ֵѹ��luaջ
		int keyt = lua_type(L, -2);		// ��ȡkey����
		if (keyt != LUA_TSTRING) {
			fprintf(stderr, "Invalid config table\n");
			exit(1);
		}
		const char * key = lua_tostring(L,-2);	// ��ȡkey
		if (lua_type(L,-1) == LUA_TBOOLEAN) {
			int b = lua_toboolean(L,-1);
			skynet_setenv(key,b ? "true" : "false" );
		} else {
			const char * value = lua_tostring(L,-1);	// ��ȡvalue
			if (value == NULL) {
				fprintf(stderr, "Invalid config table key = %s\n", key);
				exit(1);
			}
			skynet_setenv(key,value);
		}
		lua_pop(L,1);	// ����value,����key,�Ա���һ�ε���
	}
	lua_pop(L,1);		// ����ȫ�ֱ�����
}


//Ϊ�˱�������˳�, ���Բ���SIGPIPE�ź�, ���ߺ�����, ��������SIG_IGN�źŴ�����
int sigign() {
	struct sigaction sa;
	sa.sa_handler = SIG_IGN; // �����ź�,��ȫ������SIGPIPE��
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
	const char * config_file = NULL ;// �������õ��ļ���
	if (argc > 1) {
		config_file = argv[1];
	} else {
		fprintf(stderr, "Need a config file. Please read skynet wiki : https://github.com/cloudwu/skynet/wiki/Config\n"
			"usage: skynet configfilename\n");
		return 1;
	}

	luaS_initshr();//��ʼ����д��,SHRSTR_SLOT 0x10000
	skynet_globalinit();//��ʼ��skynet_node

	skynet_env_init();//�����ڴ�ռ�,��ʼ��struct skynet_env����������Lua�����

	sigign();//�����źŴ���

	struct skynet_config config;

	// lua ��ص�һЩ��ʼ��
	struct lua_State *L = luaL_newstate();
	luaL_openlibs(L);	// link lua lib ��lualib.h�ж����lua��׼����ص���lua_State

	int err = luaL_loadstring(L, load_config);//���ļ��м���lua���벢���룬����ɹ���ĳ���鱻ѹ��ջ�У�
	assert(err == LUA_OK);
	//��C��ȡ��config�����ļ����ݴ�ѹ��ջ��
	lua_pushstring(L, config_file);
	//ִ��ջ����chunk��ʵ���Ͼ��Ǽ���config���lua�ű��ַ���������
	err = lua_pcall(L, 1, 1, 0);// ִ�������ļ�
	if (err) {
		fprintf(stderr,"%s\n",lua_tostring(L,-1));
		lua_close(L);
		return 1;
	} 

	// ��ʼ�� lua ������ʼ����������,ͨ�� skynet_setenv() ������ע�� skynet_env �е�lua�����������
	//	�� struct skynet_config ����������Ϣ
			/*
			struct skynet_config {
				int thread;
				int harbor;
				const char * daemon;
				const char * module_path;//lua��·��
				const char * bootstrap;
				const char * logger;
				const char * logservice;//optstring("logservice", "logger");
			};
			*/
	
	_init_env(L);

	// ����������
	config.thread =  optint("thread",8);// �߳���
	config.module_path = optstring("cpath","./cservice/?.so");// C �����·��
	config.harbor = optint("harbor", 1);// �ڵ�ı��
	config.bootstrap = optstring("bootstrap","snlua bootstrap");
	config.daemon = optstring("daemon", NULL);
	config.logger = optstring("logger", NULL);
	config.logservice = optstring("logservice", "logger");
	//�ر������L
	lua_close(L);

	skynet_start(&config);//���� struct skynet_config ����������
	//��Ӧ�����skynet_globalinit()������ɾ�� �̴߳洢��Key��
	skynet_globalexit();
	luaS_exitshr();

	return 0;
}
