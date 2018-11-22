local base_type =require "struct.base_type"
--local protobufload = require "protobufload"
local p_core = require "p.core"
local skynet = require "skynet.manager"
local logstat = require "base.logstat"
local handler = require "agent.handler"

local userinfo =  require "data.userinfo"
userinfo = userinfo.inst()

local deckinfo = require "data.deckinfo"
deckinfo = deckinfo.inst()

local usersql = require "npc.usersql"

require "struct.class"
require "struct.globle"
------------------------------------------------------------------------------
local DEBUG = function (...) logstat.log_file2("user.txt",...) end
local DEBUG_TABLE = function (table) logstat.log_file_r("user.txt",table) end
--------------------------------------------------------------------------------
handler = handler.new ()
local pload = protobufload.inst() 
user = nil
local CMD = {}

function CMD.add_gold(msg)
	user.add_gold(user,tonumber(msg[2]))
end

function CMD.add_gem(msg)
	user.add_gem(user,tonumber(msg[2]))
end

function CMD.hand(msg)
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "hand",user.userid,tonumber(msg[2]),tonumber(msg[3]) )
	end
end

function CMD.add_card(msg)
	user.add_card(user,tonumber(msg[2]),tonumber(msg[3]))
	user.send_common_cards(user)
	user.send_equip_cards(user)
end

function CMD.call(msg)
	local m_G = _G
	_G.user = user
	_G.skilldata = require "data.skilldata"
	--print_r(_G.mpSkill)
	local str = "return "..msg[2]
	print("str:"..str)
	local f2 = load(str)
	local re = f2()
	print_r(re)
	_G = m_G
end

function handler.init(u)
    user = u
end


function handler.AnalyseMsg(messageId,msg)
	if messageId == 7010 then
		handler.user_cmd(msg)
	 end
end

-- message user_cmd
-- {
	-- required int32 user_id = 1;
	-- required string msg = 2;	    //名字
-- }
function handler.user_cmd(msg)
	local cmd_str = msg.msg
	local tmp_cmd
	tmp_cmd = explode(cmd_str," ")
	print("----------------------------------------------")
	print_r(tmp_cmd)
	print("----------------------------------------------")
	local f = CMD[tmp_cmd[1]]
	f(tmp_cmd)
end


return handler