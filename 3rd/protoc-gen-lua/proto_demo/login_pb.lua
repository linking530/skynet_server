-- Generated By protoc-gen-lua Do not Edit
local protobuf = require "protobuf"
module('login_pb')


local LOGIN_RESULT = protobuf.Descriptor();
local LOGIN_RESULT_ID_FIELD = protobuf.FieldDescriptor();
local LOGIN_CREATE = protobuf.Descriptor();
local LOGIN_CREATE_USERID_FIELD = protobuf.FieldDescriptor();
local LOGIN_CREATE_NAME_FIELD = protobuf.FieldDescriptor();
local LOGIN_USERS = protobuf.Descriptor();
local LOGIN_USERS_LOGIN_USER = protobuf.Descriptor();
local LOGIN_USERS_LOGIN_USER_USERID_FIELD = protobuf.FieldDescriptor();
local LOGIN_USERS_LOGIN_USER_NAME_FIELD = protobuf.FieldDescriptor();
local LOGIN_USERS_USERS_FIELD = protobuf.FieldDescriptor();
local LOGIN_MESSAGE = protobuf.Descriptor();
local LOGIN_MESSAGE_FROMUSERID_FIELD = protobuf.FieldDescriptor();
local LOGIN_MESSAGE_TOUSERID_FIELD = protobuf.FieldDescriptor();
local LOGIN_MESSAGE_MSG_FIELD = protobuf.FieldDescriptor();
local LOGIN_ENTER = protobuf.Descriptor();
local LOGIN_ENTER_ACCOUNT_FIELD = protobuf.FieldDescriptor();
local LOGIN_ENTER_PASSWORD_FIELD = protobuf.FieldDescriptor();
local LOGIN_SERVER = protobuf.Descriptor();
local LOGIN_SERVER_IP_FIELD = protobuf.FieldDescriptor();
local LOGIN_SERVER_PORT_FIELD = protobuf.FieldDescriptor();
local LOGIN_SERVER_ACCOUNT_FIELD = protobuf.FieldDescriptor();
local LOGIN_SERVER_PASSWORD_FIELD = protobuf.FieldDescriptor();

LOGIN_RESULT_ID_FIELD.name = "id"
LOGIN_RESULT_ID_FIELD.full_name = ".login.login_result.id"
LOGIN_RESULT_ID_FIELD.number = 1
LOGIN_RESULT_ID_FIELD.index = 0
LOGIN_RESULT_ID_FIELD.label = 2
LOGIN_RESULT_ID_FIELD.has_default_value = false
LOGIN_RESULT_ID_FIELD.default_value = 0
LOGIN_RESULT_ID_FIELD.type = 5
LOGIN_RESULT_ID_FIELD.cpp_type = 1

LOGIN_RESULT.name = "login_result"
LOGIN_RESULT.full_name = ".login.login_result"
LOGIN_RESULT.nested_types = {}
LOGIN_RESULT.enum_types = {}
LOGIN_RESULT.fields = {LOGIN_RESULT_ID_FIELD}
LOGIN_RESULT.is_extendable = false
LOGIN_RESULT.extensions = {}
LOGIN_CREATE_USERID_FIELD.name = "userid"
LOGIN_CREATE_USERID_FIELD.full_name = ".login.login_create.userid"
LOGIN_CREATE_USERID_FIELD.number = 1
LOGIN_CREATE_USERID_FIELD.index = 0
LOGIN_CREATE_USERID_FIELD.label = 2
LOGIN_CREATE_USERID_FIELD.has_default_value = false
LOGIN_CREATE_USERID_FIELD.default_value = 0
LOGIN_CREATE_USERID_FIELD.type = 5
LOGIN_CREATE_USERID_FIELD.cpp_type = 1

LOGIN_CREATE_NAME_FIELD.name = "name"
LOGIN_CREATE_NAME_FIELD.full_name = ".login.login_create.name"
LOGIN_CREATE_NAME_FIELD.number = 2
LOGIN_CREATE_NAME_FIELD.index = 1
LOGIN_CREATE_NAME_FIELD.label = 2
LOGIN_CREATE_NAME_FIELD.has_default_value = false
LOGIN_CREATE_NAME_FIELD.default_value = ""
LOGIN_CREATE_NAME_FIELD.type = 9
LOGIN_CREATE_NAME_FIELD.cpp_type = 9

LOGIN_CREATE.name = "login_create"
LOGIN_CREATE.full_name = ".login.login_create"
LOGIN_CREATE.nested_types = {}
LOGIN_CREATE.enum_types = {}
LOGIN_CREATE.fields = {LOGIN_CREATE_USERID_FIELD, LOGIN_CREATE_NAME_FIELD}
LOGIN_CREATE.is_extendable = false
LOGIN_CREATE.extensions = {}
LOGIN_USERS_LOGIN_USER_USERID_FIELD.name = "userid"
LOGIN_USERS_LOGIN_USER_USERID_FIELD.full_name = ".login.login_users.login_user.userid"
LOGIN_USERS_LOGIN_USER_USERID_FIELD.number = 1
LOGIN_USERS_LOGIN_USER_USERID_FIELD.index = 0
LOGIN_USERS_LOGIN_USER_USERID_FIELD.label = 2
LOGIN_USERS_LOGIN_USER_USERID_FIELD.has_default_value = false
LOGIN_USERS_LOGIN_USER_USERID_FIELD.default_value = 0
LOGIN_USERS_LOGIN_USER_USERID_FIELD.type = 5
LOGIN_USERS_LOGIN_USER_USERID_FIELD.cpp_type = 1

LOGIN_USERS_LOGIN_USER_NAME_FIELD.name = "name"
LOGIN_USERS_LOGIN_USER_NAME_FIELD.full_name = ".login.login_users.login_user.name"
LOGIN_USERS_LOGIN_USER_NAME_FIELD.number = 2
LOGIN_USERS_LOGIN_USER_NAME_FIELD.index = 1
LOGIN_USERS_LOGIN_USER_NAME_FIELD.label = 2
LOGIN_USERS_LOGIN_USER_NAME_FIELD.has_default_value = false
LOGIN_USERS_LOGIN_USER_NAME_FIELD.default_value = ""
LOGIN_USERS_LOGIN_USER_NAME_FIELD.type = 9
LOGIN_USERS_LOGIN_USER_NAME_FIELD.cpp_type = 9

LOGIN_USERS_LOGIN_USER.name = "login_user"
LOGIN_USERS_LOGIN_USER.full_name = ".login.login_users.login_user"
LOGIN_USERS_LOGIN_USER.nested_types = {}
LOGIN_USERS_LOGIN_USER.enum_types = {}
LOGIN_USERS_LOGIN_USER.fields = {LOGIN_USERS_LOGIN_USER_USERID_FIELD, LOGIN_USERS_LOGIN_USER_NAME_FIELD}
LOGIN_USERS_LOGIN_USER.is_extendable = false
LOGIN_USERS_LOGIN_USER.extensions = {}
LOGIN_USERS_LOGIN_USER.containing_type = LOGIN_USERS
LOGIN_USERS_USERS_FIELD.name = "users"
LOGIN_USERS_USERS_FIELD.full_name = ".login.login_users.users"
LOGIN_USERS_USERS_FIELD.number = 1
LOGIN_USERS_USERS_FIELD.index = 0
LOGIN_USERS_USERS_FIELD.label = 3
LOGIN_USERS_USERS_FIELD.has_default_value = false
LOGIN_USERS_USERS_FIELD.default_value = {}
LOGIN_USERS_USERS_FIELD.message_type = LOGIN_USERS_LOGIN_USER
LOGIN_USERS_USERS_FIELD.type = 11
LOGIN_USERS_USERS_FIELD.cpp_type = 10

LOGIN_USERS.name = "login_users"
LOGIN_USERS.full_name = ".login.login_users"
LOGIN_USERS.nested_types = {LOGIN_USERS_LOGIN_USER}
LOGIN_USERS.enum_types = {}
LOGIN_USERS.fields = {LOGIN_USERS_USERS_FIELD}
LOGIN_USERS.is_extendable = false
LOGIN_USERS.extensions = {}
LOGIN_MESSAGE_FROMUSERID_FIELD.name = "fromuserid"
LOGIN_MESSAGE_FROMUSERID_FIELD.full_name = ".login.login_message.fromuserid"
LOGIN_MESSAGE_FROMUSERID_FIELD.number = 1
LOGIN_MESSAGE_FROMUSERID_FIELD.index = 0
LOGIN_MESSAGE_FROMUSERID_FIELD.label = 2
LOGIN_MESSAGE_FROMUSERID_FIELD.has_default_value = false
LOGIN_MESSAGE_FROMUSERID_FIELD.default_value = 0
LOGIN_MESSAGE_FROMUSERID_FIELD.type = 5
LOGIN_MESSAGE_FROMUSERID_FIELD.cpp_type = 1

LOGIN_MESSAGE_TOUSERID_FIELD.name = "touserid"
LOGIN_MESSAGE_TOUSERID_FIELD.full_name = ".login.login_message.touserid"
LOGIN_MESSAGE_TOUSERID_FIELD.number = 2
LOGIN_MESSAGE_TOUSERID_FIELD.index = 1
LOGIN_MESSAGE_TOUSERID_FIELD.label = 2
LOGIN_MESSAGE_TOUSERID_FIELD.has_default_value = false
LOGIN_MESSAGE_TOUSERID_FIELD.default_value = 0
LOGIN_MESSAGE_TOUSERID_FIELD.type = 5
LOGIN_MESSAGE_TOUSERID_FIELD.cpp_type = 1

LOGIN_MESSAGE_MSG_FIELD.name = "msg"
LOGIN_MESSAGE_MSG_FIELD.full_name = ".login.login_message.msg"
LOGIN_MESSAGE_MSG_FIELD.number = 3
LOGIN_MESSAGE_MSG_FIELD.index = 2
LOGIN_MESSAGE_MSG_FIELD.label = 2
LOGIN_MESSAGE_MSG_FIELD.has_default_value = false
LOGIN_MESSAGE_MSG_FIELD.default_value = ""
LOGIN_MESSAGE_MSG_FIELD.type = 9
LOGIN_MESSAGE_MSG_FIELD.cpp_type = 9

LOGIN_MESSAGE.name = "login_message"
LOGIN_MESSAGE.full_name = ".login.login_message"
LOGIN_MESSAGE.nested_types = {}
LOGIN_MESSAGE.enum_types = {}
LOGIN_MESSAGE.fields = {LOGIN_MESSAGE_FROMUSERID_FIELD, LOGIN_MESSAGE_TOUSERID_FIELD, LOGIN_MESSAGE_MSG_FIELD}
LOGIN_MESSAGE.is_extendable = false
LOGIN_MESSAGE.extensions = {}
LOGIN_ENTER_ACCOUNT_FIELD.name = "account"
LOGIN_ENTER_ACCOUNT_FIELD.full_name = ".login.login_enter.account"
LOGIN_ENTER_ACCOUNT_FIELD.number = 1
LOGIN_ENTER_ACCOUNT_FIELD.index = 0
LOGIN_ENTER_ACCOUNT_FIELD.label = 2
LOGIN_ENTER_ACCOUNT_FIELD.has_default_value = false
LOGIN_ENTER_ACCOUNT_FIELD.default_value = ""
LOGIN_ENTER_ACCOUNT_FIELD.type = 9
LOGIN_ENTER_ACCOUNT_FIELD.cpp_type = 9

LOGIN_ENTER_PASSWORD_FIELD.name = "password"
LOGIN_ENTER_PASSWORD_FIELD.full_name = ".login.login_enter.password"
LOGIN_ENTER_PASSWORD_FIELD.number = 2
LOGIN_ENTER_PASSWORD_FIELD.index = 1
LOGIN_ENTER_PASSWORD_FIELD.label = 2
LOGIN_ENTER_PASSWORD_FIELD.has_default_value = false
LOGIN_ENTER_PASSWORD_FIELD.default_value = ""
LOGIN_ENTER_PASSWORD_FIELD.type = 9
LOGIN_ENTER_PASSWORD_FIELD.cpp_type = 9

LOGIN_ENTER.name = "login_enter"
LOGIN_ENTER.full_name = ".login.login_enter"
LOGIN_ENTER.nested_types = {}
LOGIN_ENTER.enum_types = {}
LOGIN_ENTER.fields = {LOGIN_ENTER_ACCOUNT_FIELD, LOGIN_ENTER_PASSWORD_FIELD}
LOGIN_ENTER.is_extendable = false
LOGIN_ENTER.extensions = {}
LOGIN_SERVER_IP_FIELD.name = "ip"
LOGIN_SERVER_IP_FIELD.full_name = ".login.login_server.ip"
LOGIN_SERVER_IP_FIELD.number = 1
LOGIN_SERVER_IP_FIELD.index = 0
LOGIN_SERVER_IP_FIELD.label = 2
LOGIN_SERVER_IP_FIELD.has_default_value = false
LOGIN_SERVER_IP_FIELD.default_value = ""
LOGIN_SERVER_IP_FIELD.type = 9
LOGIN_SERVER_IP_FIELD.cpp_type = 9

LOGIN_SERVER_PORT_FIELD.name = "port"
LOGIN_SERVER_PORT_FIELD.full_name = ".login.login_server.port"
LOGIN_SERVER_PORT_FIELD.number = 2
LOGIN_SERVER_PORT_FIELD.index = 1
LOGIN_SERVER_PORT_FIELD.label = 2
LOGIN_SERVER_PORT_FIELD.has_default_value = false
LOGIN_SERVER_PORT_FIELD.default_value = 0
LOGIN_SERVER_PORT_FIELD.type = 5
LOGIN_SERVER_PORT_FIELD.cpp_type = 1

LOGIN_SERVER_ACCOUNT_FIELD.name = "account"
LOGIN_SERVER_ACCOUNT_FIELD.full_name = ".login.login_server.account"
LOGIN_SERVER_ACCOUNT_FIELD.number = 3
LOGIN_SERVER_ACCOUNT_FIELD.index = 2
LOGIN_SERVER_ACCOUNT_FIELD.label = 2
LOGIN_SERVER_ACCOUNT_FIELD.has_default_value = false
LOGIN_SERVER_ACCOUNT_FIELD.default_value = ""
LOGIN_SERVER_ACCOUNT_FIELD.type = 9
LOGIN_SERVER_ACCOUNT_FIELD.cpp_type = 9

LOGIN_SERVER_PASSWORD_FIELD.name = "password"
LOGIN_SERVER_PASSWORD_FIELD.full_name = ".login.login_server.password"
LOGIN_SERVER_PASSWORD_FIELD.number = 4
LOGIN_SERVER_PASSWORD_FIELD.index = 3
LOGIN_SERVER_PASSWORD_FIELD.label = 2
LOGIN_SERVER_PASSWORD_FIELD.has_default_value = false
LOGIN_SERVER_PASSWORD_FIELD.default_value = ""
LOGIN_SERVER_PASSWORD_FIELD.type = 9
LOGIN_SERVER_PASSWORD_FIELD.cpp_type = 9

LOGIN_SERVER.name = "login_server"
LOGIN_SERVER.full_name = ".login.login_server"
LOGIN_SERVER.nested_types = {}
LOGIN_SERVER.enum_types = {}
LOGIN_SERVER.fields = {LOGIN_SERVER_IP_FIELD, LOGIN_SERVER_PORT_FIELD, LOGIN_SERVER_ACCOUNT_FIELD, LOGIN_SERVER_PASSWORD_FIELD}
LOGIN_SERVER.is_extendable = false
LOGIN_SERVER.extensions = {}

login_create = protobuf.Message(LOGIN_CREATE)
login_enter = protobuf.Message(LOGIN_ENTER)
login_message = protobuf.Message(LOGIN_MESSAGE)
login_result = protobuf.Message(LOGIN_RESULT)
login_server = protobuf.Message(LOGIN_SERVER)
login_users = protobuf.Message(LOGIN_USERS)
login_users.login_user = protobuf.Message(LOGIN_USERS_LOGIN_USER)

