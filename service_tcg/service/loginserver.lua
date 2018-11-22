local skynet = require "skynet"
local socket = require "socket"

local syslog = require "syslog"
local config = require "config.system"
local netpack = require "netpack"
local p = require "p.core"
-- local character_handler = require "agent.character_handler"
local session_id = 1
local slave = {}
local nslave
local gameserver = {}

local CMD = {}

local function xfs_send(v)
	data = p.unpack(v)
	print("[LOG]",os.date("%m-%d-%Y %X", skynet.time()),"send ok",data.v,data.p)
	socket.write(client_fd, netpack.pack(v))
end

function CMD.open (conf)
    -- character_handler.init({})
	syslog.noticef ("loginserver CMD.open conf:")
	
--local config = {
--	port = 9777, 
--	slave = 8,
--	auth_timeout = 10, -- seconds
--	session_expire_time = 30 * 60, -- seconds
--}	
	
	for i = 1, conf.slave do
		local s = skynet.newservice ("loginslave")
		skynet.call (s, "lua", "init", skynet.self (), i, conf)
		table.insert (slave, s)
	end
	--#的实际作用是获得一个table中最大的数字键值
	nslave = #slave

	local host = conf.host or "0.0.0.0"
	local port = assert (tonumber (conf.port))
	local sock = socket.listen (host, port)

	syslog.noticef ("listen on %s:%d", host, port)

	local balance = 1
	--如果接到数据、不分拆交给slave auth函数处理
	socket.start (sock, function (fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > nslave then balance = 1 end
		skynet.call (s, "lua", "auth", fd, addr)
	end)
end

function CMD.save_session (account, key, challenge)
	syslog.noticef ("loginserver CMD.save_session account:%s, key:%s, challenge:%s",account, key, challenge)
	session = session_id
	session_id = session_id + 1

	s = slave[(session % nslave) + 1]
	skynet.call (s, "lua", "save_session", session, account, key, challenge)
	return session
end

function CMD.challenge (session, challenge)
	syslog.noticef ("loginserver CMD.challenge session:%s, challenge:%s",session, challenge)
	s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "challenge", session, challenge)
end

function CMD.verify (session, token)
	syslog.noticef ("loginserver CMD.verify session:%s, token:%s",session, token)
	local s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "verify", session, token)
end

--c服务snlua启动后执行的第一个lua文件里面的主逻辑必定是skynet.start(start_func)，
--由此开始运行lua服务的逻辑
--skynet.retpack 跟skynet.ret的区别是向请求方作回应时要用skynet.pack打包

--skynet.dispatch(typename, func)
--修改以typename为协议名的协议：
--用func这个函数来作为协议的dispatch函数(默认的lua协议没提供dispatch，
--需要使用者根据业务需要写)
skynet.start (function ()
	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (...))
	end)
	
end)
