require("struct.globle")
local skynet = require "skynet.manager"
local netpack = require "netpack"
local socket = require "socket"
local p_core=require "p.core"
local p_battle = require "battle.battle"
local battle_ctrl = require "battle.battle_ctrl"
local logstat = require "base.logstat"
local sharedata = require "sharedata"
local DEBUG = function (...) logstat.log_file2("battle.txt",...) end
local DEBUG_TABLE = function (table) logstat.log_file_r("battle.txt",table) end
local CMD = {}
local battle = p_battle.new()

--申请战斗
function CMD.init(agent,userId,agent2,userId2)
    logstat.log_day("battle","battle:init!")
    battle:init( agent,userId,agent2,userId2 )   
end

function CMD.war_ok(userid,status)
	DEBUG("user.battleroom:",userid,status)
    player = battle:get_player(userid)
    battle_ctrl.card_ok(battle,player,status)
end

function CMD.war_mov(userid,msg)
    player = battle:get_player(userid)
    battle_ctrl.war_mov(battle,player,msg)
end

function CMD.war_sacrifice(userid,msg)
    player = battle:get_player(userid)
    battle_ctrl.war_sacrifice(battle,player,msg)
end

function CMD.war_order(userid,msg)
    player = battle:get_player(userid)
    battle_ctrl.order_check(battle,player,msg)
end

function CMD.war_deploy(userid,msg)
    player = battle:get_player(userid)
    battle_ctrl.deploy_check(battle,player,msg)
end

function CMD.hand(userid,card_id,num)
    player = battle:get_player(userid)
	print("CMD.hand "..card_id..":"..num)
    battle_ctrl.hand(battle,player,tonumber(card_id),tonumber(num))
end

function CMD.heart_beat()
    DEBUG("heart_beat")
    print_r(battle)
    while 1 do
        battle_ctrl.update_turn(battle,-1)
        skynet.sleep(100)	-- exit after 10s
    end
end

skynet.start(function()
    print("run battleroom")
	print("agent:-----------------init begin-----------------------------------")
	_G.mpCards = sharedata.query "mpCards"
	_G.mpCmds = sharedata.query "mpCmds"
	print_r(_G.mpCmds[10001])
	_G.mpCards = sharedata.query "mpCards"
	_G.mpCmds = sharedata.query "mpCmds"

	_G.mpSkill = sharedata.query "mpSkill"
	
	print_r(_G.mpSkill)
	print_r("*************************************************")
	print("agent:-----------------init end------------------------------------")
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]		
		skynet.ret(skynet.pack(f(...)))
	end)
	print("run battleroom skynet.fork")
	skynet.fork(CMD.heart_beat,1)
end)
