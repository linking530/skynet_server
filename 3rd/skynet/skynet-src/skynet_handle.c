///
/// \file skynet_handle.c
/*
SKYNET�����������ģ�鱻��Ϊ���񡣡������������ɷ�����Ϣ��
ÿ��ģ������� Skynet ���ע��һ�� callback �������������շ���������Ϣ��
�����ᵽ����һ�����Ϲ淶�� C ģ�飬�Ӷ�̬�⣨so �ļ�����������������һ�������ظ�����ʹģ���˳��������� id ��Ϊ�� handle ��
Skynet �ṩ�����ַ��񣬻����Ը��ض��ķ�����һ���׶������֣��������� id ��ָ������id ������ʱ̬��أ��޷���֤ÿ����������
����һ�µ� id �������ֿ��ԡ�������Ҫ�����������ļ�skynet_handle.c��skynet_handle.h����ʵ�����ַ���ġ�
��WIKI�е�CLUSTER��������harbor��ص����ݣ���ÿ�� skynet ������һ��ȫ��Ψһ�ĵ�ַ�������ַ��һ�� 32bit ���֣�
��� 8bit ��ʶ�������� slave �ĺ��롣�� harbor id ���� master/slave �����У�
id Ϊ 0 �Ǳ����ġ������������� 255 �� slave �ڵ㡣��

�������и����������ƣ�����s->slot_size-1�����ĵ�λ��������Զ����1��
lot_size��4��4-1����3�������Ժ���8��8-1����7��Ȼ��16,32....�������Ļ������κ�����������������ᶪʧ����Ч�ġ���λ��
*/

#include "skynet.h"

#include "skynet_handle.h"
#include "skynet_server.h"
#include "rwlock.h"

#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#define DEFAULT_SLOT_SIZE 4
#define MAX_SLOT_SIZE 0x40000000

struct handle_name {
	char * name; //��������
	uint32_t handle; //����ID��������handle���ƺ�
};

struct handle_storage {
	struct rwlock lock; ///< ��

	uint32_t harbor; ///< �ڵ� �����wiki���ᵽ��harbor 
	uint32_t handle_index; ///< ������� �����1��ʼ
	int slot_size; ///< �۵Ĵ�С,���鳤��
	struct skynet_context ** slot; //���飬ʵ�����������Ƿ����������
	
	int name_cap;//���������������
	int name_count;//ע����habor���ֳ��ȵķ���������
	struct handle_name *name; ///< �������������
};

static struct handle_storage *H = NULL; ///< ȫ�ֽṹ������ָ��

//ע����񣬷��ظ���һ��handle
/// \param[in] *ctx
/// \return uint32_t
uint32_t
skynet_handle_register(struct skynet_context *ctx) {
	struct handle_storage *s = H; // ����Ϊȫ�ֱ���

	rwlock_wlock(&s->lock); // ����
	
	for (;;) {
		int i;
		for (i=0;i<s->slot_size;i++) { //���������б��Ҹ���λ
			uint32_t handle = (i+s->handle_index) & HANDLE_MASK; //ֻȡ��24λ
			int hash = handle & (s->slot_size-1);//����(handle+s->slot_size)%s->slot_size�Ĳ�����
			if (s->slot[hash] == NULL) {////û��hash��ײ������
				s->slot[hash] = ctx;
				s->handle_index = handle + 1;//handle_index������

				rwlock_wunlock(&s->lock); // ����

				handle |= s->harbor;// λ�����򣬰�harborǰ8λ����24λΪs->slot[hash] 
				return handle;
			}
		}
		assert((s->slot_size*2 - 1) <= HANDLE_MASK); //slot_size�ǲ��Ǵﵽ0xffffff+1��һ���ˣ�
		struct skynet_context ** new_slot = skynet_malloc(s->slot_size * 2 * sizeof(struct skynet_context *)); // �����ڴ�
		memset(new_slot, 0, s->slot_size * 2 * sizeof(struct skynet_context *)); // ��սṹ
		//�������ݿ�������Ҫ����hash������handle_indexû����
		for (i=0;i<s->slot_size;i++) {
			int hash = skynet_context_handle(s->slot[i]) & (s->slot_size * 2 - 1);
			//fprintf(stderr, "reset hash %d %d %d %d\n", skynet_context_handle(s->slot[i]), s->slot_size, hash, i);
			//reset hash 4 4 4 0
			//reset hash 1 4 1 1
			//reset hash 2 4 2 2
			//reset hash 3 4 3 3
			assert(new_slot[hash] == NULL); // ����
			new_slot[hash] = s->slot[i];
		}
		skynet_free(s->slot); // �ͷ�
		s->slot = new_slot;
		s->slot_size *= 2;
	}
}

/// �ջؾ��
/// \param[in] handle
/// \return void
int
skynet_handle_retire(uint32_t handle) {
	int ret = 0;
	struct handle_storage *s = H; // ȫ�ֱ���

	rwlock_wlock(&s->lock); // ����
	//ȡ��Чλhash
	uint32_t hash = handle & (s->slot_size-1);
	//ȡ���������ģ�һ���Ҫ�ͷŵ�
	struct skynet_context * ctx = s->slot[hash];
	//������������Ǵ��ڵģ�����ȷʵ��Ӧ�ľ������handle
	if (ctx != NULL && skynet_context_handle(ctx) == handle) {
		s->slot[hash] = NULL;//�ѿ�λ�ó���
		ret = 1;
		int i;
		int j=0, n=s->name_count;
		for (i=0; i<n; ++i) {
			if (s->name[i].handle == handle) {
				skynet_free(s->name[i].name);//�ͷ��ڴ�
				continue;
			} else if (i!=j) {//������������Ԫ��ɾ���������Ѻ���Ķ���ǰ��һ��
				s->name[j] = s->name[i];
			}
			++j;//Ԫ��ɾ������
		}
		s->name_count = j;
	} else {
		ctx = NULL;
	}

	rwlock_wunlock(&s->lock);
	//������ͷŷ�����
	if (ctx) {
		// release ctx may call skynet_handle_* , so wunlock first.
		skynet_context_release(ctx);
	}

	return ret;
}

/// �������о��
/// return void
void 
skynet_handle_retireall() {
	struct handle_storage *s = H;
	for (;;) {
		int n=0;
		int i;
		for (i=0;i<s->slot_size;i++) {
			rwlock_rlock(&s->lock); // ����
			struct skynet_context * ctx = s->slot[i];
			uint32_t handle = 0;
			if (ctx)
				handle = skynet_context_handle(ctx);
			rwlock_runlock(&s->lock); // ����
			if (handle != 0) {
				if (skynet_handle_retire(handle))// ���վ��
				 {
					++n;
				}
			}
		}
		if (n==0)
			return;
	}
}

/// ����handleֵ���ض�Ӧ�ķ���
/// \param[in] handle
/// \return struct skynet_context *
struct skynet_context * 
skynet_handle_grab(uint32_t handle) {
	struct handle_storage *s = H;
	struct skynet_context * result = NULL;

	rwlock_rlock(&s->lock);

	uint32_t hash = handle & (s->slot_size-1);
	struct skynet_context * ctx = s->slot[hash];
	if (ctx && skynet_context_handle(ctx) == handle) {
		result = ctx;
		skynet_context_grab(result);//���ü���+1
	}

	rwlock_runlock(&s->lock);

	return result;
}

/// �������ֲ��Ҿ��
//�㷨�Ƕ��ֲ��ҷ�
//���ֲ��ҷ�������googe/bing/baidu
/// \param[in] *name
/// \return uint32_t
uint32_t 
skynet_handle_findname(const char * name) {
	struct handle_storage *s = H; // ȫ�ֱ���

	rwlock_rlock(&s->lock); // ����

	uint32_t handle = 0;

	int begin = 0;
	int end = s->name_count - 1;
	while (begin<=end) {
		int mid = (begin+end)/2;
		struct handle_name *n = &s->name[mid];
		int c = strcmp(n->name, name); //strcmp�Ǹ�cϵͳ����
		if (c==0) {//�ҵ�ƥ�������
			handle = n->handle;
			break;
		}
		if (c<0) {//��ǰλ�õ����� < Ҫ���ҵ����֣�����벿��ȥ��
			begin = mid + 1;
		} else {//��ǰλ�õ����� > Ҫ���ҵ����֣���ǰ�벿��ȥ��
			end = mid - 1;
		}
	}

	rwlock_runlock(&s->lock);

	return handle;
}

//��name���뵽name������beforeλ�ã��ٹ���handle
/// ��֮ǰ��������
/// \param[in] *s
/// \param[in] *name
/// \param[in] handle
/// \param[in] before
/// \return static void
static void
_insert_name_before(struct handle_storage *s, char *name, uint32_t handle, int before) {
	//����
	if (s->name_count >= s->name_cap) {
		s->name_cap *= 2;//����
		assert(s->name_cap <= MAX_SLOT_SIZE);
		struct handle_name * n = skynet_malloc(s->name_cap * sizeof(struct handle_name));//��һ�������飬�����������ݵ�2��
		int i;
		for (i=0;i<before;i++) {//����beforeλ��ǰ������
			n[i] = s->name[i];
		}
		for (i=before;i<s->name_count;i++) {//����before�����������
			n[i+1] = s->name[i];
		}
		skynet_free(s->name);//���������ڴ������
		s->name = n;//�������������
	} else {
		int i;
		for (i=s->name_count;i>before;i--) {//�Ӻ���ǰ��һ��һ���ƶ�����Ԫ�أ���beforeλ�ÿճ���
			s->name[i] = s->name[i-1];
		}
	}
	s->name[before].name = name;
	s->name[before].handle = handle;
	s->name_count ++;
}

//��handle��һ��name
//name����С����˳�����е�
//���ֲ��ҷ�
/// \param[in] *s
/// \param[in] *name
/// \param[in] handle
static const char *
_insert_name(struct handle_storage *s, const char * name, uint32_t handle) {
	int begin = 0;
	int end = s->name_count - 1;
	while (begin<=end) {
		int mid = (begin+end)/2;
		struct handle_name *n = &s->name[mid];
		int c = strcmp(n->name, name);
		if (c==0) {
			return NULL;
		}
		if (c<0) {
			begin = mid + 1;
		} else {
			end = mid - 1;
		}
	}
	char * result = skynet_strdup(name);

	_insert_name_before(s, result, handle, begin);

	return result;
}

///
/// \param[in] handle
/// \param[in] *name
/// \return const char *
const char * 
skynet_handle_namehandle(uint32_t handle, const char *name) {
	rwlock_wlock(&H->lock);

	const char * ret = _insert_name(H, name, handle);

	rwlock_wunlock(&H->lock);

	return ret;
}

/// ��ʼ�����
/// \param[in] harbor
/// \return void
//
void 
skynet_handle_init(int harbor) {
	assert(H==NULL); // ����
	struct handle_storage * s = skynet_malloc(sizeof(*H)); // �����ڴ�
	s->slot_size = DEFAULT_SLOT_SIZE; // ����Ĭ�ϲ۵Ĵ�С =4
	s->slot = skynet_malloc(s->slot_size * sizeof(struct skynet_context *)); // ����slot_size���ڴ�
	memset(s->slot, 0, s->slot_size * sizeof(struct skynet_context *));

	rwlock_init(&s->lock); // ��ʼ����
	// reserve 0 for system harbor���ڸ�8λ
	s->harbor = (uint32_t) (harbor & 0xff) << HANDLE_REMOTE_SHIFT;
	s->handle_index = 1;
	s->name_cap = 2;
	s->name_count = 0;
	s->name = skynet_malloc(s->name_cap * sizeof(struct handle_name)); // �����ڴ�

	H = s; // ����ȫ�ֱ���

	// Don't need to free H ������Ҫ�ͷ� H
}

