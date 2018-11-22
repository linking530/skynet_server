## PBC

PBC is a google protocol buffers library for C without code generation.

## Quick Example

    package tutorial;
    
    message Person {
      required string name = 1;
      required int32 id = 2;        // Unique ID number for this person.
      optional string email = 3;
    
      enum PhoneType {
        MOBILE = 0;
        HOME = 1;
        WORK = 2;
      }
    
      message PhoneNumber {
        required string number = 1;
        optional PhoneType type = 2 [default = HOME];
      }
    
      repeated PhoneNumber phone = 4;
    }

```C
struct pbc_rmessage * m = pbc_rmessage_new(env, "tutorial.Person", slice);
printf("name = %s\n", pbc_rmessage_string(m , "name" , 0 , NULL));
printf("id = %d\n", pbc_rmessage_integer(m , "id" , 0 , NULL));
printf("email = %s\n", pbc_rmessage_string(m , "email" , 0 , NULL));

int phone_n = pbc_rmessage_size(m, "phone");
int i;

for (i=0;i<phone_n;i++) {
	struct pbc_rmessage * p = pbc_rmessage_message(m , "phone", i);
	printf("\tnumber[%d] = %s\n",i,pbc_rmessage_string(p , "number", i ,NULL));
	printf("\ttype[%d] = %s\n",i,pbc_rmessage_string(p, "type", i, NULL));
}

pbc_rmessage_delete(m);
```

## Message API

You can use *wmessage* for encoding , and *rmessage* for decoding.

See test/addressbook.c for details.

## Pattern API

If you need better performance , you can use pbc_pattern_xxx api .

See test/pattern.c for details.

Pattern api is faster and less memory used because it can access data in native C struct.

## Extension

PBC support extension in a very simple way . PBC add a specific prefix to every extension field name. 

## Service

Not supported

## Enum

With message API , you can use both string and integer as enum type . They must be integer in Pattern API. 

## Lua bindings

cd bindings/lua && make

See https://github.com/cloudwu/pbc/tree/master/binding/lua/README.md

## Question ?

* Send me email : http://www.codingnow.com/2000/gmail.gif
* My Blog : http://blog.codingnow.com
* Design : http://blog.codingnow.com/2011/12/protocol_buffers_for_c.html (in Chinese)
* Build for Visual Studio 2012 : https://github.com/miaodadao/pbc


Protocol Buffers for C

我一直不太满意 google protocol buffers 的默认设计。为每个 message type 生成一大坨 C++ 代码让我很难受。而且官方没有提供 C 版本，第三方的 C 版本 也不让我满意。

这种设计很难让人做动态语言的 binding ，而大多数动态语言往往又没有强类型检查，采用生成代码的方式并没有特别的好处，反而有很大的性能损失（和通常做一个 bingding 库的方式比较）。比如官方的 Python 库，完全可以在运行时，根据协议，把那些函数生成出来，而不必用离线的工具生成代码。

去年的时候我曾经写过一个 lua 版本的库 。为了独立于官方版本，我甚至还用 lpeg 写了一个 .proto 文件的解析器。用了大约不到 100 行 lua 代码就可以解析出 .proto 文件内的协议内容。可以让 lua 库直接加载文本的协议描述文件。（这个东西这次帮了我大忙）

这次，我重新做项目，又碰到 protobuf 协议解析问题，想从头好好解决一下。上个月一开始，我想用 luajit 好好编写一个纯 lua 版。猜想，利用 luajit 和 ffi 可以达到不错的性能。但是做完以后，发现和 C++ 版本依然有差距 (大约只能达到 C++ 版本的 25% ~ 33% 左右的速度) ，比我去年写的 C + Lua binding 的方式要差。但是，去年写的那一份 C 代码和 Lua 代码结合太多。所以我萌生了重新写一份 C 实现的想法。

做到一半的时候，有网友指出，有个 googler 最近也在做类似的工作。μpb 这个项目在这里 。这里他写了一大篇东西阐述为什么做这样一份东西，大体上和我的初衷一致。不过他的 api 设计的不太好，我觉得太难用。所以这个项目并不妨碍我完成我自己的这一份。

C 版本之所以很难把 api 设计好，是因为 C 缺乏必要的数据结构。而且没有垃圾回收，缺乏数据类型的元信息。

考虑再三，我决定提供两套 api ，满足不同的需求。

当性能要求不太高的时候，仅仅满足 C 语言开发的便捷需要，提供一套简单易用的 api 操作 protobuf 格式的 message 。我称之为 message api 。

大体上有两组 api :

对于编码 protobuf 的消息，使用 rmessage 相关 api

struct pbc_rmessage * pbc_rmessage_new(struct pbc_env * env, const char * typename , struct pbc_slice * slice);
void pbc_rmessage_delete(struct pbc_rmessage *);

uint32_t pbc_rmessage_integer(struct pbc_rmessage * , const char *key , int index, uint32_t *hi);
double pbc_rmessage_real(struct pbc_rmessage * , const char *key , int index);
const char * pbc_rmessage_string(struct pbc_rmessage * , const char *key , int index, int *sz);
struct pbc_rmessage * pbc_rmessage_message(struct pbc_rmessage *, const char *key, int index);
int pbc_rmessage_size(struct pbc_rmessage *, const char *key);
对于解码消息，使用 wmessage 相关 api

struct pbc_wmessage * pbc_wmessage_new(struct pbc_env * env, const char *typename);
void pbc_wmessage_delete(struct pbc_wmessage *);

void pbc_wmessage_integer(struct pbc_wmessage *, const char *key, uint32_t low, uint32_t hi);
void pbc_wmessage_real(struct pbc_wmessage *, const char *key, double v);
void pbc_wmessage_string(struct pbc_wmessage *, const char *key, const char * v, int len);
struct pbc_wmessage * pbc_wmessage_message(struct pbc_wmessage *, const char *key);
void * pbc_wmessage_buffer(struct pbc_wmessage *, struct pbc_slice * slice);
pbc_rmessage_new 和 pbc_rmessage_delete 用来构造和释放 pbc_rmessage 结构。
从结构中取出的子消息，字符串，都是由它来保证生命期的。这样不需要用户做过于繁杂的对象构建和销毁工作。

对于 repeated 的数据，没有额外再引入新的数据类型。
而是把 message 内部的所有域都视为 repeated 。这种设计，可以极大的精简需要的 api 。

我们用 pbc_rmessage_size 可以查询 message 中某个 field 被重复了多少次。
如果消息中并没有编码入这个 field ，它能返回 0 感知到。

我把所有的基本数据类型全部统一成了三种：integer , string , real 。bool 类型被当成 integer 处理。
enum 类型即可以是 string ，也可以是 integer 。
用 pbc_rmessage_string 时，可以取到 enum 的名字；
用 pbc_rmessage_integer 则取得 id 。

pbc_rmessage_message 可以获得一个子消息，这个返回的对象不必显式的销毁，它的生命期挂接在父节点上。
即使消息中没有编码入某个子消息，这个 api 依然可以正确的返回。从中取出的子域都将是默认值。

integer 不区分 32bit 数和 64bit 数。
当你能肯定你需要的整数可以用 32bit 描述时，pbc_rmessage_integer 的最后一个参数可以传 NULL ，忽略高 32bit 的数据。

wmessage 的用法更像是不断的向一个未关闭的消息包类压数据。
当你把整个消息的内容都填完后，可以用 pbc_wmessage_buffer 返回一个 slice 。
这个 slice 里包含了 buffer 的指针和长度。

需要注意的是，如果使用 pbc_wmessage_integer 压入一个负数，一定要将高位传 -1 。
因为接口一律把传入参数当成是无符号的整数。

考虑到某些内部实现的性能，以及后面讲提到的 pattern api 的方便性（如果你完全拿这个库做 C/S 通讯）。
建议所有的 string 都在末尾加上 \0 。
因为，这样在解码的时候，可以将字符串指针直接指向数据包内，而不需要额外复制一份出来。

pbc_wmessage_string 可以压入非 \0 结尾的字符串，因为压入的数据长度是由参数制定的。
当然你也可以不自己计算长度。如果长度参数传 <=0 的话，库会帮你调用 strlen 检测。
并且将最终的长度减去这个负数。即，如果你传 -1 ，就会帮你多压入最后的一个 \0 字节。

Pattern API 可以得到更高的性能。更快的速度和更少的内存占用量。
更重要的是，对于比较小的消息包，如果你使用得当，使用 pattern api 甚至不会触发哪怕一次堆上的内存分配操作。
api 工作时的所有的临时内存都在栈上。

相关 api 如下：

struct pbc_pattern * pbc_pattern_new(struct pbc_env * , const char * message, const char *format, ...);
void pbc_pattern_delete(struct pbc_pattern *);
int pbc_pattern_pack(struct pbc_pattern *, void *input, struct pbc_slice * s);
int pbc_pattern_unpack(struct pbc_pattern *, struct pbc_slice * s , void * output);
我们首先需要创建一个 pattern 做编码和解码用。一个简单的例子是这样的：

message Person {
  required string name = 1;
  required int32 id = 2; 
  optional string email = 3;
}
这样一个消息，对于在 C 的结构体中，你可能希望是这样： struct Person { pbcslice name; int32t id; pbc_slice email; } 
这里使用 pbc_slice 来表示一个 string 。因为对于 message 来说，里面的字符串是有长度的。并且不一定以 \0 结尾。
slice 同样可以表示一个尚未解开的子消息。

我们使用 pbc_pattern_new 可以让 pbc 认识这个结构的内存布局。

struct pbc_pattern * Person_p = pbc_pattern_new(env , "Person" ,
  "name %s id %d email %s",
  offsetof(struct Person , name),
  offsetof(struct Person , id),
  offsetof(struct Person , email));
然后就可以用 pbc_pattern_pack 和 pbc_pattern_unpack 编码和解码了。
pattern 的定义过程冗长而且容易出错（你也可以考虑用机器生成它们）。
但我相信在性能及其敏感的场合，这些是值得的，如果你觉得写这些不值得，可以考虑用回上面的 message api 。

对于 repeated 的数据，pattern api 把他们看成一个数组 pbc_array 。

有这样一组 api 可以用来操作它：

int pbc_array_size(pbc_array);
uint32_t pbc_array_integer(pbc_array array, int index, uint32_t *hi);
double pbc_array_real(pbc_array array, int index);
struct pbc_slice * pbc_array_slice(pbc_array array, int index);

void pbc_array_push_integer(pbc_array array, uint32_t low, uint32_t hi);
void pbc_array_push_slice(pbc_array array, struct pbc_slice *);
void pbc_array_push_real(pbc_array array, double v);
数组是个略微复杂一些的数据结构，但如果你的数据不多的话，它也不会牵扯到堆上的额外内存分配。
不过既然有可能调用这些 api 可能额外分配内存，那么你必须手工清除这些内存。
而且在第一次使用前，必须初始化这个数据结构 (memset 为 0 是可以的)。

void pbc_pattern_set_default(struct pbc_pattern * , void *data);
void pbc_pattern_close_arrays(struct pbc_pattern *, void *data);
pbc_pattern_set_default 可以把一块内存，以一个 pattern 的形式，初始化所有的域。包括其中的数组的初始化。

pbc_pattern_close_arrays 使用完一块数据，需要手工调用这个 api ，关闭这个数据块中的数组。

关于 Extension ，我最后放弃了直接支持。没有提供类似 get extension 的 api 。
这是因为，我们可以更简单的去处理 extension 。
我把所有的 extension field 都加了前缀，如果需要，可以用拼接字符串的方式获得消息包内的扩展域。

最后介绍的是 pbc 的环境。

struct pbc_env * pbc_new(void);
void pbc_delete(struct pbc_env *);
int pbc_register(struct pbc_env *, struct pbc_slice * slice);
pbc 库被设计成没有任何全局变量，这样你想在多线程环境用会比较安全。虽然库并没有考虑线程安全问题，但在不同的线程中使用不同的环境是完全没有问题的。

每个环境需要独立注册需要的消息类型，传入一个 protobuf 库官方工具生成的 .pb 数据块即可。以 slice 的形式传入，register 完后，这块数据内存可以释放。

这个数据块其实是以 google.protobuf.FileDescriptorSet 类型来编码的。这个数据类型非常繁杂，使得 bootstrap 过程及其难写，这个在后面会谈到。

全部代码我已经开源方在 github 上了，可以在 https://github.com/cloudwu/pbc 取到代码。详细的用法也可以从那些 test 文件中找到例子。

这个东西很难写，所以代码很乱，在写这篇 blog 的时候我还没有开始整理代码的结构。大家想用的将就用，请善待 bug 和它的朋友们。

用一个复杂的 protobuf 协议来描述协议本身，真的很淡疼。当我们没有任何一个可用的协议解析库前，我们无法理解任何 protobuf 协议。这是一个先有鸡还是先有蛋的问题。就是说，我很难凭空写出一个 pbc_register 的 api ，因为它需要先 register 一个 google.protobuf.FileDescriptorSet 类型才能开始分析输入的包。

不依赖库本身去解析 google.protobuf.FileDescriptorSet 本身的定义是非常麻烦的。当然我可以利用 google 官方的工具生成 google.protobuf.FileDescriptorSet 的 C++ 解析类开始工作。但我偏偏又不希望给这个东西带来过多的依赖。

一开始我希望自定义一种更简单的格式来描述协议本身，没有过多的层次结构，只是一个平坦的数组。这样手工解析就有可能。本来我想给 protoc 写一个 plugin ，生成自定义的协议格式。后来放弃了这个方案，因为希望库用起来更简单一些。

但是这个方案还是部分使用了。这就是源代码中 bootstrap.c 部分的缘由。它读入一个更简单版本的 google.protobuf.FileDescriptorSet 的描述。这块数据是事先生成好的，放在 descriptor.pbc.h 里。生成这块数据使用了我去年完成的 lua 库。相关的 lua 代码就没有放出来了。当然到了今天，pbc 本身足够完善，我们可以用 pbc 写一个 C 版本。有兴趣的同学，可以在 test_pbc.c 的基础上修改。

这个玩意很难写, 主要是那个鸡生蛋,蛋生鸡的问题,导致我在实现过程的很长时间里,脑子里都糨糊一般. 所以很多代码实现的很糟糕, 但又不舍得删(因为难为我把它们写出来了, 重写很难调错). 希望一边写一边优化的坏习惯, 在对于这种比较难实现的东西上, 让我编写的好生痛苦. 为了效率, 我甚至写了三个针对不同情况处理的 map .

中间因为想法改变, api 设计改变,废弃了好几千行代码. 最终也就是这个样子了. 有空再重新理一下.

最终, 还有许多细节可以进一步优化, 比如如果只针对小头的机器做, 许多不必要的代码都可以省略掉. 对于 packed 数组也值得进一步优化. 甚至可以考虑加一点 JIT .

事情总算告一段落了。连续写了 5000 行代码，我需要休息一下。

