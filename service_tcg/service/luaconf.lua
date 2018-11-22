require "struct.globle"
local sharedata = require "sharedata"
local skynet = require "skynet.manager"
local netpack = require "netpack"
local socket = require "socket"
local p_core=require "p.core"
local carddata = require "data.carddata"
local userinfo =  require "data.userinfo"
local deckinfo = require "data.deckinfo"
local shopinfo = require "data.shopinfo"
local skilldata = require "data.skilldata"
CMD = {}

local function init_conf()
	local mpCards,mpCmds = carddata.initload()
	sharedata.new("mpCards", mpCards)
	sharedata.new("mpCmds", mpCmds)
	print_r(mpCmds[10001])	
	local deckplay,decknpc = deckinfo.initload()
	sharedata.new("deckplay", deckplay)
	sharedata.new("decknpc", decknpc)	
	local data_userinfo,mpBase = userinfo.initload()
	sharedata.new("data_userinfo", data_userinfo)
	sharedata.new("mpBase", mpBase)		
	
	local data_shop,data_market = shopinfo.initload()
	sharedata.new("data_shop", data_shop)
	sharedata.new("data_market", data_market)	
	
	local mpSkill = skilldata.initload()
	sharedata.new("mpSkill", mpSkill)
	
end

--更新策划表
function CMD.renew()

	local mpCards,mpCmds = carddata.initload()
	skynet.sleep(200)	-- sleep 2s
	skynet.error("luaconf update mpCards mpCmds..")
	sharedata.update("mpCards", mpCards)
	sharedata.update("mpCmds", mpCmds)
	print_r(mpCmds[10001])
	
	local deckplay,decknpc = deckinfo.initload()
	skynet.sleep(200)	-- sleep 2s	
	skynet.error("luaconf update deckplay decknpc..")
	sharedata.update("deckplay", deckplay)
	sharedata.update("decknpc", decknpc)	
	
	local data_userinfo,mpBase = userinfo.initload()
	skynet.sleep(200)	-- sleep 2s
	skynet.error("luaconf update data_userinfo mpBase..")
	sharedata.update("data_userinfo", data_userinfo)
	sharedata.update("mpBase", mpBase)		
	skynet.sleep(200)	-- sleep 2s
	local data_shop,data_market = shopinfo.initload()
	sharedata.update("data_shop", data_shop)	
	sharedata.update("data_market", data_market)	
	
	skynet.sleep(200)	-- sleep 2s
	local mpSkill = skilldata.initload()
	sharedata.update("mpSkill", mpSkill)	
	
end


skynet.start(function()
		skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
        if f then 		
			skynet.ret(skynet.pack(f(...)))
		 else
           error(string.format("[luaconfig] has not find the command: %s", cmd))
        end
	end)
	--注册战斗服
	skynet.name(".luaconfig", skynet.self())	
    init_conf()
end)