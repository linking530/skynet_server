require "struct.globle"
local skynet = require "skynet.manager"
local netpack = require "netpack"
local socket = require "socket"
local p_core=require "p.core"

local CMD = {}
local agentMap = {}
local userArr = {}
--玩家注册
function CMD.init_user(agent,userId)
    agentMap[userId] = agent
    if userMap[userId]==nil then
        userMap[userId] = {}
    end
end

--玩家退出注销
function CMD.exit_user(userId)
    agentMap[userId] = nil
    userMap[userId] = nil
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		
		skynet.ret(skynet.pack(f(...)))
	end)
	--注册战斗服
	skynet.name(".rankserver", skynet.self())	

end)
