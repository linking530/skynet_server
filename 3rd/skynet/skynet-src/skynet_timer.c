///
/// \file skynet_timer.c
/// \brief ��ʱ��
///
#include "skynet.h"

#include "skynet_timer.h"
#include "skynet_mq.h"
#include "skynet_server.h"
#include "skynet_handle.h"
#include "spinlock.h"

#include <time.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#if defined(__APPLE__) // ƻ��ƽ̨
#include <sys/time.h>
#endif
// skynet ��ʱ����ʵ��Ϊlinux�ں˵ı�׼����  ����Ϊ 0.01s ����Ϸһ����˵���� �߾��ȵĶ�ʱ���ܷ�CPU
typedef void (*timer_execute_func)(void *ud,void *arg); ///< ����ָ������


// �����ں�����ĵġ�intervalֵ�ڣ�0��255��
// �ں��ڴ����Ƿ��е��ڶ�ʱ��ʱ������ֻ�Ӷ�ʱ����������tv1.vec��256���е�ĳ����ʱ�������ڽ���ɨ�衣
// ��2���������ں˲����ĵġ�intervalֵ�ڣ�0xff��0xffffffff��֮��Ķ�ʱ����
// ���ǵĵ��ڽ��ȳ̶�Ҳ����intervalֵ�Ĳ�ͬ����ͬ����ȻintervalֵԽС����ʱ�����ȳ̶�ҲԽ�ߡ�
// ����ڽ���������ɢ��ʱ������������֯ʱҲӦ������Դ���ͨ������ʱ����intervalֵԽС��
// �������Ķ�ʱ����������ɢ��Ҳ��Խ�ͣ�Ҳ�������еĸ���ʱ����expiresֵ���ԽС������intervalֵԽ��
// �������Ķ�ʱ����������ɢ��Ҳ��Խ��Ҳ�������еĸ���ʱ����expiresֵ���Խ�󣩡�

// �ں˹涨��������Щ����������0x100��interval��0x3fff�Ķ�ʱ����
// ֻҪ���ʽ��interval>>8��������ֵͬ�Ķ�ʱ����������֯��ͬһ����ɢ��ʱ�������У�
// ����1��8��256Ϊһ��������λ����ˣ�Ϊ��֯������������0x100��interval��0x3fff�Ķ�ʱ����
// ����Ҫ2^6��64����ɢ��ʱ��������ͬ���أ�Ϊ�����������64����ɢ��ʱ������Ҳ����һ���γ����飬����Ϊ���ݽṹtimer_vec��һ���֡�
#define TIME_NEAR_SHIFT 8
#define TIME_NEAR (1 << TIME_NEAR_SHIFT)
#define TIME_LEVEL_SHIFT 6
#define TIME_LEVEL (1 << TIME_LEVEL_SHIFT)
#define TIME_NEAR_MASK (TIME_NEAR-1)
#define TIME_LEVEL_MASK (TIME_LEVEL-1)

/// ��ʱ���¼�
struct timer_event {
	uint32_t handle; //�������ö�ʱ������Դ�����ǳ�ʱ��Ϣ���͵�Ŀ��
	int session; ///< �Ự ��һ����ID������˴�1��ʼ�����Բ�Ҫ��ʱ��ܳ���timer
};

/// ��ʱ���ڵ�
struct timer_node {
	struct timer_node *next; ///< ��һ����ʱ���ڵ�
	uint32_t expire; ///< ����ʱ�� ��ʱ�δ���� ����ʱ���
};

/// ����
struct link_list {
	struct timer_node head; ///< ����ͷ
	struct timer_node *tail; ///< ����β
};

///< ��ʱ��
struct timer {
	struct link_list near[TIME_NEAR];//�ٽ��Ķ�ʱ������
	struct link_list t[4][TIME_LEVEL];//�ĸ�����Ķ�ʱ������
	struct spinlock lock;//������
	uint32_t time; // ��ǰ�Ѿ������ĵδ����
	uint32_t starttime; //����������ʱ��㣬timestamp������
	uint64_t current;//�ӳ������������ڵĺ�ʱ������10���뼶 ��ǰʱ�䣬���ϵͳ����ʱ�䣨���ʱ�䣩
	uint64_t current_point;//��ǰʱ�䣬����10���뼶
};

static struct timer * TI = NULL;///< ȫ�ֶ�ʱ��ָ�����

//����������������һ�����
/// \param[in] *list
/// \return static inline struct timer_node *
static inline struct timer_node *
link_clear(struct link_list *list) {
	struct timer_node * ret = list->head.next; // �������ͷ����һ���ڵ�
	list->head.next = 0; // ����ͷ����һ���ڵ�Ϊ0
	list->tail = &(list->head);// ����β = ����ͷ

	return ret;// ��������ͷ����һ���ڵ�
}

//������������
static inline void
link(struct link_list *list,struct timer_node *node) {
	list->tail->next = node;
	list->tail = node;
	node->next=0;
}

//���һ����ʱ�����
/// \param[in] *T
/// \param[in] *node
/// \return static void
static void
add_node(struct timer *T,struct timer_node *node) {
	uint32_t time=node->expire;// ��ʱ�ĵδ���
	uint32_t current_time=T->time;
	//û�г�ʱ������˵ʱ����ر����	
	if ((time|TIME_NEAR_MASK)==(current_time|TIME_NEAR_MASK)) {
		link(&T->near[time&TIME_NEAR_MASK],node);// ���ڵ���ӵ���Ӧ��������
	} else { //������һ��������������ǵ�time��������Ƶ�ʱ��
		int i;
		uint32_t mask=TIME_NEAR << TIME_LEVEL_SHIFT;
		for (i=0;i<3;i++) {
			if ((time|(mask-1))==(current_time|(mask-1))) {
				break;
			}
			mask <<= TIME_LEVEL_SHIFT;
		}

		link(&T->t[i][((time>>(TIME_NEAR_SHIFT + i*TIME_LEVEL_SHIFT)) & TIME_LEVEL_MASK)],node);	
	}
}

/// ��Ӷ�ʱ��
/// \param[in] *T
/// \param[in] *arg
/// \param[in] sz
/// \param[in] time
/// \return static void
static void
timer_add(struct timer *T,void *arg,size_t sz,int time) {
	struct timer_node *node = (struct timer_node *)skynet_malloc(sizeof(*node)+sz);
	memcpy(node+1,arg,sz);

	SPIN_LOCK(T);

		node->expire=time+T->time;//��ʱʱ��+��ǰ����
		add_node(T,node);

	SPIN_UNLOCK(T);
}

//�ƶ�ĳ���������������
static void
move_list(struct timer *T, int level, int idx) {
	struct timer_node *current = link_clear(&T->t[level][idx]);
	while (current) {
		struct timer_node *temp=current->next;
		add_node(T,current);
		current=temp;
	}
}

//����һ���ǳ���Ҫ�ĺ���
//��ʱ�����ƶ���������
static void
timer_shift(struct timer *T) {
	int mask = TIME_NEAR;
	uint32_t ct = ++T->time;
	if (ct == 0) {//time�����
		move_list(T, 3, 0);
	} else {
		uint32_t time = ct >> TIME_NEAR_SHIFT;
		int i=0;

		while ((ct & (mask-1))==0) {
			int idx=time & TIME_LEVEL_MASK;
			if (idx!=0) {
				move_list(T, i, idx);
				break;				
			}
			mask <<= TIME_LEVEL_SHIFT;
			time >>= TIME_LEVEL_SHIFT;
			++i;
		}
	}
}

//�ɷ���Ϣ��Ŀ�������Ϣ����
static inline void
dispatch_list(struct timer_node *current) {
	do {
		struct timer_event * event = (struct timer_event *)(current+1);
		struct skynet_message message;
		message.source = 0;
		message.session = event->session;//�������Ҫ�����ղ࿿����ʶ�����ĸ�timer
		message.data = NULL;
		message.sz = (size_t)PTYPE_RESPONSE << MESSAGE_TYPE_SHIFT;
		//�ɷ�����ʾ����Ϣ
		skynet_context_push(event->handle, &message);
		
		struct timer_node * temp = current;
		current=current->next;
		skynet_free(temp);	
	} while (current);
}


// �ӳ�ʱ�б���ȡ��ʱ����Ϣ���ַ�
//�ɷ���Ϣ
static inline void
timer_execute(struct timer *T) {
	int idx = T->time & TIME_NEAR_MASK;
	
	while (T->near[idx].head.next) {
		struct timer_node *current = link_clear(&T->near[idx]);
		SPIN_UNLOCK(T);
		// dispatch_list don't need lock T
		dispatch_list(current);
		SPIN_LOCK(T);
	}
}

//ʱ����º����Ժ���������ø�����ʱ��
// ʱ��ÿ��һ���δ�ִ��һ�θú���
/// \param[in] *T
/// \return static void
static void 
timer_update(struct timer *T) {
	SPIN_LOCK(T);

	// try to dispatch timeout 0 (rare condition)
	timer_execute(T);

	// shift time first, and then dispatch timer message
	timer_shift(T);

	timer_execute(T);

	SPIN_UNLOCK(T);
}

/// ������ʱ��
/// \return static struct timer *
static struct timer *
timer_create_timer() {
	struct timer *r=(struct timer *)skynet_malloc(sizeof(struct timer)); // �����ڴ�
	memset(r,0,sizeof(*r)); // ��սṹ

	int i,j; // ��������

	for (i=0;i<TIME_NEAR;i++) { // TIME_NEAR: 1<<8
		link_clear(&r->near[i]); // �������
	}

	for (i=0;i<4;i++) {
		for (j=0;j<TIME_LEVEL;j++) { // TIME_LEVEL: 1<<6
			link_clear(&r->t[i][j]); // �������
		}
	}

	SPIN_INIT(r)

	r->current = 0; // ��ǰʱ��

	return r; // ���ض�ʱ���Ľṹ
}

/// ��ʱ
/// \param[in] handle
/// \param[in] time
/// \param[in] session
/// \return int
int
skynet_timeout(uint32_t handle, int time, int session) {
	if (time <= 0) {//û�г�ʱ
		struct skynet_message message;
		message.source = 0;
		message.session = session;
		message.data = NULL;
		message.sz = (size_t)PTYPE_RESPONSE << MESSAGE_TYPE_SHIFT;
		//û�г�ʱ��ֱ�ӷ���Ϣ
		if (skynet_context_push(handle, &message)) {
			return -1;
		}
	} else {//�г�ʱ
		struct timer_event event;
		event.handle = handle;
		event.session = session;
		//�г�ʱ�ļ��붨ʱ��������
		timer_add(TI, &event, sizeof(event), time);
	}

	return session;
}

//1��=1000���� milliseconds
//1����=1000΢�� microseconds
//1΢��=1000���� nanoseconds
//����timer�к���ľ��ȶ���10ms��
//Ҳ����˵�����һ������λ��������С��λ������
// centisecond: 1/100 second
static void
systime(uint32_t *sec, uint32_t *cs) {
#if !defined(__APPLE__)
	struct timespec ti;
	clock_gettime(CLOCK_REALTIME, &ti);
	*sec = (uint32_t)ti.tv_sec;		//�ѵ�һ�������������Ǿ��Ǵ�ϵͳ���������ʱ�䣬��λ����
	*cs = (uint32_t)(ti.tv_nsec / 10000000);//10����Ϊ��λ
#else
	struct timeval tv;
	gettimeofday(&tv, NULL);
	*sec = tv.tv_sec;			//1970/1/1�����ڵ�����
	*cs = tv.tv_usec / 10000;	//΢��ת���룬����10ms
#endif
}

// ����ϵͳ���������ڵ�ʱ�䣬��λ�ǰٷ�֮һ�� 0.01s
static uint64_t
gettime() {
	uint64_t t;
#if !defined(__APPLE__) // ��ƻ��ƽ̨
	struct timespec ti;
	clock_gettime(CLOCK_MONOTONIC, &ti); // ���ʱ��
	t = (uint64_t)ti.tv_sec * 100;
	t += ti.tv_nsec / 10000000;
#else // ƻ��ƽ̨
	struct timeval tv;
	gettimeofday(&tv, NULL);
	t = (uint64_t)tv.tv_sec * 100;
	t += tv.tv_usec / 10000;
#endif
	return t; // ���� t
}

/// ����ʱ��
/// \param[in] void
/// \return void
void
skynet_updatetime(void) {
	uint64_t cp = gettime();
	if(cp < TI->current_point) {
		skynet_error(NULL, "time diff error: change from %lld to %lld", cp, TI->current_point);
		TI->current_point = cp;
	} else if (cp != TI->current_point) {
		uint32_t diff = (uint32_t)(cp - TI->current_point);
		TI->current_point = cp;
		TI->current += diff;
		int i;
		for (i=0;i<diff;i++) {
			timer_update(TI);
		}
	}
}

uint32_t
skynet_starttime(void) {
	return TI->starttime;
}

uint64_t 
skynet_now(void) {
	return TI->current;
}

/// ��ʱ����ʼ��
/// \param[in] void
/// \return void
void 
skynet_timer_init(void) {
	TI = timer_create_timer(); // ������ʱ��
	uint32_t current = 0;
	systime(&TI->starttime, &current);
	TI->current = current;
	TI->current_point = gettime();
}

