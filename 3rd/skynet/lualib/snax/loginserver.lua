local skynet = require "skynet"
require "skynet.manager"
local socket = require "socket"
local crypt = require "crypt"
local table = table
local string = string
local assert = assert

--[[

Protocol:

	line (\n) based text protocol

	1. Server->Client : base64(8bytes random challenge)
	2. Client->Server : base64(8bytes handshake client key)
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : base64(DH-Exchange(server key))
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : base64(HMAC(challenge, secret))
	7. Client->Server : DES(secret, base64(token))
	8. Server : call auth_handler(token) -> server, uid (A user defined method)
	9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	10. Server->Client : 200 base64(subid)
	
	（1）L产生随机数challenge，并发送给C，主要用于最后验证密钥secret是否交换成功。

	（2）C产生随机数clientkey，clientkey是保密的，只有C知道，并通过dhexchange算法换算clientkey，得到ckey。 把base64编码的ckey发送给L。

​	（3）L也产生随机数serverkey，serverkey是保密的，只有L知道，并通过dhexchange算法换算serverkey，得到skey。把base64编码的skey发送给C。

​	（4）C使用clientkey与skey，通过dhsecret算法得到最终安全密钥secret。

​	（5）L使用serverKey与ckey, 通过dhsecret算法得到最终安全密钥secret。C 和 L最终得到的secret是一样的，而传输过程只有ckey skey是通过网络公开的，即使ckey skey泄露了，也无法推算出secret。

​	（6）密钥交换完成后，需要验证一下双方的密钥是否是一致的。C使用密钥secret通过hmac64哈希算法加密第1步中接收到的challenge，得到CHmac，然后转码成base64 CHmac发送给L。

​	（7）L收到CHmac后，自己也使用密钥secret通过hmac64哈希算法加密第1步中发送出去的challenge，得到SHmac，对比SHmac与CHmac是否一致，如果一致，则密钥交换成功。不成功就断开连接。

​	（8）C组合base64 user@base64 server:base64 passwd字符串（server为客户端具体想要登录的登录点，远端服务器可能有多个实际登录点），使用secret通过DES加密，得到etoken，发送base64 etoken。

​	（9）使用secret通过DES解密etoken，得到user@server:passwd，校验user与passwd是否正确，通知实际登录点server，传递user与secret给server，server生成subid返回。发送状态码 200 base64 subid给C。

​	（10）C得到subid后就可以断开login服务的连接，然后去连接实际登录点server了。（实际登录点server，可以由L通知C，也可以C指定想要登录哪个点，将在下一个章提到）
Error Code:
	400 Bad Request . challenge failed
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 base64(subid)
]]

local socket_error = {}
local function assert_socket(service, v, fd)
	if v then
		return v
	else
		skynet.error(string.format("%s failed: socket (fd = %d) closed", service, fd))
		error(socket_error)
	end
end

--尝试写socket，如果写失败assert
local function write(service, fd, text)
	assert_socket(service, socket.write(fd, text), fd)
end

local function launch_slave(auth_handler)
	local function auth(fd, addr)
		-- set socket buffer limit (8K)
		-- If the attacker send large package, close the socket
		socket.limit(fd, 8192)

		local challenge = crypt.randomkey()
		write("auth", fd, crypt.base64encode(challenge).."\n")
		skynet.error(string.format("auth challenge   %s", crypt.base64encode(challenge)))
		local handshake = assert_socket("auth", socket.readline(fd), fd)
		local clientkey = crypt.base64decode(handshake)
		if #clientkey ~= 8 then
			error "Invalid client key"
		end
		local serverkey = crypt.randomkey()
		write("auth", fd, crypt.base64encode(crypt.dhexchange(serverkey)).."\n")

		local secret = crypt.dhsecret(clientkey, serverkey)

		local response = assert_socket("auth", socket.readline(fd), fd)
		local hmac = crypt.hmac64(challenge, secret)

		if hmac ~= crypt.base64decode(response) then
			write("auth", fd, "400 Bad Request\n")
			error "challenge failed"
		end

		local etoken = assert_socket("auth", socket.readline(fd),fd)

		local token = crypt.desdecode(secret, crypt.base64decode(etoken))

		local ok, server, uid =  pcall(auth_handler,token)

		return ok, server, uid, secret
	end

	local function ret_pack(ok, err, ...)
		if ok then
			return skynet.pack(err, ...)
		else
			if err == socket_error then
				return skynet.pack(nil, "socket error")
			else
				return skynet.pack(false, err)
			end
		end
	end

	local function auth_fd(fd, addr)
		skynet.error(string.format("connect from %s (fd = %d)", addr, fd))
		socket.start(fd)	-- may raise error here
		local msg, len = ret_pack(pcall(auth, fd, addr))
		socket.abandon(fd)	-- never raise error here
		return msg, len
	end

	skynet.dispatch("lua", function(_,_,...)
		local ok, msg, len = pcall(auth_fd, ...)
		if ok then
			skynet.ret(msg,len)
		else
			skynet.ret(skynet.pack(false, msg))
		end
	end)
	
end --end local function launch_slave(auth_handler)

local user_login = {}

local function accept(conf, s, fd, addr)
	skynet.error(string.format("login accept at : %s %s", fd, addr))
	-- call slave auth
	local ok, server, uid, secret = skynet.call(s, "lua",  fd, addr)
	-- slave will accept(start) fd, so we can write to fd later

	if not ok then
		if ok ~= nil then
			write("response 401", fd, "401 Unauthorized\n")
		end
		error(server)
	end

	if not conf.multilogin then
		if user_login[uid] then
			write("response 406", fd, "406 Not Acceptable\n")
			error(string.format("User %s is already login", uid))
		end

		user_login[uid] = true
	end

	local ok, err = pcall(conf.login_handler, server, uid, secret)
	-- unlock login
	user_login[uid] = nil

	if ok then
		err = err or ""
		write("response 200",fd,  "200 "..crypt.base64encode(err).."\n")
	else
		write("response 403",fd,  "403 Forbidden\n")
		error(err)
	end
end

local function launch_master(conf)
	local instance = conf.instance or 8
	assert(instance > 0)
	local host = conf.host or "0.0.0.0"
	local port = assert(tonumber(conf.port))
	local slave = {}
	local balance = 1

	skynet.dispatch("lua", function(_,source,command, ...)
		skynet.ret(skynet.pack(conf.command_handler(command, ...)))
	end)

	for i=1,instance do
		table.insert(slave, skynet.newservice(SERVICE_NAME))
	end

	skynet.error(string.format("login server listen at : %s %d", host, port))
	local id = socket.listen(host, port)
	socket.start(id , function(fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > #slave then
			balance = 1
		end
		local ok, err = pcall(accept, conf, s, fd, addr)
		if not ok then
			if err ~= socket_error then
				skynet.error(string.format("invalid client (fd = %d) error = %s", fd, err))
			end
		end
		socket.close_fd(fd)	-- We haven't call socket.start, so use socket.close_fd rather than socket.close.
	end)
end

-- local server = {
	-- host = "127.0.0.1",
	-- port = 8001,
	-- multilogin = false,	-- disallow multilogin
	-- name = "login_master",
-- }
local function login(conf)
	local name = "." .. (conf.name or "login")
	skynet.start(function()
	--用来查询一个 . 开头的名字对应的地址。
	--它是一个非阻塞 API ，不可以查询跨节点的全局名字。
		local loginmaster = skynet.localname(name)
		if loginmaster then
			local auth_handler = assert(conf.auth_handler)
			launch_master = nil
			conf = nil
			launch_slave(auth_handler)
		else
			launch_slave = nil
			conf.auth_handler = nil
			assert(conf.login_handler)
			assert(conf.command_handler)
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return login
