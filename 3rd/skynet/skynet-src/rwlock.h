#ifndef SKYNET_RWLOCK_H
#define SKYNET_RWLOCK_H
//读写锁
#ifndef USE_PTHREAD_LOCK

struct rwlock {
	int write;
	int read;
};

static inline void
rwlock_init(struct rwlock *lock) {
	lock->write = 0;
	lock->read = 0;
}

static inline void
rwlock_rlock(struct rwlock *lock) {
	for (;;) {
		// 看写锁是否被占用，如果有被占用则强制执行完占用前的操作
		while(lock->write) {
			//It is a atomic builtin for full memory barrier.
			//No memory operand will be moved across the operation, either forward or backward.Further,
			//instructions will be issued as necessary to prevent the processor from speculating loads 
			//across the operation and from queuing stores after the operation.
			__sync_synchronize();
		}
		//设置锁住读锁
		__sync_add_and_fetch(&lock->read,1);
		//在给nreaders + 1 之后再次检查是否有写入者，有的话此次读锁请求失败  
		if (lock->write) {
			__sync_sub_and_fetch(&lock->read,1);
		} else {
			break;
		}
	}
}

//type __sync_lock_test_and_set(type *ptr, type value, ...)
//将*ptr设为value并返回*ptr操作之前的值。
static inline void
rwlock_wlock(struct rwlock *lock) {
	//如果是写状态则等待
	//如果非写状态则标记为写状态，进入下一步
	// 如果没有写者，__sync_lock_test_and_set会返回0，表示此次请求写锁成功；  
	// 否则表示有其它写者，则空转  
	while (__sync_lock_test_and_set(&lock->write,1)) {}
	// 等待读锁不被占用
	while(lock->read) {
		//memory barrier,强制cpu执行完前面的写入以后再执行最后一条：
		// 在开始写入之前发现有读者进入，则要等到前面的操作完成 
		__sync_synchronize();
	}

}

static inline void
rwlock_wunlock(struct rwlock *lock) {
	//void __sync_lock_release (type *ptr, ...)
	//将*ptr置0
	__sync_lock_release(&lock->write);
}

static inline void
rwlock_runlock(struct rwlock *lock) {
	__sync_sub_and_fetch(&lock->read,1);
}

#else

#include <pthread.h>

// only for some platform doesn't have __sync_*
// todo: check the result of pthread api

struct rwlock {
	pthread_rwlock_t lock;
};

//pthread_rwlock_t 是linux系统用于线程管理的一个函数。
//读写锁由 pthread_rwlock_t 类型的变量表示。
//程序在使用 pthread_rwlock_t 变量进行同步之前,必须调用 pthread_rwlock_init 函数来初始化这个变量。
//这个函数的形式为:
//intpthread_rwlock_init(pthread_rwlock_t* restrict rwlock,const pthread_rwlockattr_t* restrictrwlockattr);
//参数 rwlock 是一个指向读写锁的指针,参数 attr 是一个读写锁属性对象的指针,如果将NULL 传递给它,则使用默认属性来初始化一个读写锁。
//如果成功,pthread_rwlock_init就返回 0。如果不成功,pthread_rwlock_init 就返回一个非零的错误码。
static inline void
rwlock_init(struct rwlock *lock) {
	pthread_rwlock_init(&lock->lock, NULL);
}

static inline void
rwlock_rlock(struct rwlock *lock) {
	 //获取一个写入锁
	 pthread_rwlock_rdlock(&lock->lock);
}

static inline void
rwlock_wlock(struct rwlock *lock) {
	 //获取一个读出锁
	 pthread_rwlock_wrlock(&lock->lock);
}

static inline void
rwlock_wunlock(struct rwlock *lock) {
	//释放一个写入锁或者读出锁
	pthread_rwlock_unlock(&lock->lock);
}

static inline void
rwlock_runlock(struct rwlock *lock) {
	pthread_rwlock_unlock(&lock->lock);
}

#endif

#endif
