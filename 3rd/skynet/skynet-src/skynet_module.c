///
/// \file skynet_module.c
/// \brief ���ض�̬���ӿ�
///
#include "skynet.h"

#include "skynet_module.h"
#include "spinlock.h"

#include <assert.h>
#include <string.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#define MAX_MODULE_TYPE 32///< ���ģ�������

/// ģ��Ľṹ
struct modules {
	int count;///< ģ�������
	struct spinlock lock;///< ��
	const char * path;///< ģ���·��
	struct skynet_module m[MAX_MODULE_TYPE];///< ģ�������
};

static struct modules * M = NULL;///< ģ��ṹ��ȫ��ָ�����

/// ���Դ�ģ��
/// \param[in] *m ģ��Ľṹ
/// \param[in] *name ģ�������
/// \return static void *
static void *
_try_open(struct modules *m, const char * name) {
	const char *l;
	const char * path = m->path;// �ӽṹ�л��ģ���·��
	size_t path_size = strlen(path); // ·���ĳ���
	size_t name_size = strlen(name);// ģ�����Ƶĳ���
	//fprintf(stderr, "_try_open %s\n", path);
	//_try_open .. / 3rd / skynet / cservice / ? .so; . / cservice / ? .so
	//_try_open .. / 3rd / skynet / cservice / ? .so; . / cservice / ? .so
	int sz = path_size + name_size;// ģ��·�������Ƶĳ���
	//search path
	void * dl = NULL;// ģ���ָ�����
	char tmp[sz]; // ģ���·�������Ʊ���
	do
	{
		memset(tmp,0,sz);// ���
		while (*path == ';') path++;// ѭ���Ƿ���� ';' �ֺ�
		if (*path == '\0') break;// ������� '\0' ������ѭ��
		l = strchr(path, ';');// �����ִ��е�һ�γ��� ';' �ֺŵ�λ��
		if (l == NULL) l = path + strlen(path);
		int len = l - path;
		int i;
		for (i=0;path[i]!='?' && i < len ;i++) {
			tmp[i] = path[i];// ѭ��ȡ�á�����֮ǰ���ַ�������ʱ�ַ����С�
		}
		memcpy(tmp+i,name,name_size);// ����ģ�����ֵ���ʱ�ַ����С�
		if (path[i] == '?') { // �����һ���ַ�Ϊ '?' ��
			strncpy(tmp+i+name_size,path+i+1,len - i - 1);// �Ӻ��渴��ģ��ĺ�׺������ʱ�ַ����С�
		} else {
			fprintf(stderr,"Invalid C service path\n");
			exit(1);
		}
		//RTLD_NOW��Ҫ��dlopen����ǰ��������ȫ��û�ж�����ţ������������������dlopen�᷵��NULL������Ϊ��: undefined symbol: xxxx.......
		//RTLD_GLOBAL����̬���ж���ķ��ſɱ����򿪵������������
		//RTLD_LOCAL�� ��RTLD_GLOBAL�����෴����̬���ж���ķ��Ų��ܱ����򿪵��������ض�λ��
		dl = dlopen(tmp, RTLD_NOW | RTLD_GLOBAL);// ��ģ��Ķ�̬���ӿ�
		path = l;
	}while(dl == NULL);// ѭ������·������';'�ֺ�Ϊ��

	if (dl == NULL) {// �����ģ���ļ�ʧ��
		fprintf(stderr, "try open %s failed : %s\n",name,dlerror());
	}

	return dl;// ���ش�ģ���ָ�����
}

/// �������Ʋ�ѯģ�����飬����ģ��ṹ��ָ��
/// \param[in] *name ģ������
/// \return static struct skynet_module *
static struct skynet_module * 
_query(const char * name) {
	int i;
	for (i=0;i<M->count;i++) {
		if (strcmp(M->m[i].name,name)==0) {
			return &M->m[i];
		}
	}
	return NULL;
}

/// �򿪺���
/// \param[in] *mod ģ��Ľṹ
/// \return static int
/*
fprintf(stderr, "_open_sym %s %s.\n", mod->name,tmp);
_open_sym harbor harbor_create.
_open_sym harbor harbor_init.
_open_sym harbor harbor_release.
_open_sym harbor harbor_signal.
*/
static int
_open_sym(struct skynet_module *mod) {
	size_t name_size = strlen(mod->name);// ģ�����Ƶĳ���
	char tmp[name_size + 9]; // create/init/release/signal , longest name is release (7)
	memcpy(tmp, mod->name, name_size);// ����ģ�����Ƶ���ʱ�ַ���
	strcpy(tmp+name_size, "_create"); // ���ơ�_create������ʱ�ַ���
	mod->create = dlsym(mod->module, tmp);// ��ģ����+��_create���ĺ���
	//fprintf(stderr, "_open_sym %s %s.\n", mod->name, tmp);
	strcpy(tmp+name_size, "_init");// ���ơ�_init������ʱ�ַ���
	mod->init = dlsym(mod->module, tmp);// ��ģ����+��_init���ĺ���
	//fprintf(stderr, "_open_sym %s %s.\n", mod->name, tmp);
	strcpy(tmp+name_size, "_release");// ���ơ�_release������ʱ�ַ���
	mod->release = dlsym(mod->module, tmp);// ��ģ����+��_release���ĺ���
	//fprintf(stderr, "_open_sym %s %s.\n", mod->name, tmp);
	strcpy(tmp+name_size, "_signal");
	mod->signal = dlsym(mod->module, tmp);
	//fprintf(stderr, "_open_sym %s %s.\n", mod->name,tmp);
	return mod->init == NULL;// �ж��Ƿ�Ϊ�գ���������
}

/// ��ѯģ��
/// \param[in] *name ģ�������
/// \return struct skynet_module *
struct skynet_module * 
skynet_module_query(const char * name) {
	struct skynet_module * result = _query(name);// ���ģ�������Ƿ������ģ��
	if (result)
		return result;// ����������ģ�飬�򷵻����ģ���ָ��

	SPIN_LOCK(M)// ��������ģ������

	result = _query(name); // double check �ٴμ��ģ�������Ƿ������ģ��

	if (result == NULL && M->count < MAX_MODULE_TYPE) {// ���û���ҵ�����ģ������С�����ģ����
		int index = M->count; // ����ģ��������±�Ϊģ����
		void * dl = _try_open(M,name);// ���Դ�ģ��
		if (dl) {// �����ģ��ɹ�
			M->m[index].name = name;// �����ָ�ֵ��ģ�������е�Ԫ��
			M->m[index].module = dl;// ��ģ��ָ�븳ֵ��ģ�������е�Ԫ��

			if (_open_sym(&M->m[index]) == 0) {// ��ģ���еĺ���
				M->m[index].name = skynet_strdup(name);
				M->count ++;// ģ���� +1
				result = &M->m[index];// ����ģ��Ľṹָ��
			}
		}
	}

	SPIN_UNLOCK(M)// ����

	return result;// ����ģ��Ľṹָ��
}

/// ����ģ��ṹ��ģ��������
/// \param[in] *mod ģ��Ľṹ
/// \return void
void 
skynet_module_insert(struct skynet_module *mod) {
	SPIN_LOCK(M)// ������סģ������

	struct skynet_module * m = _query(mod->name);// ��ѯģ���Ƿ���������
	assert(m == NULL && M->count < MAX_MODULE_TYPE); // ����ģ��Ϊ�գ�������������ģ�������
	int index = M->count;// ����ģ��������±�Ϊģ����
	M->m[index] = *mod;// ��ģ��ṹָ�븳ֵ������
	++M->count; // ģ���� +1

	SPIN_UNLOCK(M)// ����
}

/// ʵ������������
/// \param[in] *m
/// \return void *
void * 
skynet_module_instance_create(struct skynet_module *m) {
	if (m->create) {// ����������ָ��
		return m->create();// ִ��ģ���еĴ�������
	} else {
		return (void *)(intptr_t)(~0);// ���ؿ�ָ��
	}
}

/// ʵ������ʼ������
/// \param[in] *m
/// \param[in] *inst
/// \param[in] *ctx
/// \param[in] *parm
/// \return int
/// \retval 0 �ɹ�
/// \retval 1 ʧ��
int
skynet_module_instance_init(struct skynet_module *m, void * inst, struct skynet_context *ctx, const char * parm) {
	return m->init(inst, ctx, parm);// ִ��ģ���еĳ�ʼ������
}

/// ʵ�����ͷź���
/// \param[in] *m
/// \param[in] *inst
/// \return void
void 
skynet_module_instance_release(struct skynet_module *m, void *inst) {
	if (m->release) {// ����������ָ��
		m->release(inst); // ִ��ģ���е��ͷź���
	}
}

void
skynet_module_instance_signal(struct skynet_module *m, void *inst, int signal) {
	if (m->signal) {
		m->signal(inst, signal);
	}
}

/// ģ���ʼ��
/// \param[in] *path
/// \return void
void 
skynet_module_init(const char *path) {
	struct modules *m = skynet_malloc(sizeof(*m));// ����ģ��ṹ���ڴ�
	m->count = 0;// ģ������Ϊ0
	m->path = skynet_strdup(path);// ģ���·��

	SPIN_INIT(m)

	M = m;// ��ֵ��ȫ��ģ��ṹ����
}
