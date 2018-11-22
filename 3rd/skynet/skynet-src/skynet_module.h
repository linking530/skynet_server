#ifndef SKYNET_MODULE_H
#define SKYNET_MODULE_H

struct skynet_context;

// ����ָ������
typedef void * (*skynet_dl_create)(void);
typedef int (*skynet_dl_init)(void * inst, struct skynet_context *, const char * parm);
typedef void (*skynet_dl_release)(void * inst);
typedef void (*skynet_dl_signal)(void * inst, int signal);

struct skynet_module {
	const char * name;// ģ������
	void * module;// ģ��ָ��
	skynet_dl_create create;// ����������ָ��
	skynet_dl_init init;// ������ʼ��������ָ��
	skynet_dl_release release; // �����ͷź�����ָ��
	skynet_dl_signal signal;
};

void skynet_module_insert(struct skynet_module *mod);// ����ģ�鵽������
struct skynet_module * skynet_module_query(const char * name);// ��ѯģ���Ƿ�������
void * skynet_module_instance_create(struct skynet_module *); // ��������
int skynet_module_instance_init(struct skynet_module *, void * inst, struct skynet_context *ctx, const char * parm);// ��ʼ������
void skynet_module_instance_release(struct skynet_module *, void *inst);// �ͷź���
void skynet_module_instance_signal(struct skynet_module *, void *inst, int signal);

void skynet_module_init(const char *path);// ��ʼ��ģ��

#endif
