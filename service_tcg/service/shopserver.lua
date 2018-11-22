require "struct.globle"
local skynet = require "skynet.manager"
local netpack = require "netpack"
local socket = require "socket"
local p_core=require "p.core"
local shop_ctrl = require "shop.shop_ctrl"
local sharedata = require "sharedata"
local CMD = {}
local agentMap = {}
local userMap ={}
--玩家注册
function CMD.init_user(agent,userId)
	print("shopserver init_user:"..agent..","..userId)
    agentMap[userId] = agent
    if userMap[userId]==nil then
        userMap[userId] = {}
    end
	shop_ctrl.send_shop_info(agent,userId)	
end

function CMD.get_shop_info(id)
	return shop_ctrl.get_shop_info(id)
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
	--print("agent:-----------------init begin-----------------------------------")
	_G.data_shop = sharedata.query "data_shop"
	_G.data_market = sharedata.query "data_market"
	--print("agent:-----------------init end------------------------------------")	
	--注册战斗服
	skynet.name(".shopserver", skynet.self())	

end)
