#ifndef PROTOBUF_C_BOOTSTRAP_H
#define PROTOBUF_C_BOOTSTRAP_H

#include "proto.h"
#include "pbc.h"

// 用一个复杂的 protobuf 协议来描述协议本身，真的很淡疼。
// 当我们没有任何一个可用的协议解析库前，我们无法理解任何 protobuf 协议。
// 这是一个先有鸡还是先有蛋的问题。
// 就是说，我很难凭空写出一个 pbc_register 的 api ，因为它需要先 register 一个 google.protobuf.FileDescriptorSet 类型才能开始分析输入的包。

// 不依赖库本身去解析 google.protobuf.FileDescriptorSet 本身的定义是非常麻烦的。
// 当然我可以利用 google 官方的工具生成 google.protobuf.FileDescriptorSet 的
 // C++ 解析类开始工作。但我偏偏又不希望给这个东西带来过多的依赖。

// 一开始我希望自定义一种更简单的格式来描述协议本身，没有过多的层次结构，
// 只是一个平坦的数组。这样手工解析就有可能。本来我想给 protoc 写一个 plugin ，
// 生成自定义的协议格式。后来放弃了这个方案，因为希望库用起来更简单一些。

// 但是这个方案还是部分使用了。这就是源代码中 bootstrap.c 部分的缘由。


void _pbcB_init(struct pbc_env *);
void _pbcB_register_fields(struct pbc_env *, pbc_array queue);

#endif
