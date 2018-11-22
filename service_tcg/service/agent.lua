local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local character_handler = require "agent.character_handler"
local card_handler = require "agent.card_handler"
local battle_handler = require "agent.battle_handler"
local cmd_handler =  require "agent.cmd_handler"
local user = require "npc.user"
local sharedata = require "sharedata"
local carddata = require "data.carddata"
require "struct.globle"
local pload = protobufload.inst()
local gamed
local CMD = {}
local client_fd
local m_user = user.new()
-----------------------------------------------------------------------------
character_handler.init(m_user)
card_handler.init(m_user)
battle_handler.init(m_user)
cmd_handler.init(m_user)
------------------------------------------------------------------------------
local function kick_self ()
	skynet.call (gamed, "lua", "kick", skynet.self (), client_fd)
end

local function xfs_send(v)
	-- data = p_core.unpack(v)
	-- print("[LOG]",os.date("%m-%d-%Y %X", skynet.time()),"send ok",data.v,data.p)
	socket.write(client_fd, netpack.pack(v))
end

function m_user.send(msg_id,msg)
    --print("CMD SEND:"..msg_id)
	local v
    if msg~=nil then
        v = p_core.pack(1,msg_id,msg)
    end
	socket.write(m_user.client_fd, netpack.pack(v))
end

local function login(msg)
	result = character_handler.login(msg,client_fd,skynet.self())
    xfs_send(p_core.pack(1,1002,result))
end

function unpackMessage(message)
    local version,messageId,msg = string.unpack(">hiz",message)
    return version,messageId,msg
end

local function AnalyseMsg(messageId,msg)
    local decode_msg	
    if messageId == 1002 then
        decode_msg = pload.decode("login.game_result",msg)
    elseif messageId == 1004 then
        decode_msg = pload.decode("login.login_enter",msg)
	elseif messageId == 7010 then
     decode_msg = pload.decode("game.user_cmd",msg)		
	elseif messageId == 1011 then
     decode_msg = pload.decode("game.buy_item",msg)	
    elseif messageId ==2000 then
     decode_msg = pload.decode("game.game_result",msg)		
    elseif messageId == 2001	then
     decode_msg = pload.decode("game.game_users",msg)		
    elseif messageId == 2002	then
     decode_msg = pload.decode("game.common_cards",msg)		
    elseif messageId == 2003	then
     decode_msg = pload.decode("game.equip_cards",msg)		
    elseif messageId == 2004	then
     decode_msg = pload.decode("game.group_cards",msg)		
    elseif messageId == 2005	then
     decode_msg = pload.decode("game.group_cards_option",msg)		
    elseif messageId == 2006	then
     decode_msg = pload.decode("game.group_cards_result",msg)			
    elseif messageId == 2007	then
     decode_msg = pload.decode("game.npc_map",msg)	
    elseif messageId == 3000	then
     decode_msg = pload.decode("game.war_option",msg)		
    elseif messageId == 3001	then
     decode_msg = pload.decode("game.war_order",msg)		
    elseif messageId == 3002	then
     decode_msg = pload.decode("game.war_sacrifice",msg)		
    elseif messageId == 3004	then
     decode_msg = pload.decode("game.war_deploy",msg)		
    elseif messageId == 3005	then
     decode_msg = pload.decode("game.war_mov",msg)			
    elseif messageId == 4001	then
     decode_msg = pload.decode("game.cur_stutas",msg)		
    elseif messageId == 4002	then
     decode_msg = pload.decode("game.front_begin",msg)		
    elseif messageId == 4003	then
     decode_msg = pload.decode("game.hands",msg)		
    elseif messageId == 4004	then
     decode_msg = pload.decode("game.change_hand",msg)		
    elseif messageId == 4005	then
     decode_msg = pload.decode("game.cmds",msg)		
    elseif messageId == 4006	then
     decode_msg = pload.decode("game.crds",msg)		
    elseif messageId == 4007	then
     decode_msg = pload.decode("game.fronts",msg)		
    elseif messageId == 4008	then
     decode_msg = pload.decode("game.change_fronts",msg)
    elseif messageId == 4009	then
     decode_msg = pload.decode("game.diss",msg)	
    elseif messageId == 4010	then
     decode_msg = pload.decode("game.change_diss",msg)
    elseif messageId == 4011	then
     decode_msg = pload.decode("game.res",msg)
    end
    
	if (messageId >= 1000) and (messageId<2000) then--卡牌信息
        character_handler.AnalyseMsg(messageId,decode_msg)
	elseif (messageId >= 2000) and (messageId<3000) then--卡牌信息
        card_handler.AnalyseMsg(messageId,decode_msg)
	elseif (messageId >= 3000) and (messageId<4000) then--战斗信息
        battle_handler.AnalyseMsg(messageId,decode_msg)
	elseif (messageId >= 7000) and (messageId<8000) then--战斗信息
        cmd_handler.AnalyseMsg(messageId,decode_msg)	
	end    
    
    print("messageId:"..messageId)
    --print_r(decode_msg)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return skynet.tostring(msg,sz)
	end,

	dispatch = function (session, address, text)
		--data = p.unpack(text)
		print("address:"..address)
		local result,ok
		local version,messageId,msg=unpackMessage(text)
		print("version:"..version.." messageId:"..messageId)
        AnalyseMsg( messageId,msg )
	end
}

skynet.register_protocol {
	name = "xfs",
	id = 12,
	pack = skynet.pack,
	unpack = skynet.unpack,
	dispatch = function (session, address, text)
		print("[LOG]",os.date("%m-%d-%Y %X", skynet.starttime()),text,skynet.address(address))
		--xfs_send(p.pack(1,0,"Welcome to skynet\n"))
		--xfs_send(p.pack(1,0,os.date("程序开始运行于 %Y-%m-%d %X \n", skynet.starttime())))
		skynet.retpack(text)
	end
}

function CMD.set_battleroom(value)
    m_user.battleroom = value
end

function CMD.send(msg_id,msg)
    --print("CMD SEND:"..msg_id)
    if msg~=nil then
        xfs_send(p_core.pack(1,msg_id,msg))
    end
end

function CMD.start(gate , fd,v_gamed)
	client_fd = fd
	m_user.client_fd = fd
	print("client_fd:"..client_fd)
	gamed = f_gamed
	m_user.client_fd = client_fd
	m_user.agent = skynet.self()
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.close_agent()
	user.quit(m_user)
end

skynet.start(function()
	--print("agent:-----------------init begin-----------------------------------")
	_G.mpCards = sharedata.query "mpCards"
	_G.mpCmds = sharedata.query "mpCmds"
	--print_r(_G.mpCmds[10001])
	_G.deckplay = sharedata.query "deckplay"
	_G.decknpc = sharedata.query "decknpc"
	--print_r(_G.deckplay[1])
	_G.data_userinfo = sharedata.query "data_userinfo"
	_G.mpBase = sharedata.query "mpBase"
	
	_G.mpSkill = sharedata.query "mpSkill"	
	--print("agent:-----------------init end------------------------------------")
	skynet.dispatch("lua", function(_,_, command, ...)
	    print("agent_command:"..command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
