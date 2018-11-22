#include <stdlib.h>
#include <stdio.h>
// ����ͳ���ڴ��������ͷŴ���ƥ��
static int _g = 0;

void * _pbcM_malloc(size_t sz) {
	++ _g;
	return malloc(sz);
}

void _pbcM_free(void *p) {
	if (p) {
		-- _g;
		free(p);
	}
}

void* _pbcM_realloc(void *p, size_t sz) {
	return realloc(p,sz);
}

void _pbcM_memory() {
	printf("%d\n",_g);	
}

// ����ڵ㣬���ڼ�¼ÿһ���ڴ���׵�ַ
struct heap_page {
	struct heap_page * next;
};

// �����������ڣ����Ӽ�¼��һ��heap_page�ڵ�ĳߴ���Ϣ�������ڵ㲻���¼
struct heap {
	struct heap_page *current;
	int size;
	int used;
};

struct heap * 
_pbcH_new(int pagesize) {
	int cap = 1024;
	// ��֤cap����pagesize������1024�ı���
	while(cap < pagesize) {
		cap *= 2;
	}
	 // heap�ṹ�еĳߴ��¼����currentָ���heap_page�ڵ�
	struct heap * h = (struct heap *)_pbcM_malloc(sizeof(struct heap));
    // ��������ڴ�����ߴ� sizeof(struct heap_page) + cap
    // ���������ڴ�ߴ�Ϊ cap��������Ҫ���ڴ��ͷ����������ڵ㼴sizeof(struct heap_page)����������heap_page��ÿ���ڴ洮������
    // Ҳ����ÿ���ڴ�鶼Ҫ��ͷ������ʹ��struct heap_page�ṹ����	
	h->current = (struct heap_page *)_pbcM_malloc(sizeof(struct heap_page) + cap);
	h->size = cap;
	h->used = 0;
	h->current->next = NULL;
	return h;
}

void 
_pbcH_delete(struct heap *h) {
	// ����heap_page��ȫ��ɾ��
	struct heap_page * p = h->current;
	struct heap_page * next = p->next;
	for(;;) {
		_pbcM_free(p);
		if (next == NULL)
			break;
		p = next;
		next = p->next;
	}
	_pbcM_free(h);
}

//��heap�Ϸ������size���ڴ沢����ָ��
void* 
_pbcH_alloc(struct heap *h, int size) {
	// ȡ�õ�size���ڴ����size������4�ı���
	size = (size + 3) & ~3;
	// �ж�heap->currentָ���heap_page�Ƿ����㹻���ڴ�ռ�
	if (h->size - h->used < size) {
		struct heap_page * p;
		// heap->size��Ĭ�ϵ�ÿ���ڴ��Ĵ�С�������Ի�������heap->size�ߴ���ڴ��
		if (size < h->size) {
			p = (struct heap_page *)_pbcM_malloc(sizeof(struct heap_page) + h->size);
		} else {
			p = (struct heap_page *)_pbcM_malloc(sizeof(struct heap_page) + size);
		}
		// ֱ�ӽ��´������ڴ����뵽����ͷ��heapҲֻ��¼�´������ڴ�飬ԭ�����ڴ�鱻��������ֻ�ܵȴ��������ڴ��ͷ�
		p->next = h->current;
		h->current = p;
		h->used = size;
		 // (p+1) ��Ϊ��ָ���������ڴ棬������ÿ���ڴ��ͷ����heap_page�ṹ��p+1�����ƶ�һ��heap_page�Ŀռ�
		return (p+1);
	} else {
		// �����ڴ��δʹ�ò���
        // (char *)(h->current + 1) ��Ϊ��ָ���������ڴ棬������ÿ���ڴ��ͷ����heap_page�ṹ
		char * buffer = (char *)(h->current + 1);
		buffer += h->used;
		h->used += size;
		return buffer;
	}
}
