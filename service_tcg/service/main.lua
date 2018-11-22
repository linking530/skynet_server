local skynet = require "skynet"
--\lualib\config\system.lua
local config = require "config.system"
local login_config = require "config.loginserver"
local game_config = require "config.gameserver"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local syslog = require "syslog"

local sharedata = require "sharedata"
local carddata = require "data.carddata"
local userinfo =  require "data.userinfo"
local deckinfo = require "data.deckinfo"

skynet.start(function()
    logstat.create()
	
--    logstat.log_day("hello","hello world !")
    local protobufload = protobufload.inst()
--	protobufload.env_new()
	protobufload.initload(protobufload)

	-- userinfo.initload()
	
	-- local mpCards,mpCmds = carddata.initload()
	-- sharedata.new("mpCards", mpCards)
	-- sharedata.new("mpCmds", mpCmds)
	-- print_r(mpCmds[10001])	
	-- local deckplay,decknpc = deckinfo.initload()
	-- sharedata.new("deckplay", deckplay)
	-- sharedata.new("decknpc", decknpc)	
	-- local data_userinfo,mpBase = userinfo.initload()
	-- sharedata.new("data_userinfo", data_userinfo)
	-- sharedata.new("mpBase", mpBase)	
	skynet.uniqueservice("luaconf")	
	skynet.newservice ("debug_me", config.debug_port)

	skynet.newservice ("protod")
	skynet.uniqueservice ("mysqlserver")
	skynet.uniqueservice ("shopserver")
	skynet.newservice("battleserver")
	
	local loginserver = skynet.newservice ("loginserver")
	skynet.call (loginserver, "lua", "open", login_config)	
    syslog.noticef ("main loginserver:%d",loginserver)	
	local gamed = skynet.newservice("gamed")
	skynet.call(gamed, "lua", "start", {
		port = 9555,
		maxclient = max_client,
	})
---------------------新登录接口-----------------------------------------------
--[[ 要使用msgserver一般都要跟loginserver一起使用,下面我们让他们一起工作.
客户端登录的时候,一般先登录loginserver,然后再去连接实际登录点,
msgserver一般充当真实登录点的角色,原理图如下:
]]--
	local logind = skynet.newservice("logind")
	local gate = skynet.newservice("gated", logind)
	--网关服务需要发送lua open来打开，open也是保留的命令
	skynet.call(gate, "lua", "open" , {
		port = 8888,
		maxclient = 64,
		servername = "logind_sample",
	})
-------------------------------------------------------------------------------	
    -- local uid = "nzhsoft"
    -- local secret = "11111111"
    -- local subid = skynet.call(gate, "lua", "login", uid, secret) --告诉msgserver，nzhsoft这个用户可以登陆
    -- skynet.error("lua login subid", subid)
        
    -- skynet.call(gate, "lua", "logout", uid, subid) --告诉msgserver，nzhsoft登出
        
    -- skynet.call(gate, "lua", "kick", uid, subid) --告诉msgserver，剔除nzhsoft连接
        
    -- skynet.call(gate, "lua", "close")   --关闭gate，也就是关掉监听套接字
	
end)
