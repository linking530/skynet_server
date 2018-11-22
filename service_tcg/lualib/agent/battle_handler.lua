local base_type =require "struct.base_type"
local protobufload = require "protobufload"
local p_core = require "p.core"
local skynet = require "skynet.manager"
local logstat = require "base.logstat"
local handler = require "agent.handler"
require "struct.class"
require "struct.globle"
local DEBUG = function (...) logstat.log_file2("battle.txt",...) end
local DEBUG_TABLE = function (table) logstat.log_file_r("battle.txt",table) end
handler = handler.new ()
local pload = protobufload.inst()
local user
--战斗普通卡
local battle_card
--战斗装备卡
local battle_cmd
--普通卡
local common_cards
--装备卡
local equip_cards
--卡组
local group_cards

function handler.init(u)
    user = u
end

local function war_option(war_option_msg)

	--print_r(war_option_msg)
	--2	war apply type    // 寻找对手,开始战斗 type：1匹配对战，2天梯对战
	if war_option_msg.option == 2 then
	    local battleserver = skynet.localname(".battleserver")	
	    print("user.agent:"..user.agent.."user.userid:"..user.userid)	    
	    skynet.call( battleserver, "lua", "applyBattle",user.agent,user.userid)
	--3	war withdraw type // 取消匹配对战     type：1为取消匹配对战，2为取消天梯对战
	elseif war_option_msg.option == 3 then
	
	--4	war exchange  // 更换手牌
	elseif war_option_msg.option == 4 then
	
	--5	war giveup    // 放弃,认输
	elseif war_option_msg.option == 5 then
	
	--6 war turnover //回合结束
	elseif war_option_msg.option == 6 then
	
	--7 war ok 操作结束,进入下一阶段
	elseif war_option_msg.option == 7 then
	    DEBUG("user.battleroom:",user.battleroom)
	    if user.battleroom~=nil then
	        skynet.call( user.battleroom, "lua", "war_ok",user.userid,war_option_msg.value)
	    end
    --npc战斗	
	end if war_option_msg.option == 8 then
	    local battleserver = skynet.localname(".battleserver")	
	    skynet.call( battleserver, "lua", "applyBattle",user.agent,user.userid)
	    print("user.agent:"..user.agent.."user.number:"..user.userid)	
	end

end

local function war_mov(msg)
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_mov",user.userid,msg)
	end
end

local function war_sacrifice(msg)
	print("battle_handler.war_sacrifice")
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_sacrifice",user.userid,msg)
	end
end

local function war_order(msg)
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_order",user.userid,msg)
	end
end

local function war_deploy(msg)
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_deploy",user.userid,msg)
	end
end

function handler.AnalyseMsg(messageId,msg)
	if messageId == 3000 then--登录
        war_option(msg)
	elseif  messageId == 3001 then
		war_order(msg)
	elseif  messageId == 3002 then
		war_sacrifice(msg)
	elseif  messageId == 3003 then
		war_deploy(msg)
	elseif messageId == 3005 then
	    war_mov(msg)		
	end
end

function handler.load_card()
    user.battle_card = battle_card
    user.battle_cmd = battle_cmd
    battle_cmd = {10001,10002,10003,}
    battle_card = {
                {100001,100},
                }
    
end


return handler