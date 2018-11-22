#include <stdlib.h>
#include <stdio.h>
// 用于统计内存的申请和释放次数匹配
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

// 链表节点，用于记录每一块内存的首地址
struct heap_page {
	struct heap_page * next;
};

// 整个链表的入口，附加记录第一个heap_page节点的尺寸信息，后续节点不会记录
struct heap {
	struct heap_page *current;
	int size;
	int used;
};

struct heap * 
_pbcH_new(int pagesize) {
	int cap = 1024;
	// 保证cap大于pagesize并且是1024的倍数
	while(cap < pagesize) {
		cap *= 2;
	}
	 // heap结构中的尺寸记录的是current指向的heap_page节点
	struct heap * h = (struct heap *)_pbcM_malloc(sizeof(struct heap));
    // 这里这个内存申请尺寸 sizeof(struct heap_page) + cap
    // 申请的这块内存尺寸为 cap，但是需要在内存块头部附加链表节点即sizeof(struct heap_page)，这样就用heap_page把每块内存串起来了
    // 也就是每个内存块都要在头部额外使用struct heap_page结构串联	
	h->current = (struct heap_page *)_pbcM_malloc(sizeof(struct heap_page) + cap);
	h->size = cap;
	h->used = 0;
	h->current->next = NULL;
	return h;
}

void 
_pbcH_delete(struct heap *h) {
	// 遍历heap_page，全部删除
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

//从heap上分配大于size的内存并返回指针
void* 
_pbcH_alloc(struct heap *h, int size) {
	// 取得的size大于传入的size并且是4的倍数
	size = (size + 3) & ~3;
	// 判断heap->current指向的heap_page是否有足够的内存空间
	if (h->size - h->used < size) {
		struct heap_page * p;
		// heap->size是默认的每个内存块的大小，若可以还是申请heap->size尺寸的内存块
		if (size < h->size) {
			p = (struct heap_page *)_pbcM_malloc(sizeof(struct heap_page) + h->size);
		} else {
			p = (struct heap_page *)_pbcM_malloc(sizeof(struct heap_page) + size);
		}
		// 直接将新创建的内存块插入到链表头，heap也只记录新创建的内存块，原来的内存块被链表串连，只能等待后续的内存释放
		p->next = h->current;
		h->current = p;
		h->used = size;
		 // (p+1) 是为了指向真正的内存，而不是每个内存块头部的heap_page结构，p+1就是移动一个heap_page的空间
		return (p+1);
	} else {
		// 返回内存块未使用部分
        // (char *)(h->current + 1) 是为了指向真正的内存，而不是每个内存块头部的heap_page结构
		char * buffer = (char *)(h->current + 1);
		buffer += h->used;
		h->used += size;
		return buffer;
	}
}
