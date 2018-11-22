#ifndef PROTOBUF_C_ARRAY_H
#define PROTOBUF_C_ARRAY_H

#include "varint.h"
#include "pbc.h"
#include "alloc.h"

//我把所有的基本数据类型全部统一成了三种：integer , string , real 。
//bool 类型被当成 integer 处理。enum 类型即可以是 string ，也可以是 integer 。
//用 pbc_rmessage_string 时，可以取到 enum 的名字；用 pbc_rmessage_integer 则取得 id 。
typedef union _pbc_var {
	struct longlong integer;
	double real;
	struct {
		const char * str;
		int len;
	} s;
	struct {
		int id;
		const char * name;
	} e;
	struct pbc_slice m;
	void * p[2];
} pbc_var[1];
//static struct pbc_wmessage
//var->p[0] = _wmessage_new(m->heap, f->type_name.m);
//struct _field	
//var->p[1] = f;

void _pbcA_open(pbc_array);
void _pbcA_open_heap(pbc_array, struct heap *h);
void _pbcA_close(pbc_array);

void _pbcA_push(pbc_array, pbc_var var);
void _pbcA_index(pbc_array , int idx, pbc_var var);
void * _pbcA_index_p(pbc_array _array, int idx);

#endif
