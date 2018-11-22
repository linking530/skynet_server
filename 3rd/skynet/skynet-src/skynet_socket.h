#ifndef skynet_socket_h
#define skynet_socket_h

struct skynet_context;
// ���Կ����Ƕ� socket_server �ﷵ��ֵ���͵ķ�װ
#define SKYNET_SOCKET_TYPE_DATA 1
#define SKYNET_SOCKET_TYPE_CONNECT 2
#define SKYNET_SOCKET_TYPE_CLOSE 3
#define SKYNET_SOCKET_TYPE_ACCEPT 4
#define SKYNET_SOCKET_TYPE_ERROR 5
#define SKYNET_SOCKET_TYPE_UDP 6
#define SKYNET_SOCKET_TYPE_WARNING 7
// ��Ӧ skynet_socket_server ��������Ϣ����  
struct skynet_socket_message {
	int type; // ����
	int id; // ���
	int ud;
	char * buffer; // ������
};

void skynet_socket_init(); // ��ʼ�� Socket
void skynet_socket_exit(); // �˳� Socket
void skynet_socket_free(); // �ͷ� Socket
int skynet_socket_poll();  // �鿴 Socket ��Ϣ

int skynet_socket_send(struct skynet_context *ctx, int id, void *buffer, int sz); // ��������
void skynet_socket_send_lowpriority(struct skynet_context *ctx, int id, void *buffer, int sz); // �����ȼ���������
int skynet_socket_listen(struct skynet_context *ctx, const char *host, int port, int backlog); // ���� Socket
int skynet_socket_connect(struct skynet_context *ctx, const char *host, int port); // Socket ����
int skynet_socket_bind(struct skynet_context *ctx, int fd); // ���¼�
void skynet_socket_close(struct skynet_context *ctx, int id); // �ر� Socket
void skynet_socket_shutdown(struct skynet_context *ctx, int id);
void skynet_socket_start(struct skynet_context *ctx, int id); // ���� Socket
void skynet_socket_nodelay(struct skynet_context *ctx, int id);

int skynet_socket_udp(struct skynet_context *ctx, const char * addr, int port);
int skynet_socket_udp_connect(struct skynet_context *ctx, int id, const char * addr, int port);
int skynet_socket_udp_send(struct skynet_context *ctx, int id, const char * address, const void *buffer, int sz);
const char * skynet_socket_udp_address(struct skynet_socket_message *, int *addrsz);

#endif
