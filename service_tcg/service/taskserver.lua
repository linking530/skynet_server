require "struct.globle"
local skynet = require "skynet.manager"
local netpack = require "netpack"
local socket = require "socket"
local p_core=require "p.core"

local CMD = {}
local userMap= {}

--玩家注册
function CMD.init_user(agent,userId)
    userMap[userId] = {"agent":agent,"userId":userId}
end

--玩家退出注销
function CMD.exit_user(userId)
    userMap[userId] = nil
end


skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		
		skynet.ret(skynet.pack(f(...)))
	end)
	--注册战斗服
	skynet.name(".taskserver", skynet.self())	

end)
