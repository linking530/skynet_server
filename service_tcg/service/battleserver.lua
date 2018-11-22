require "struct.globle"
local skynet = require "skynet.manager"
local netpack = require "netpack"
local socket = require "socket"
local p_core=require "p.core"

local CMD = {}
local agentMap = {}
local userArr = {}
local battleRooms= {}
--申请战斗
function CMD.applyBattle(agent,userId)
    print("applyBattl userId："..userId)
    agentMap[userId] = agent
	local battleroom = skynet.newservice("battleroom")
	    print("battleroom init begin")
    skynet.call(battleroom, "lua", "init",agent,userId,0,1)
        print("battleroom init end")
	table.insert(battleRooms, battleroom)
    skynet.call(agent, "lua", "set_battleroom",battleroom)
end

function CMD.endBattle(agent,userId)
    print("applyBattl userId："..userId)
    agentMap[userId] = agent
	local battleroom = skynet.newservice("battleroom")
	    print("battleroom init begin")
    skynet.call(battleroom, "lua", "init",agent,userId,0,1)
        print("battleroom init end")
	table.insert(battleRooms, battleroom)
    skynet.call(agent, "lua", "set_battleroom",battleroom)	
end



skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		
		skynet.ret(skynet.pack(f(...)))
	end)
	--注册战斗服
	skynet.name(".battleserver", skynet.self())	

end)
