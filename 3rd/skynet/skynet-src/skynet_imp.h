#ifndef SKYNET_IMP_H
#define SKYNET_IMP_H

// Skynet配置的结构
struct skynet_config {
	int thread;//  //启动工作线程数量，不要配置超过实际拥有的CPU核心数

	//skynet网络节点的唯一编号，可以是 1 - 255 间的任意整数。一个 skynet 网络最多支持 255 个节点。
	//每个节点有必须有一个唯一的编号。
	//如果 harbor 为 0 ，skynet 工作在单节点模式下。此时 master 和 address 以及 standalone 都不必设置。
	int harbor;// 节点编号

	const char * daemon;//后台模式：daemon = "./skynet.pid"可以以后台模式启动skynet（注意，同时请配置logger 项输出log） 

	const char * module_path;//用 C 编写的服务模块的位置，通常指 cservice 下那些 .so 文件 const char * bootstrap; 

	//skynet 启动的第一个服务以及其启动参数。默认配置为 snlua bootstrap ，即启动一个名为 bootstrap 的 lua 服务。
	//通常指的是 service / bootstrap.lua 这段代码。
	const char * bootstrap;

	//它决定了 skynet 内建的 skynet_error 这个 C API 将信息输出到什么文件中。
	//如果 logger 配置为 nil ，将输出到标准输出。你可以配置一个文件名来将信息记录在特定文件中。
	const char * logger;// 日志文件

	//默认为 "logger" ，你可以配置为你定制的 log 服务（比如加上时间戳等更多信息）。
	//可以参考 service_logger.c 来实现它。
	//注：如果你希望用 lua 来编写这个服务，可以在这里填写 snlua ，然后在 logger 配置具体的 lua 服务的名字。
	//在 examples 目录下，有 config.userlog 这个范例可供参考。
	const char * logservice;
};

/******************************
工作模式

如果只看工作线程，假设是一个四核八线程的机器，thread也配置的是8，那么就会有8个线程同时工作，
但是在skynet中，这也意味着最多只有8个协程在工作。只有这个协程让出了执行权，另外一个协程才能执行。
*******************************/

/****************
worker线程

把它放在前面是因为"一切皆服务"的思想在我理解就在这里体现的。  
工作线程维护一个全局的消息队列，全局的消息队列中又是各个服务的消息队列。  
工作线程的工作其实很简单 : 
从全局消息队列中弹出服务的消息队列，然后根据此线程权重来决定处理此服务的消息队列中的多少个消息，
然后再把这个服务的消息队列重新加入到全局消息队列的队列尾，
等待下一次它被取出 * 每次将服务的消息队列从全局消息队列中弹出代表已经开始处理了，
所以要先调用 skynet_monitor_trigger 将其此次消息处理加入到 moniter 线程的监控之下，
然后再进行消息处理，处理完毕后调用skynet_monitor_trigger将此次消息处理的监控移除。
*/
#define THREAD_WORKER 0

/***********************************
启动线程

这里的"启动线程"不知道这样称呼对不对(不是软件专业毕业的硬伤~)，
反正我就是这样称呼了，它主要是指创建各个线程之前的流程。
它做的工作为: 
1. 整个skynet进程的入口 
2. 初始化环境变量 
3. 进程信号的处理 
4. 加载配置文件代码块并针对配置文件做一系列初始化工作 
5. 各个模块的初始化 
6. 创建第一个 logger 服务(为什么第一个创建呢，因为靠它来输出log) 
7. 加载snlua模块(所有的lua服务都是通过它来创建)，
	通过给snlua服务发送第一个消息等工作线程创建完后来从消息队列中取出这个消息来创建bootstrap服务，
	然后bootstrap服务会进行又一轮的初始化工作 
8. 创建各个线程

*/
#define THREAD_MAIN 1
/*
socket线程

socket线程的工作简单来说: 
监控进程内的请求:执行上层过来的发送socket数据的请求，通过select实现  监控client发送到server的数据:
将client过来的socket数据交给对应的服务(一般为gate服务)，通过epoll实现(可选其他的方式)

稍微复杂点: 
1. 在启动线程中创建了1个管道，此管道主要用来接收上层的命令(监听、连接、发送数据等)，
它交给select监控是否可读/可写。如果上层需要对socket描述符进行写操作，
唯一的方式是通过相应的接口向socket描述符对应的id(socket线程为每个socket描述符分配了一个id，
上层只能通过这个id进行操作，而不能直接得到socket描述符文件)写一些数据，
然后向此id写一个相应的命令(比如'S' 'L' 'D') 
2. 在启动线程初始化 socket 模块时创建了一个struct socket_server统领socket处理的全局，
下面主要管理了:管道描述符、epoll描述符、epoll事件、每个socket描述符对应的一个struct socket 
3. 在2中说到的"每个socket描述符对应的一个struct socket"是socket线程处理的核心，
它通过protocol字段告诉框架此socket采用的协议，通过type字段说明当前socket进行到哪一步了(是准备监听还是正在监听，
是accept完成了还是正在进行，是否已经准备好接收数据了) 。
它同时也作为epoll的自定义数据，这样当epoll发现有事件发生时skynet框架便能通过type字段知道进行到哪一步了，才能做出相应的处理。

*/
#define THREAD_SOCKET 2

/*
timer线程

就是一个定时器线程，skynet 框架的定时任务(skynet.timeout)就是就是通过它来做的。
它是模拟linux下的时间片轮转的方式。每过1/100秒就转一个刻度(想象一下水表)。
定时器线程主要分为5个层级，从低层级到高层级的粒度分别为:256、64、64、64、64，
当我们需要向skynet框架注册一个定时器时，就算出与当前时间对应的偏移值，将其链接到对应的层级的节点。
就像齿轮一样，只要有动力它就会一直转，转到某个层级的节点如果发现其下链接有事件，
就会将对应的事件链表依次取出，找到是哪个服务注册的定时器，将向那个服务压入一条定时器消息，
等待worker线程的处理，一直到这个链表为空，齿轮才会转到下一个时间节点。如果低层级的齿轮转完了，
就将高层级的一个节点继续分配到最低层级的齿轮上去。 
链接参考: 浅析 Linux 中的时间编程和实现原理，第 3 部分: Linux 内核的工作，前面部分一起看可能会好点。

*/
#define THREAD_TIMER 3

/*
moniter线程

moniter线程，顾名思义，监控线程，主要是用来监控工作线程是否有异常:
是否已经陷入死循环(这样说也不太对，主要是看是不是一个消息处理的时间过长:5秒钟)，如果发现陷入死循环，仅仅打印一句log。
其实就是一个辅助作用的线程，但是如果配合 debug_console 能很快的定位出陷入死循环的地方在哪，或者说哪个消息处理时花的时间过长。
*/
#define THREAD_MONITOR 4

void skynet_start(struct skynet_config * config); // 启动 Skynet

#endif
