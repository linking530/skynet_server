local base_type =require "struct.base_type"
local protobufload = require "protobufload"
local p_core = require "p.core"
local skynet = require "skynet.manager"
local logstat = require "base.logstat"
local handler = require "agent.handler"
require "struct.class"
require "struct.globle"

------------------------------------------------------------------------------
local DEBUG = function (...) logstat.log_file2("card_handler.txt",...) end
local DEBUG_TABLE = function (table) logstat.log_file_r("card_handler.txt",table) end
--------------------------------------------------------------------------------

handler = handler.new ()
local pload = protobufload.inst() 
local user

function handler.init(u)
    user = u
end

--//option 1创建组牌 2组牌 3删除组牌 4修改组牌名
--message group_cards_option
--{
--	message equip_card
--	{
--		required int32 cardid = 1;	//装备卡牌ID
--		required int32 number = 2;	//装备卡牌数量
--	}
--	message common_card
--	{
--		required int32 cardid = 1;	//普通卡牌ID
--		required int32 number = 2;	//普通卡牌数量
--	}	
--	required int32 id = 1;						//卡组ID
--	required int32 option = 2;					//卡组操作
--	required string name = 3;					//卡组名
--	repeated equip_card equip_card_list = 4;	//装备卡列表
--	repeated common_card common_card_list = 5;	//普通卡列表	
--}
--CREATE_DECK = 1
--UPDATE_DECK = 2
--DEL_DECK = 3
--MODIFY_DECK = 4

local function modify_deck(msg)
    local deck_me ={}

	for i=1, #msg.equip_card_list do
		cardid = msg.equip_card_list[i].cardid	
		if deck_me[cardid]==nil then
			deck_me[cardid] = 0
		end
		deck_me[cardid] =deck_me[cardid]+1		
	end
	
	for i=1, #msg.common_card_list do
		cardid = msg.common_card_list[i].cardid	
		if deck_me[cardid]==nil then
			deck_me[cardid] = 0
		end
		deck_me[cardid] =msg.common_card_list[i].number		
	end
	--deck_me.name = msg.name
	user.deck[msg.id] = deck_me
	DEBUG(deck_me)
end




function handler.AnalyseMsg(messageId,msg)
	if messageId == 2005 then--登录
        modify_deck(msg)
	-- elseif messageId == 3005 then
	    -- war_mov(msg)
	end
end




return handler