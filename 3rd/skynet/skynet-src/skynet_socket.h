#ifndef skynet_socket_h
#define skynet_socket_h

struct skynet_context;
// 可以看做是对 socket_server 里返回值类型的封装
#define SKYNET_SOCKET_TYPE_DATA 1
#define SKYNET_SOCKET_TYPE_CONNECT 2
#define SKYNET_SOCKET_TYPE_CLOSE 3
#define SKYNET_SOCKET_TYPE_ACCEPT 4
#define SKYNET_SOCKET_TYPE_ERROR 5
#define SKYNET_SOCKET_TYPE_UDP 6
#define SKYNET_SOCKET_TYPE_WARNING 7
// 对应 skynet_socket_server 服务中消息传输  
struct skynet_socket_message {
	int type; // 类型
	int id; // 编号
	int ud;
	char * buffer; // 缓冲区
};

void skynet_socket_init(); // 初始化 Socket
void skynet_socket_exit(); // 退出 Socket
void skynet_socket_free(); // 释放 Socket
int skynet_socket_poll();  // 查看 Socket 消息

int skynet_socket_send(struct skynet_context *ctx, int id, void *buffer, int sz); // 发送数据
void skynet_socket_send_lowpriority(struct skynet_context *ctx, int id, void *buffer, int sz); // 低优先级发送数据
int skynet_socket_listen(struct skynet_context *ctx, const char *host, int port, int backlog); // 监听 Socket
int skynet_socket_connect(struct skynet_context *ctx, const char *host, int port); // Socket 连接
int skynet_socket_bind(struct skynet_context *ctx, int fd); // 绑定事件
void skynet_socket_close(struct skynet_context *ctx, int id); // 关闭 Socket
void skynet_socket_shutdown(struct skynet_context *ctx, int id);
void skynet_socket_start(struct skynet_context *ctx, int id); // 启动 Socket
void skynet_socket_nodelay(struct skynet_context *ctx, int id);

int skynet_socket_udp(struct skynet_context *ctx, const char * addr, int port);
int skynet_socket_udp_connect(struct skynet_context *ctx, int id, const char * addr, int port);
int skynet_socket_udp_send(struct skynet_context *ctx, int id, const char * address, const void *buffer, int sz);
const char * skynet_socket_udp_address(struct skynet_socket_message *, int *addrsz);

#endif
