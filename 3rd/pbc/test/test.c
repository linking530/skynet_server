#include "pbc.h"

#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

#define COUNT 1000000

#include "readfile.h"

static void
test(struct pbc_env *env) {
	int i;
	for(i=0; i<COUNT; i++)
	{
			//解码二进制流为数据结构	
			struct pbc_wmessage* w_msg = pbc_wmessage_new(env, "at");
			struct pbc_rmessage* r_msg = NULL;
			struct pbc_slice sl;
			char buffer[1024];
			sl.buffer = buffer, sl.len = 1024;
			pbc_wmessage_integer(w_msg, "aa", 123, 0);
			pbc_wmessage_integer(w_msg, "bb", 456, 0);
			pbc_wmessage_string(w_msg, "cc", "test string!", -1);
			
			//将w_msg数据放入slice
			pbc_wmessage_buffer(w_msg, &sl);
					
			r_msg = pbc_rmessage_new(env, "at", &sl);
			pbc_rmessage_delete(r_msg);
			pbc_wmessage_delete(w_msg);
	} 
}

int
main() {
	struct pbc_env * env = pbc_new();
	//数据存放buffer, len 
	struct pbc_slice slice;
	//读取protoc生成的pb文件
	read_file("test.pb", &slice);
	//讲slice数据消息regist到pbc的环境
	int ret = pbc_register(env, &slice);
	assert(ret == 0);
	test(env);
	pbc_delete(env);

	return 0;
}
