#ifndef SKYNET_SPINLOCK_H
#define SKYNET_SPINLOCK_H

#define SPIN_INIT(q) spinlock_init(&(q)->lock);
#define SPIN_LOCK(q) spinlock_lock(&(q)->lock);
#define SPIN_UNLOCK(q) spinlock_unlock(&(q)->lock);
#define SPIN_DESTROY(q) spinlock_destroy(&(q)->lock);

#ifndef USE_PTHREAD_LOCK
/*
　自旋锁(spinlock) 和 互斥锁(mutex) 对比

 　　自旋锁：得到锁之前是在一个循环中空转，直到得到锁为止，那么就有三种可能 1：很短时间就得到锁，由于是空转，没有sleep，也就没有由系统到用户态的消耗，2：很长时间才得到锁，虽然没有状态的切换，但是由于忙等时间过长

   　　　　　　导致性能下降，3：一直空转，消耗cpu时间。

		 　　互斥锁 : 企图获得锁，若是得不到锁则阻塞，放弃cpu，没有忙等的出现，当锁可得时，发生状态切换，由内核切换到用户态，虽然没有忙等但是状态切换的代价仍然很大。

		   　　

			 　　由此可知：对自旋锁和互斥锁的选择是要根据得到锁的耗时来的，若果当得到锁后，需要执行大量的操作，一般选用互斥锁，若得到锁后，进行很少量的操作，一般选择自旋锁，因为执行的操作短，那么忙等的开销总体还是小于内核态

			   　　　　　　   和用户态切换带来的开销的。

*/
/*****

1. c/c++标准中没有定义任何操作符为原子的，操作符是否原子和平台及编译器版本有关

2. GCC提供了一组内建的原子操作，这些操作是以函数的形式提供的，这些函数不需要引用任何头文件

　　2.1 对变量做某种操作，并且返回操作前的值，总共6个函数：

　　　　type __sync_fetch_and_add (type *ptr, type value, ...)    加减运算 相当于  tmp = *ptr;  *ptr += value; return tmp;

　　　　type __sync_fetch_and_sub (type *ptr, type value, ...)    加减运算 相当于  tmp = *ptr;  *ptr -= value; return tmp;

　　　　type __sync_fetch_and_or (type *ptr, type value, ...)       逻辑运算 相当于  tmp = *ptr;  *ptr |= value; return tmp;

　　　　type __sync_fetch_and_and (type *ptr, type value, ...)     逻辑运算 相当于  tmp = *ptr;  *ptr &= value; return tmp;

　　　　type __sync_fetch_and_xor (type *ptr, type value, ...)     位运算 相当于  tmp = *ptr;  *ptr ^= value; return tmp;

　　　　type __sync_fetch_and_nand (type *ptr, type value, ...)   位运算 相当于  tmp = *ptr; *ptr = ~(tmp & value); return tmp;

           注意，__sync_fetch_and_nand在GCC的4.4版本之前语义并非如此，而是 tmp = *ptr; *ptr = ~tmp & value; return tmp;

　　2.2 对变量做某种操作，并且返回操作后的值，总共6个函数，和前面的6个函数完全类似：

　　　　type __sync_add_and_fetch (type *ptr, type value, ...)

　　　　type __sync_sub_and_fetch (type *ptr, type value, ...)

　　　　type __sync_or_and_fetch (type *ptr, type value, ...)

　　　　type __sync_and_and_fetch (type *ptr, type value, ...)

　　　　type __sync_xor_and_fetch (type *ptr, type value, ...)

　　　　type __sync_nand_and_fetch (type *ptr, type value, ...)

　　2.3 把变量的值和某个值比较，如果相等就把变量的值设置为新的值，总共2个函数：

　　　　bool __sync_bool_compare_and_swap (type *ptr, type oldval type newval, ...)   

　　　　　　返回是否相等，相当于

　　　　　　　　　if ( *ptr == oldval ) {*ptr = newval; return true;}

                          else {return false;}

　　　　type __sync_val_compare_and_swap (type *ptr, type oldval type newval, ...)

　　　　　　返回修改前的值，相当于

　　　　　　　　　tmp = *ptr 

　　　　　　　　　if ( *ptr == oldval ) { *ptr= newval; }

                          return tmp ;

　　2.4 锁定测试-设置 及 解锁，总共2个函数： 

　　　　type __sync_lock_test_and_set (type *ptr, type value, ...)

　　　　　　把变量的值设置为新值，并返回设置前的值，相当于tmp = *ptr; return tmp

　　　　void __sync_lock_release (type *ptr, ...)  

　　　　　　把变量的值设置为0，相当于 *ptr = 0  通过查看汇编代码，可以看出这个函数使用了内存屏障，然后再把变量的值置为0

            这两个函数可以实现自旋锁

自旋锁的实现：boost实现如下，在spinlock_sync.hpp
*****/
struct spinlock {
	int lock;
};

static inline void
spinlock_init(struct spinlock *lock) {
	lock->lock = 0;
}

static inline void
spinlock_lock(struct spinlock *lock) {
	//将*ptr设为value并返回*ptr操作之前的值。
	while (__sync_lock_test_and_set(&lock->lock,1)) {}
}

static inline int
spinlock_trylock(struct spinlock *lock) {
	return __sync_lock_test_and_set(&lock->lock,1) == 0;
}

static inline void
spinlock_unlock(struct spinlock *lock) {
	__sync_lock_release(&lock->lock);
}

static inline void
spinlock_destroy(struct spinlock *lock) {
	(void) lock;
}

#else

#include <pthread.h>
/****************************************

 pthread_mutex_init()函数是以动态方式创建互斥锁的，参数attr指定了新建互斥锁的属性。
 如果参数attr为空，则使用默认的互斥锁属性，默认属性为快速互斥锁 。
 互斥锁的属性在创建锁的时候指定，在LinuxThreads实现中仅有一个锁类型属性，
 不同的锁类型在试图对一个已经被锁定的互斥锁加锁时表现不同。


********************************************/
// we use mutex instead of spinlock for some reason
// you can also replace to pthread_spinlock

struct spinlock {
	pthread_mutex_t lock;	//互斥锁
};

static inline void
spinlock_init(struct spinlock *lock) {

	pthread_mutex_init(&lock->lock, NULL);
}

static inline void
spinlock_lock(struct spinlock *lock) {
	pthread_mutex_lock(&lock->lock);
}

static inline int
spinlock_trylock(struct spinlock *lock) {
	return pthread_mutex_trylock(&lock->lock) == 0;
}

static inline void
spinlock_unlock(struct spinlock *lock) {
	pthread_mutex_unlock(&lock->lock);
}

static inline void
spinlock_destroy(struct spinlock *lock) {
	pthread_mutex_destroy(&lock->lock);
}

#endif

#endif
