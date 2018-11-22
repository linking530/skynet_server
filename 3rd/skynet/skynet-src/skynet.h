#ifndef SKYNET_H
#define SKYNET_H

#include "skynet_malloc.h"

#include <stddef.h>
#include <stdint.h>

//其实，type 表示的是当前消息包的协议组别，而不是传统意义上的消息类别编号。
//协议组别类型并不会很多，所以，我限制了 type 的范围是 0 到 255 ，由一个字节标识。
//在实现时，我把 type 编码到了 size 参数的高 8 位。
//因为单个消息包限制长度在 16 M （24 bit)内，是个合理的限制。
//这样，为每个消息增加了 type 字段，并没有额外增加内存上的开销。
//0是内部服务最为常用的文本消息类型。

#define PTYPE_TEXT 0
//1 表示这是一个回应包，应该依据对方的规范来解码。
#define PTYPE_RESPONSE 1
#define PTYPE_MULTICAST 2
#define PTYPE_CLIENT 3
#define PTYPE_SYSTEM 4
#define PTYPE_HARBOR 5
#define PTYPE_SOCKET 6
// read lualib/skynet.lua examples/simplemonitor.lua
#define PTYPE_ERROR 7	
// read lualib/skynet.lua lualib/mqueue.lua lualib/snax.lua
#define PTYPE_RESERVED_QUEUE 8
#define PTYPE_RESERVED_DEBUG 9
#define PTYPE_RESERVED_LUA 10
#define PTYPE_RESERVED_SNAX 11
//我们可以在 type 里打上 dontcopy 的 tag(PTYPE_TAG_DONTCOPY) ，让框架不要复制 msg / sz 指代的数据包。
//否则 skynet 会用 malloc 分配一块内存，把数据复制进去。
//callback 函数在处理完这块数据后，会调用 free 释放内存。
//你可以通过让 callback 返回 1 ，阻止框架释放内存。这通常和在 send 时标记 dontcopy 标记配对使用。
#define PTYPE_TAG_DONTCOPY 0x10000
//在 type 里设上 alloc session 的 tag (PTYPE_TAG_ALLOCSESSION)。
//send api 就会忽略掉传入的 session 参数，而会分配出一个当前服务从来没有使用过的 session 号，发送出去。
//同时约定，接收方在处理完这个消息后，把这个 session 原样发送回来。
//这样，编写服务的人只需要在 callback 函数里记录下所有待返回的 session 表，就可以在收到每个消息后，正确的调用对应的处理函数。
#define PTYPE_TAG_ALLOCSESSION 0x20000

/*
C Name	Value	Description
EPERM	1	Operation not permitted
ENOENT	2	No such file or directory
ESRCH	3	No such process
EINTR	4	Interrupted system call
EIO	5	I/O error
ENXIO	6	No such device or address
E2BIG	7	Arg list too long
ENOEXEC	8	Exec format error
EBADF	9	Bad file number
ECHILD	10	No child processes
EAGAIN	11	Try again
ENOMEM	12	Out of memory
EACCES	13	Permission denied
EFAULT	14	Bad address
ENOTBLK	15	Block device required
EBUSY	16	Device or resource busy
EEXIST	17	File exists
EXDEV	18	Cross-device link
ENODEV	19	No such device
ENOTDIR	20	Not a directory
EISDIR	21	Is a directory
EINVAL	22	Invalid argument
ENFILE	23	File table overflow
EMFILE	24	Too many open files
ENOTTY	25	Not a tty device
ETXTBSY	26	Text file busy
EFBIG	27	File too large
ENOSPC	28	No space left on device
ESPIPE	29	Illegal seek
EROFS	30	Read-only file system
EMLINK	31	Too many links
EPIPE	32	Broken pipe
EDOM	33	Math argument out of domain
ERANGE	34	Math result not representable
EDEADLK	35	Resource deadlock would occur
ENAMETOOLONG	36	Filename too long
ENOLCK	37	No record locks available
ENOSYS	38	Function not implemented
ENOTEMPTY	39	Directory not empty
ELOOP	40	Too many symbolic links encountered
EWOULDBLOCK	41	Same as EAGAIN
ENOMSG	42	No message of desired type
EIDRM	43	Identifier removed
ECHRNG	44	Channel number out of range
EL2NSYNC	45	Level 2 not synchronized
EL3HLT	46	Level 3 halted
EL3RST	47	Level 3 reset
ELNRNG	48	Link number out of range
EUNATCH	49	Protocol driver not attached
ENOCSI	50	No CSI structure available
EL2HLT	51	Level 2 halted
EBADE	52	Invalid exchange
EBADR	53	Invalid request descriptor
EXFULL	54	Exchange full
ENOANO	55	No anode
EBADRQC	56	Invalid request code
EBADSLT	57	Invalid slot
EDEADLOCK	 -	Same as EDEADLK
EBFONT	59	Bad font file format
ENOSTR	60	Device not a stream
ENODATA	61	No data available
ETIME	62	Timer expired
ENOSR	63	Out of streams resources
ENONET	64	Machine is not on the network
ENOPKG	65	Package not installed
EREMOTE	66	Object is remote
ENOLINK	67	Link has been severed
EADV	68	Advertise error
ESRMNT	69	Srmount error
ECOMM	70	Communication error on send
EPROTO	71	Protocol error
EMULTIHOP	72	Multihop attempted
EDOTDOT	73	RFS specific error
EBADMSG	74	Not a data message
EOVERFLOW	75	Value too large for defined data type
ENOTUNIQ	76	Name not unique on network
EBADFD	77	File descriptor in bad state
EREMCHG	78	Remote address changed
ELIBACC	79	Cannot access a needed shared library
ELIBBAD	80	Accessing a corrupted shared library
ELIBSCN	81	A .lib section in an .out is corrupted
ELIBMAX	82	Linking in too many shared libraries
ELIBEXEC	83	Cannot exec a shared library directly
EILSEQ	84	Illegal byte sequence
ERESTART	85	Interrupted system call should be restarted
ESTRPIPE	86	Streams pipe error
EUSERS	87	Too many users
ENOTSOCK	88	Socket operation on non-socket
EDESTADDRREQ	89	Destination address required
EMSGSIZE	90	Message too long
EPROTOTYPE	91	Protocol wrong type for socket
ENOPROTOOPT	92	Protocol not available
EPROTONOSUPPORT	93	Protocol not supported
ESOCKTNOSUPPORT	94	Socket type not supported
EOPNOTSUPP	95	Operation not supported on transport
EPFNOSUPPORT	96	Protocol family not supported
EAFNOSUPPORT	97	Address family not supported by protocol
EADDRINUSE	98	Address already in use
EADDRNOTAVAIL	99	Cannot assign requested address
ENETDOWN	100	Network is down
ENETUNREACH	101	Network is unreachable
ENETRESET 	102	Network dropped
ECONNABORTED	103	Software caused connection
ECONNRESET	104	Connection reset by
ENOBUFS	105	No buffer space available
EISCONN	106	Transport endpoint
ENOTCONN	107	Transport endpoint
ESHUTDOWN 	108	Cannot send after transport
ETOOMANYREFS	109	Too many references
ETIMEDOUT 	110	Connection timed
ECONNREFUSED	111	Connection refused
EHOSTDOWN 	112	Host is down
EHOSTUNREACH	113	No route to host
EALREADY	114	Operation already
EINPROGRESS	115	Operation now in
ESTALE	116	Stale NFS file handle
EUCLEAN	117	Structure needs cleaning
ENOTNAM	118	Not a XENIX-named
ENAVAIL	119	No XENIX semaphores
EISNAM	120	Is a named type file
EREMOTEIO 	121	Remote I/O error
EDQUOT	122	Quota exceeded
ENOMEDIUM 	123	No medium found
EMEDIUMTYPE	124	Wrong medium type

*/

struct skynet_context;

void skynet_error(struct skynet_context * context, const char *msg, ...);
const char * skynet_command(struct skynet_context * context, const char * cmd , const char * parm);
uint32_t skynet_queryname(struct skynet_context * context, const char * name);
int skynet_send(struct skynet_context * context, uint32_t source, uint32_t destination , int type, int session, void * msg, size_t sz);
int skynet_sendname(struct skynet_context * context, uint32_t source, const char * destination , int type, int session, void * msg, size_t sz);

int skynet_isremote(struct skynet_context *, uint32_t handle, int * harbor);

typedef int (*skynet_cb)(struct skynet_context * context, void *ud, int type, int session, uint32_t source , const void * msg, size_t sz);
void skynet_callback(struct skynet_context * context, void *ud, skynet_cb cb);

uint32_t skynet_current_handle(void);
uint64_t skynet_now(void);
void skynet_debug_memory(const char *info);	// for debug use, output current service memory to stderr

#endif
