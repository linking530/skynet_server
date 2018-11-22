local login = require "snax.loginserver"
local crypt = require "crypt"
local skynet = require "skynet"
require "struct.globle"
local syslog = require "syslog"
local logstat = require "base.logstat"

-- 200 [base64(subid)] --��¼�ɹ��᷵��һ��subid�����subid����ε�¼��Ψһ��ʶ
-- 400 Bad Request --����ʧ��
-- 401 Unauthorized --�Զ���� auth_handler ���Ͽ� token
-- 403 Forbidden --�Զ���� login_handler ִ��ʧ��
-- 406 Not Acceptable --���û��Ѿ��ڵ�½�С���ֻ������ multilogin �ر�ʱ��

local server = {
	host = "0.0.0.0",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

--��������
local server_list = {}
--�������
local user_online = {}
local user_login = {}
--����Ҫʵ�������������һ���ͻ��˷��͹����� token ����֤��
--�����֤����ͨ��������ͨ�� error �׳��쳣��
--�����֤ͨ������Ҫ�����û�ϣ������ĵ�½���Լ��û�����
--��½������ǰ����� token �����û����о���,Ҳ����������ʵ��һ�����ؾ�������ѡ��
function server.auth_handler(token)
	-- the token is base64(user)@base64(server):base64(password)
	--ͨ��������ʽ����������������
	local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	server = crypt.base64decode(server)
	password = crypt.base64decode(password)
	--���벻��ֱ�ӱ����жϵ�ǰЭ�̣�ǧ��Ҫ����nilֵ��һ��Ҫ��assert�жϻ���error������ֹ����ǰЭ��
	--assert(password == "password", "Invalid password")
	local mysqlserver = skynet.localname(".mysqlserver")	
	local sql = "select * from name_list where player_name=\""..user.."\""
	logstat.log_day("sql","sql:"..sql.."\n")
	local ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))
	if ret[1]== nil then 
		 print("not role")
		 sql = "INSERT INTO name_list (player_name, player_account,) VALUES ('"..user.."', '"..user.."')"
		 local ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	else
		 print("role"..ret[1]["role_id"]..ret[1]["player_name"]..ret[1]["player_account"])
	end
	return server, user
end

-- ����Ҫʵ����������������û��Ѿ���֤ͨ���󣬸����֪ͨ����ĵ�½�㣨server ����
-- ��ܻύ�����û�����uid�����Ѿ���ȫ��������ͨѶ��Կ��
-- ����Ҫ�����ǽ�����½�㣬���õ�ȷ�ϣ��ȴ���½��׼���ú󣩲ſ��Է��ء�
function server.login_handler(server, uid, secret)
	print(string.format("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))
	local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	if last then
		skynet.call(last.address, "lua", "kick", uid, last.subid)
	end
	if user_online[uid] then
		error(string.format("user %s is already online", uid))
	end

	local subid = tostring(skynet.call(gameserver, "lua", "login", uid, secret))
	user_online[uid] = { address = gameserver, subid = subid , server = server}
	return subid
end

local CMD = {}

function CMD.register_gate(server, address)
	print(string.format("register_gate %s %s", server, address))
	server_list[server] = address
end

function CMD.logout(uid, subid)
	local u = user_online[uid]
	if u then
		print(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

--ʵ��command_handler����������lua��Ϣ������ע��
function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(server)
