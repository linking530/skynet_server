local msgserver = require "snax.msgserver"
local crypt = require "crypt"
local skynet = require "skynet"

local loginservice = tonumber(...)

local server = {}
local users = {}
local username_map = {}
local internal_id = 0

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
--当一个用户登陆后，登陆服务器会转交给你这个用户的 uid 和 serect ，最终会触发 login_handler 方法。
--在这个函数里，你需要做的是判定这个用户是否真的可以登陆。然后为用户生成一个 subid ，使用 msgserver.username(uid, subid, servername) 可以得到这个用户这次的登陆名。这里 servername 是当前登陆点的名字。
--在这个过程中，如果你发现一些意外情况，不希望用户进入，只需要用 error 抛出异常。
--外部发消息来调用，一般是loginserver发消息来，你需要产生唯一的subid，如果loginserver不允许multilogin，那么这个函数也不会重入。
function server.login_handler(uid, secret)
	if users[uid] then
		error(string.format("%s is already login", uid))
	end

	internal_id = internal_id + 1
	local id = internal_id	-- don't use internal_id directly
	--通过uid以及subid获得username
	local username = msgserver.username(uid, id, servername)

	-- you can use a pool to alloc new agent
	local agent = skynet.newservice "msgagent"
	local u = {
		username = username,
		agent = agent,
		uid = uid,
		subid = id,
	}

	-- trash subid (no used)
	skynet.call(agent, "lua", "login", uid, id, secret)

	users[uid] = u
	username_map[username] = u
	
	--正在登录，给登录名注册一个secret
	msgserver.login(username, secret)

	-- you should return unique subid
	return id
end

-- call by agent
--当一个用户想登出时，这个函数会被调用，你可以在里面做一些状态清除的工作。
--外部发消息来调用，登出uid对应的登录名
function server.logout_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.logout(u.username)
		users[uid] = nil
		username_map[u.username] = nil
		skynet.call(loginservice, "lua", "logout",uid, subid)
	end
end

-- call by login server
--当外界（通常是登陆服务器）希望让一个用户登出时，会触发这个事件。
--发起一个 logout 消息（最终会触发 logout_handler）
--一般给loginserver发消息来调用，可以作为登出操作
function server.kick_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
		pcall(skynet.call, u.agent, "lua", "logout")
	end
end

-- call by self (when socket disconnect)
--当用户的通讯连接断开后，会触发这个事件。你可以不关心这个事件，也可以利用这个事件做超时管理。
--（比如断开连接后一定时间不重新连回来就主动登出。）
--当客户端断开了连接，这个回调函数会被调用
function server.disconnect_handler(username)
	local u = username_map[username]
	if u then
		skynet.call(u.agent, "lua", "afk")
	end
end

-- call by self (when recv a request from client)
--如果用户提起了一个请求，就会被这个 request_handler会被调用。这里隐藏了 session 信息，
--等请求处理完后，只需要返回一个字符串，这个字符串会回到框架，加上 session 回应客户端。
--这个函数中允许抛出异常，框架会正确的捕获这个异常，并通过协议通知客户端。
--当接收到客户端的网络请求，这个回调函数会被调用，需要给与应答
function server.request_handler(username, msg)
	local u = username_map[username]
	return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
end

-- call by self (when gate open)
--在打开端口时，会触发这个register_handler函数参数name是在配置信息中配置的当前登陆点的名字
--你在这个回调要做的事件是通知登录服务器，我这个登录点准备好了
--注册一下登录点服务，主要是告诉loginservice这个有这个登录点的存在
function server.register_handler(name)
	servername = name
	skynet.call(loginservice, "lua", "register_gate", servername, skynet.self())
end

--print("gate msgserver.start(server)..")
--服务初始化函数，要把server表传递进去。
msgserver.start(server)

