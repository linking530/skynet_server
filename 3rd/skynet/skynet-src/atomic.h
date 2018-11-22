#ifndef SKYNET_ATOMIC_H
#define SKYNET_ATOMIC_H
//原子操作
//在用gcc编译的时候要加上选项 -march=i686
#define ATOM_CAS(ptr, oval, nval) __sync_bool_compare_and_swap(ptr, oval, nval)
#define ATOM_CAS_POINTER(ptr, oval, nval) __sync_bool_compare_and_swap(ptr, oval, nval)
#define ATOM_INC(ptr) __sync_add_and_fetch(ptr, 1)	//加1再去的当前值
#define ATOM_FINC(ptr) __sync_fetch_and_add(ptr, 1)	//返回当前值再加1
#define ATOM_DEC(ptr) __sync_sub_and_fetch(ptr, 1)	//减1再获取当前值
#define ATOM_FDEC(ptr) __sync_fetch_and_sub(ptr, 1)	//获取当前值再减1
#define ATOM_ADD(ptr,n) __sync_add_and_fetch(ptr, n)//加n再去的当前值
#define ATOM_SUB(ptr,n) __sync_sub_and_fetch(ptr, n)//减n再去的当前值
#define ATOM_AND(ptr,n) __sync_and_and_fetch(ptr, n)

#endif
