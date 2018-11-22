#include "map.h"
#include "alloc.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct _pbcM_ip_slot {
	int id;
	void * pointer;
	int next;
};

struct map_ip {
	size_t array_size;
	void ** array;
	size_t hash_size;
	struct _pbcM_ip_slot * slot;
};

struct _pbcM_si_slot {
	const char *key;
	size_t hash;
	int id;
	int next;
};

struct map_si {
	size_t size;
	struct _pbcM_si_slot slot[1];
};
// Justin Sobel写的一个位操作的哈希函数。
static size_t
calc_hash(const char *name)
{
	size_t len = strlen(name);
	size_t h = len;
	size_t step = (len>>5)+1;
	size_t i;
	for (i=len; i>=step; i-=step)
	    h = h ^ ((h<<5)+(h>>2)+(size_t)name[i-1]);
	return h;
}

//struct map_si * map2 = _pbcM_si_new(kv, sizeof(kv)/sizeof(kv[0]));
struct map_si *
_pbcM_si_new(struct map_kv * table, int size)
{
	//printf("_pbcM_si_new : %p %d\n", table, size);
	size_t sz = sizeof(struct map_si) + (size-1) * sizeof(struct _pbcM_si_slot);
	struct map_si * ret = (struct map_si *)malloc(sz);
	memset(ret,0,sz);

	ret->size = (size_t)size;

	int empty = 0;
	int i;

	for (i=0;i<size;i++) {
		size_t hash_full = calc_hash((const char *)table[i].pointer);
		size_t hash = hash_full % size;
		struct _pbcM_si_slot * slot = &ret->slot[hash];
		if (slot->key == NULL) {
			slot->key = (const char *)table[i].pointer;
			slot->id = table[i].id;
			slot->hash = hash_full;
		} else {
			while(ret->slot[empty].key != NULL) {
				++empty;
			}
			struct _pbcM_si_slot * empty_slot = &ret->slot[empty];
			empty_slot->next = slot->next;
			slot->next = empty + 1;
			empty_slot->id = table[i].id;
			empty_slot->key = (const char *)table[i].pointer;
			empty_slot->hash = hash_full;
		}
	}

	return ret;
}

void
_pbcM_si_delete(struct map_si *map)
{
	//printf("_pbcM_si_delete : %p\n", map);
	free(map);
}

int
_pbcM_si_query(struct map_si *map, const char *key, int *result)
{
	//printf("_pbcM_si_query : %p %s %d\n", map, key , *result);
	size_t hash_full = calc_hash(key);
	size_t hash = hash_full % map->size;

	struct _pbcM_si_slot * slot = &map->slot[hash];
	for (;;) {
		if (slot->hash == hash_full && strcmp(slot->key, key) == 0) {
			*result = slot->id;
			return 0;
		}
		if (slot->next == 0) {
			return 1;
		}
		slot = &map->slot[slot->next-1];
	}
}

static struct map_ip *
_pbcM_ip_new_hash(struct map_kv * table, int size)
{
	//printf("_pbcM_ip_new_hash : %p %d\n", table, size);
	struct map_ip * ret = (struct map_ip *)malloc(sizeof(struct map_ip));
	ret->array = NULL;
	ret->array_size = 0;
	ret->hash_size = (size_t)size;
	ret->slot = (struct _pbcM_ip_slot *)malloc(sizeof(struct _pbcM_ip_slot) * size);
	memset(ret->slot,0,sizeof(struct _pbcM_ip_slot) * size);
	int empty = 0;
	int i;
	for (i=0;i<size;i++) {
		int hash = ((unsigned)table[i].id) % size;
		struct _pbcM_ip_slot * slot = &ret->slot[hash];
		if (slot->pointer == NULL) {
			slot->pointer = table[i].pointer;
			slot->id = table[i].id;
		} else {
			while(ret->slot[empty].pointer != NULL) {
				++empty;
			}
			struct _pbcM_ip_slot * empty_slot = &ret->slot[empty];
			empty_slot->next = slot->next;
			slot->next = empty + 1;
			empty_slot->id = table[i].id;
			empty_slot->pointer = table[i].pointer;
		}
	}
	return ret;
}

//_pbcM_ip_new(kv, sizeof(kv) / sizeof(kv[0]));
struct map_ip *
_pbcM_ip_new(struct map_kv * table, int size)
{
	//printf("_pbcM_ip_new : %p %d\n", table, size);
	int i;
	int max = table[0].id;
	if (max > size * 2 || max < 0)
		return _pbcM_ip_new_hash(table,size);
	for (i=1;i<size;i++) {
		if (table[i].id < 0) {
			return _pbcM_ip_new_hash(table,size);
		}
		if (table[i].id > max) {
			max = table[i].id;
			if (max > size * 2)
				return _pbcM_ip_new_hash(table,size);
		}
	}
	struct map_ip * ret = (struct map_ip *)malloc(sizeof(struct map_ip));
	ret->hash_size = size;
	ret->slot = NULL;
	ret->array_size = max + 1;
	ret->array = (void **)malloc((max+1) * sizeof(void *));
	memset(ret->array,0,(max+1) * sizeof(void *));
	for (i=0;i<size;i++) {
		ret->array[table[i].id] = table[i].pointer;
	}
	return ret;
}

void
_pbcM_ip_delete(struct map_ip * map)
{
	//printf("_pbcM_ip_delete : %p\n", map);
	if (map) {
		free(map->array);
		free(map->slot);
		free(map);
	}
}

static void
_inject(struct map_kv * table, struct map_ip *map)
{
	//printf("_inject : %p %p\n", table,map);
	if (map->array) {
		int n = 0;
		int i;
		for (i=0;i<(int)map->array_size;i++) {
			if (map->array[i]) {
				table[n].id = i;
				table[n].pointer = map->array[i];
				++ n;
			}
		}
	} else {
		int i;
		for (i=0;i<(int)map->hash_size;i++) {
			table[i].id = map->slot[i].id;
			table[i].pointer = map->slot[i].pointer;
		}
	}
}

struct map_ip *
_pbcM_ip_combine(struct map_ip *a, struct map_ip *b)
{
	//printf("_pbcM_ip_combine : %p %p\n", a, b);
	int sz = (int)(a->hash_size + b->hash_size);
	struct map_kv * table = (struct map_kv *)malloc(sz * sizeof(struct map_kv));
	memset(table , 0 , 	sz * sizeof(struct map_kv));
	_inject(table, a);
	_inject(table + a->hash_size, b);
	struct map_ip * r = _pbcM_ip_new(table, sz);
	free(table);
	return r;
}

//返回i位置的对象指针key和_pbcM_si_query函数配合使用
//void *p = _pbcM_ip_query(map, i);
//if (p) {
//	int id = 0;
//	_pbcM_si_query(map2, p, &id);
//	printf("%d %s\n", id, (const char *)p);
//}
void *
_pbcM_ip_query(struct map_ip * map, int id)
{
	//printf("_pbcM_ip_query : %p %d\n", map, id);
	if (map == NULL)
		return NULL;
	if (map->array) {
		if (id>=0 && id<(int)map->array_size)
			return map->array[id];
		return NULL;
	}
	int hash = (unsigned)id % map->hash_size;
	struct _pbcM_ip_slot * slot = &map->slot[hash];
	for (;;) {
		if (slot->id == id) {
			return slot->pointer;
		}
		if (slot->next == 0) {
			return NULL;
		}
		slot = &map->slot[slot->next-1];
	}
}

struct _pbcM_sp_slot {
	const char *key;
	size_t hash;
	void *pointer;
	int next;
};

struct map_sp {
	size_t cap;
	size_t size;
	struct heap *heap;
	struct _pbcM_sp_slot * slot;
};

//创建一个_pbcM_sp_slot的个数大于等于max的map_sp

struct map_sp *
_pbcM_sp_new(int max , struct heap *h)
{
	//printf("_pbcM_sp_new : %d %p\n", max, h);
	struct map_sp * ret = (struct map_sp *)HMALLOC(sizeof(struct map_sp));
	int cap = 1;
	while (cap < max) {
		cap *=2;
	}
	ret->cap = cap;
	ret->size = 0;
	ret->slot = (struct _pbcM_sp_slot *)HMALLOC(ret->cap * sizeof(struct _pbcM_sp_slot));
	memset(ret->slot,0,sizeof(struct _pbcM_sp_slot) * ret->cap);
	ret->heap = h;
	return ret;
}

void
_pbcM_sp_delete(struct map_sp *map)
{
	//printf("_pbcM_sp_delete :  %p\n", map);
	if (map && map->heap == NULL) {
		_pbcM_free(map->slot);
		_pbcM_free(map);
	}
}

static void _pbcM_sp_rehash(struct map_sp *map);

static void
_pbcM_sp_insert_hash(struct map_sp *map, const char *key, size_t hash_full, void * value)
{
	//printf("_pbcM_sp_insert_hash : %p %s %d \n", map,key,(int*)value);
	if (map->cap > map->size) {
		size_t hash = hash_full & (map->cap-1);
		struct _pbcM_sp_slot * slot = &map->slot[hash];
		if (slot->key == NULL) {
			slot->key = key;
			slot->pointer = value;
			slot->hash = hash_full;
		} else {
			int empty = (hash + 1) & (map->cap-1);
			while(map->slot[empty].key != NULL) {
				empty = (empty + 1) & (map->cap-1);
			}
			struct _pbcM_sp_slot * empty_slot = &map->slot[empty];
			empty_slot->next = slot->next;
			slot->next = empty + 1;
			empty_slot->pointer = value;
			empty_slot->key = key;
			empty_slot->hash = hash_full;
		}
		map->size++;
		return;
	}
	_pbcM_sp_rehash(map);
	_pbcM_sp_insert_hash(map, key, hash_full, value);
}

static void
_pbcM_sp_rehash(struct map_sp *map) {
	//printf("_pbcM_sp_rehash : %p\n", map );
	struct heap * h = map->heap;
	struct _pbcM_sp_slot * old_slot = map->slot;
	size_t size = map->size;
	map->size = 0;
	map->cap *= 2;
	map->slot = (struct _pbcM_sp_slot *)HMALLOC(sizeof(struct _pbcM_sp_slot)*map->cap);
	memset(map->slot,0,sizeof(struct _pbcM_sp_slot)*map->cap);
	size_t i;
	for (i=0;i<size;i++) {
		_pbcM_sp_insert_hash(map, old_slot[i].key, old_slot[i].hash, old_slot[i].pointer);
	}
	if (h == NULL) {
		_pbcM_free(old_slot);
	}
}

//_pbcM_sp_query_insert_hash(map, key, calc_hash(key))
static void **
_pbcM_sp_query_insert_hash(struct map_sp *map, const char *key, size_t hash_full)
{
	//printf("_pbcM_sp_query_insert_hash : %p %s %d \n", map, key, hash_full);
	//确定元素存放在哪个桶中，桶为空，新生成结点放入桶中(此时，这个结点是放在数组中)
	size_t hash = hash_full & (map->cap-1);
	struct _pbcM_sp_slot * slot = &map->slot[hash];
	if (slot->key == NULL) {
		if (map->cap <= map->size)
			goto _rehash;
		slot->key = key;
		slot->hash = hash_full;
		map->size++;
		return &(slot->pointer);
	} else {
		for (;;) {
			//hash值相等，并且key值相等
			if (slot->hash == hash_full && strcmp(slot->key, key) == 0)
				return &(slot->pointer);
			if (slot->next == 0) {
				break;
			}
			slot = &map->slot[slot->next-1];
		}
		if (map->cap <= map->size)
			goto _rehash;

		int empty = (hash + 1) & (map->cap-1);
		while(map->slot[empty].key != NULL) {
			empty = (empty + 1) & (map->cap-1);
		}
		struct _pbcM_sp_slot * empty_slot = &map->slot[empty];
		empty_slot->next = slot->next;
		slot->next = empty + 1;
		empty_slot->key = key;
		empty_slot->hash = hash_full;

		map->size++;

		return &(empty_slot->pointer);
	}
_rehash:
	_pbcM_sp_rehash(map);
	return _pbcM_sp_query_insert_hash(map, key, hash_full);
}

void
_pbcM_sp_insert(struct map_sp *map, const char *key, void * value)
{
	//printf("_pbcM_sp_insert : %p %s %d \n", map, key, (int*)value);
	_pbcM_sp_insert_hash(map,key,calc_hash(key),value);
}

//void ** r = _pbcM_sp_query_insert(map3, "Carol");
//*r = "carol";
void **
_pbcM_sp_query_insert(struct map_sp *map, const char *key)
{
	//printf("_pbcM_sp_query_insert : %p %s\n", map, key);
	return _pbcM_sp_query_insert_hash(map,key,calc_hash(key));
}

void *
_pbcM_sp_query(struct map_sp *map, const char *key)
{
	//printf("_pbcM_sp_query : %p %s\n", map, key);
	if (map == NULL)
		return NULL;
	size_t hash_full = calc_hash(key);
	size_t hash = hash_full & (map->cap -1);

	struct _pbcM_sp_slot * slot = &map->slot[hash];
	for (;;) {
		if (slot->hash == hash_full && strcmp(slot->key, key) == 0) {
			return slot->pointer;
		}
		if (slot->next == 0) {
			return NULL;
		}
		slot = &map->slot[slot->next-1];
	}
}

void
_pbcM_sp_foreach(struct map_sp *map, void (*func)(void *p))
{
	//printf("_pbcM_sp_foreach : %p %p\n", map, func);
	size_t i;
	for (i=0;i<map->cap;i++) {
		if (map->slot[i].pointer) {
			func(map->slot[i].pointer);
		}
	}
}

//struct pbc_wmessage *m；
//_pbcM_sp_foreach_ud(m->packed, _pack_packed, m);
//map_sp遍历,并对每个节点调用func函数
void
_pbcM_sp_foreach_ud(struct map_sp *map, void (*func)(void *p, void *ud), void *ud)
{
	//printf("_pbcM_sp_foreach_ud : %p %p\n", map, func);
	size_t i;
	for (i=0;i<map->cap;i++) {
		if (map->slot[i].pointer) {
			func(map->slot[i].pointer,ud);
		}
	}
}

//返回第一个非空_pbcM_sp_slot指针
static int
_find_first(struct map_sp *map)
{
	//printf("_find_first : %p \n", map);
	size_t i;
	for (i=0;i<map->cap;i++) {
		if (map->slot[i].pointer) {
			return i;
		}
	}
	return -1;
}

//遍历MAP
static int
_find_next(struct map_sp *map, const char *key)
{
	//printf("_find_next : %p %s\n", map, key);
	size_t hash_full = calc_hash(key);
	size_t hash = hash_full & (map->cap -1);

	struct _pbcM_sp_slot * slot = &map->slot[hash];
	for (;;) {
		if (slot->hash == hash_full && strcmp(slot->key, key) == 0) {
			int i = slot - map->slot + 1;
			while(i<map->cap) {
				if (map->slot[i].pointer) {
					return i;
				}
				++i;
			}
			return -1;
		}
		if (slot->next == 0) {
			return -1;
		}
		slot = &map->slot[slot->next-1];
	}
}


//const char * key = NULL;
//for (;;) {
//	void * v = _pbcM_sp_next(map3, &key);
//	if (key == NULL)
//		break;
//	printf("%s : %s\n", key, (const char *)v);
//}
//遍历map,函数返回v值
void *
_pbcM_sp_next(struct map_sp *map, const char ** key)
{
	//printf("_pbcM_sp_next %p : %s\n", map, key);
	if (map == NULL) {
		*key = NULL;
		return NULL;
	}
	int idx;
	if (*key == NULL) {
		idx = _find_first(map);
	} else {
		idx = _find_next(map, *key);
	}
	if (idx < 0) {
		*key = NULL;
		return NULL;
	}
	*key = map->slot[idx].key;
	return map->slot[idx].pointer;
}



