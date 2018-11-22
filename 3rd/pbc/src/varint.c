#include "varint.h"

#include "pbc.h"

#include <stdint.h>
/*
先使用zigzag压缩数据长度，然后使用varint表示法存储数据

1.	每个字节，我们只使用低7位，最高的一位作为一个标志位：
	•	1：下一个byte也是该数字的一部分
	•	0：下一个byte不是该数字的一部分
2.小端编码，低位在前，高位在后

*/

inline int
_pbcV_encode32(uint32_t number, uint8_t buffer[10])
{
	//如果小于7位二进制数，直接取7位存入buffer[0]，并返回长度
	if (number < 0x80) {
		buffer[0] = (uint8_t) number ; 
		return 1;
	}
	//取后7位存入buffer[0]
	buffer[0] = (uint8_t) (number | 0x80 );//由于还有后续数据，所以高位设置为1（| 0x80 即10000000）
	//如果小于14个二进制位
	if (number < 0x4000) {
		//将高7位存入buffer[1]，后续无字节
		buffer[1] = (uint8_t) (number >> 7 );
		return 2;
	}
	//大于14个二进制位，将高8~14位存入buffer[1]，由于还有后续数据，所以高位设置为1（| 0x80即10000000 ）
	buffer[1] = (uint8_t) ((number >> 7) | 0x80 );
	//如果小于21个二进制位
	if (number < 0x200000) {
		//将最高7位存入buffer[1]，后续无字节
		buffer[2] = (uint8_t) (number >> 14);
		return 3;
	}
	//大于21个二进制位，将15~21位存入buffer[2]，由于还有后续数据，所以高位设置为1（| 0x80即10000000 ）	
	buffer[2] = (uint8_t) ((number >> 14) | 0x80 );
	//如果小于28个二进制位
	if (number < 0x10000000) {
		//将最高7位存入buffer[1]，后续无字节
		buffer[3] = (uint8_t) (number >> 21);
		return 4;
	}
	//大于28个二进制位都用5个字节表示
	buffer[3] = (uint8_t) ((number >> 21) | 0x80 );
	buffer[4] = (uint8_t) (number >> 28);
	return 5;
}

//由于大数据比较少，故此用了一个do-while循环替代了_pbcV_encode32的写法，作用与_pbcV_encode32一样
int
_pbcV_encode(uint64_t number, uint8_t buffer[10]) 
{
	//如果小于32位
	if ((number & 0xffffffff) == number) {
		return _pbcV_encode32((uint32_t)number , buffer);
	}
	int i = 0;
	do {
		buffer[i] = (uint8_t)(number | 0x80);
		number >>= 7;
		++i;
	} while (number >= 0x80);
	buffer[i] = (uint8_t)number;
	return i+1;
}
//将buffer的数据放入result，并返回数据在buffer的长度
int
_pbcV_decode(uint8_t buffer[10], struct longlong *result) {
	//小于8位，buffer[0]后无数据
	if (!(buffer[0] & 0x80)) {
		result->low = buffer[0];
		result->hi = 0;
		return 1;
	}
	uint32_t r = buffer[0] & 0x7f;
	int i;
	for (i=1;i<4;i++) {
		//buffer[i]&0x7f将buffer[i]7位以上的位清零然后合并到r左前端
		r |= ((buffer[i]&0x7f) << (7*i));
		//如果后续没有信息了标志位为0
		if (!(buffer[i] & 0x80)) {
			result->low = r;
			result->hi = 0;
			return i+1;
		}
	}
	uint64_t lr = 0;
	for (i=4;i<10;i++) {
		lr |= ((uint64_t)(buffer[i] & 0x7f) << (7*(i-4)));
		if (!(buffer[i] & 0x80)) {
			result->hi = (uint32_t)(lr >> 4);//因为有4位是32位low的所以右移4位
			result->low = r | (((uint32_t)lr & 0xf) << 28);//取低4位放在Low的最前4位
			return i+1;
		}
	}

	result->low = 0;
	result->hi = 0;
	return 10;
}

//我们就把(n >> 31)这个符号位放到补码的最后，其他位整体前移一位(n << 1) 
//合并数据^
int 
_pbcV_zigzag32(int32_t n, uint8_t buffer[10])
{
	n = (n << 1) ^ (n >> 31);
	return _pbcV_encode32(n,buffer);
}

int 
_pbcV_zigzag(int64_t n, uint8_t buffer[10])
{
	n = (n << 1) ^ (n >> 63);
	return _pbcV_encode(n,buffer);
}

//还原 -1的补码(11111111)
//       0的补码-0的补码是（00000000）
// zigzag值还原为整型值：
// int zigzag_to_int(int n) 
// {
// 		return (((unsignedint)n) >>1) ^ -(n & 1);
// }

void
_pbcV_dezigzag64(struct longlong *r)
{
	uint32_t low = r->low;
	r->low = ((low >> 1) | ((r->hi & 1) << 31)) ^ - (low & 1);
	r->hi = (r->hi >> 1) ^ - (low & 1);
}

//zigzag值还原为整型值
void
_pbcV_dezigzag32(struct longlong *r)
{
	uint32_t low = r->low;
	r->low = (low >> 1) ^ - (low & 1);
	r->hi = -(low >> 31);//？
}
