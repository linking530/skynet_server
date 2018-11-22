#ifndef SKYNET_RWLOCK_H
#define SKYNET_RWLOCK_H
//��д��
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
		// ��д���Ƿ�ռ�ã�����б�ռ����ǿ��ִ����ռ��ǰ�Ĳ���
		while(lock->write) {
			//It is a atomic builtin for full memory barrier.
			//No memory operand will be moved across the operation, either forward or backward.Further,
			//instructions will be issued as necessary to prevent the processor from speculating loads 
			//across the operation and from queuing stores after the operation.
			__sync_synchronize();
		}
		//������ס����
		__sync_add_and_fetch(&lock->read,1);
		//�ڸ�nreaders + 1 ֮���ٴμ���Ƿ���д���ߣ��еĻ��˴ζ�������ʧ��  
		if (lock->write) {
			__sync_sub_and_fetch(&lock->read,1);
		} else {
			break;
		}
	}
}

//type __sync_lock_test_and_set(type *ptr, type value, ...)
//��*ptr��Ϊvalue������*ptr����֮ǰ��ֵ��
static inline void
rwlock_wlock(struct rwlock *lock) {
	//�����д״̬��ȴ�
	//�����д״̬����Ϊд״̬��������һ��
	// ���û��д�ߣ�__sync_lock_test_and_set�᷵��0����ʾ�˴�����д���ɹ���  
	// �����ʾ������д�ߣ����ת  
	while (__sync_lock_test_and_set(&lock->write,1)) {}
	// �ȴ���������ռ��
	while(lock->read) {
		//memory barrier,ǿ��cpuִ����ǰ���д���Ժ���ִ�����һ����
		// �ڿ�ʼд��֮ǰ�����ж��߽��룬��Ҫ�ȵ�ǰ��Ĳ������ 
		__sync_synchronize();
	}

}

static inline void
rwlock_wunlock(struct rwlock *lock) {
	//void __sync_lock_release (type *ptr, ...)
	//��*ptr��0
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

//pthread_rwlock_t ��linuxϵͳ�����̹߳����һ��������
//��д���� pthread_rwlock_t ���͵ı�����ʾ��
//������ʹ�� pthread_rwlock_t ��������ͬ��֮ǰ,������� pthread_rwlock_init ��������ʼ�����������
//�����������ʽΪ:
//intpthread_rwlock_init(pthread_rwlock_t* restrict rwlock,const pthread_rwlockattr_t* restrictrwlockattr);
//���� rwlock ��һ��ָ���д����ָ��,���� attr ��һ����д�����Զ����ָ��,�����NULL ���ݸ���,��ʹ��Ĭ����������ʼ��һ����д����
//����ɹ�,pthread_rwlock_init�ͷ��� 0��������ɹ�,pthread_rwlock_init �ͷ���һ������Ĵ����롣
static inline void
rwlock_init(struct rwlock *lock) {
	pthread_rwlock_init(&lock->lock, NULL);
}

static inline void
rwlock_rlock(struct rwlock *lock) {
	 //��ȡһ��д����
	 pthread_rwlock_rdlock(&lock->lock);
}

static inline void
rwlock_wlock(struct rwlock *lock) {
	 //��ȡһ��������
	 pthread_rwlock_wrlock(&lock->lock);
}

static inline void
rwlock_wunlock(struct rwlock *lock) {
	//�ͷ�һ��д�������߶�����
	pthread_rwlock_unlock(&lock->lock);
}

static inline void
rwlock_runlock(struct rwlock *lock) {
	pthread_rwlock_unlock(&lock->lock);
}

#endif

#endif
