local login = require "snax.loginserver"
local crypt = require "crypt"
local skynet = require "skynet"
require "struct.globle"
local syslog = require "syslog"
local logstat = require "base.logstat"

-- 200 [base64(subid)] --登录成功会返回一个subid，这个subid是这次登录的唯一标识
-- 400 Bad Request --握手失败
-- 401 Unauthorized --自定义的 auth_handler 不认可 token
-- 403 Forbidden --自定义的 login_handler 执行失败
-- 406 Not Acceptable --该用户已经在登陆中。（只发生在 multilogin 关闭时）

local server = {
	host = "0.0.0.0",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

--服务器表
local server_list = {}
--在线玩家
local user_online = {}
local user_login = {}
--你需要实现这个方法，对一个客户端发送过来的 token 做验证。
--如果验证不能通过，可以通过 error 抛出异常。
--如果验证通过，需要返回用户希望进入的登陆点以及用户名。
--登陆点可以是包含在 token 内由用户自行决定,也可以在这里实现一个负载均衡器来选择）
function server.auth_handler(token)
	-- the token is base64(user)@base64(server):base64(password)
	--通过正则表达式，解析出各个参数
	local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	server = crypt.base64decode(server)
	password = crypt.base64decode(password)
	--密码不对直接报错中断当前协程，千万不要返回nil值，一定要用assert中断或者error报错终止掉当前协程
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

-- 你需要实现这个方法，处理当用户已经验证通过后，该如何通知具体的登陆点（server ）。
-- 框架会交给你用户名（uid）和已经安全交换到的通讯密钥。
-- 你需要把它们交给登陆点，并得到确认（等待登陆点准备好后）才可以返回。
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

--实现command_handler，用来处理lua消息，必须注册
function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(server)
