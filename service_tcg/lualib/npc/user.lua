----------------------------------------------------------------------------------------
------------------------场外玩家-----------------------------------
----------------------------------------------------------------------------------------
local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local carddata = require "data.carddata"
local List = require "struct.List"
local usersql = require "npc.usersql"
local deckinfo = require "data.deckinfo"
deckinfo = deckinfo.inst()

require "struct.globle"

------------------------------------------------------------------------------
local DEBUG = function (...) logstat.log_file2("user.txt",...) end
local DEBUG_TABLE = function (table) logstat.log_file_r("user.txt",table) end
--------------------------------------------------------------------------------

local pload = protobufload.inst()

---------------------------------------------------------------------
local user = {}
local mt = { __index = user }


-- -- 普通卡
-- local common_cards = nil
-- -- 装备卡
-- local equip_cards = nil
-- -- 战斗普通卡
-- local battle_card
-- -- 战斗装备卡
-- local battle_cmd
-- -- 卡组
-- local deck
function user.new(o)
    o = o or {}   -- create object if user does not provide one
	setmetatable (o, mt)
	print_r(o)
	user.init(o)
	return o
end

function user.init(o)
-- user.name = account
-- user.userid = userid
-- 起始资金	起始经验	起始等级	起始天梯分	起始钻石	起始头像	起始套牌
-- money	exp	level	feats	gem	head	card

	o.money = 0
	o.exp = 0
	o.level = 0
	o.ranksocre = 0
	o.gem = 0
	o.head = 0

	o.awardkey = 4

	o.sex = 1
	o.school = 1
	o.vip = 1
	o.deck = {}
	o.equip_cards = {}
	o.common_cards = {}
end

function user.get_gold(u)
	return u.money
end

function user.add_gold(u,value)
	u.money = u.money+value
	user.send_user_info_ex(u)
end

function user.get_gem(u)
	return u.gem
end

function user.add_gem(u,value)
	u.gem = u.gem+value
	user.send_user_info_ex(u)
end

-- required int32 id = 1;						//卡组ID
-- required int32 option = 2;					//卡组操作
-- optional string name = 3;					//卡组名
-- optional equip_card equip_card_list = 4;	//装备卡列表
-- optional common_card common_card_list = 5;	//普通卡列表	
--创建新角色初始化套牌组
function user.add_card_by_deck(u,id)
	print("id:"..id)
	local card_id = nil
	local deck_me = {}
	local decktemp = deckinfo.get_deck_play_copy( id )
	if deckinfo==nil then
		print("deckinfo.get_deck_play_copy is nil")
	end	
	--print(decktemp)
	deck_me = {}
		
	for i=1, 3 do
		card_id = decktemp.equip[i].card_id
		
		if u.equip_cards[card_id]==nil then
			u.equip_cards[card_id] = 0
		end	
		u.equip_cards[card_id] =u.equip_cards[card_id]+1
		
		if deck_me[card_id]==nil then
			deck_me[card_id] = 0
		end	
		deck_me[card_id] = deck_me[card_id]+1		
				
	end
	
	for i=1, #decktemp.common do
		card_id = decktemp.common[i].card_id
		if u.common_cards[card_id]==nil then
			u.common_cards[card_id] = 0
		end
		u.common_cards[card_id] =u.common_cards[card_id]+1
		
		if deck_me[card_id]==nil then
			deck_me[card_id] = 0
		end	
		deck_me[card_id] = deck_me[card_id]+1
		
	end
	table.insert(u.deck,deck_me)
end

function user.add_card(u,card_id,num)
	--print("user.add_card:"..card_id..","..num)
	if card_id <100000 then
		if u.equip_cards[card_id]==nil then
			u.equip_cards[card_id] = 0
		end	
		if u.common_cards[card_id]~=nil then
			u.common_cards[card_id] = nil
		end		
		u.equip_cards[card_id] =u.equip_cards[card_id]+num		
	else
		if u.common_cards[card_id]==nil then
			u.common_cards[card_id] = 0
		end
		if u.equip_cards[card_id]~=nil then
			u.equip_cards[card_id] = nil
		end	
		u.common_cards[card_id] =u.common_cards[card_id]+num
	end
end

--离线处理
function user.quit(u)
	user.save_data(u)
end

--数据库读盘
function user.retore_data(u)
	DEBUG("user.retore_data:"..u.userid)
	user.restore_player_base_info(u)
	user.restore_player_data(u)
	user.restore_player_card_deck(u)
end

function user.restore_player_base_info(u)
	local ret = usersql.select_player_base_info(u)
end

function user.restore_player_data(u)
	local ret = usersql.select_player_data(u)
	print_r(ret[0])
end

function user.restore_player_card_deck(u)
	local ret = usersql.select_player_card_deck(u)
	print_r(ret[0])
end

--数据库存盘
function user.save_data(u)
	if u.userid== nil then
		return 
	end
	DEBUG("user.save_data:"..u.userid)
	usersql.update_player_base_info(u)
	usersql.update_player_card_deck(u)
	usersql.update_player_data(u)
end

function user.insert_new_user_data(u)
	usersql.insert_player_base_info(u)
	usersql.insert_player_data(u)
	usersql.insert_player_card_deck(u)
	usersql.insert_player_base_info(u)
end

--发送普通卡
function user.send_common_cards(u)
	local mList = {}
	local mCard
	for k,v in pairs(u.common_cards) do
    	mCard={cardid = k,number = v}	
		table.insert(mList,mCard)
	end		
	-- print("u.common_cards======================1")
	-- print_r({cards=mList})
	-- print("u.common_cards======================2")
	msg = pload.encode("game.common_cards",{cards=mList;})		
	skynet.call(u.agent, "lua", "send",2002,msg)	
end

--发送装备卡
function user.send_equip_cards(u)
	local mList = {}
	local mCard
	for k,v in pairs(u.equip_cards) do
    	mCard={cardid = k,number = v}	
		table.insert(mList,mCard)
	end	
	-- print_r({list=mList})
	msg = pload.encode("game.equip_cards",{cards=mList;})		
	skynet.call(u.agent, "lua", "send",2003,msg)	
end


-- message group_cards
-- {
	-- message group_card
	-- {
		-- required int32 cardid = 1;	//装备卡牌ID
		-- required int32 number = 2;	//装备卡牌数量
	-- }
	-- required int32 cards_id = 1;	//卡组ID
	-- repeated group_card cards = 2;	//卡组列表
	-- required string cards_name = 3;	//卡组名字	
-- }
--发送卡组
function user.send_group_cards(u)
	local mList = {}
	local mCard
	for k0,v0 in pairs(u.deck) do
		for k,v in pairs(v0) do
			mCard={cardid = k,number = v}	
			table.insert(mList,mCard)
		end
		--print_r({list=mList,cards_id= k0,cards_name = v0.name})
		msg = pload.encode("game.group_cards",{
		cards_id = k0;
		cards=mList;})
		skynet.call(u.agent, "lua", "send",2004,msg)
	end
end

function user.send_map_npc(u)
	u.map_npc = {1,2,3}	
	--local pload = protobufload.inst() 
	local map_npc = pload.encode("game.map_npc",{
    mtype = 1;
    list = u.map_npc
    })

    local msg = pload.decode("game.map_npc",map_npc)
    --print_r(msg)
	skynet.call(u.agent, "lua", "send",4020,map_npc)
end

--发送玩家信息
function user.send_user_info(user)
    if user.agent==nil then
		print("send_user_info user.agent is nil")	
	    return 0
	end
	--local pload = protobufload.inst() 
	local game_users = pload.encode("game.game_users",{
    userid = user.userid;   --角色名id
    level = user.level;     --角色等级
    sex = user.sex;         --角色性别	
    school = user.school;   --角色职业
    vip = user.vip;         --角色是否VIP
    name = user.name;	    --角色名称
    })

    local msg = pload.decode("game.game_users",game_users)
    --print_r(msg)
	--skynet.call(user.agent, "lua", "send",2001,game_users)
	user.send(2001,game_users)
end

function user.send_user_info_ex(user)
    if user.agent==nil then
		print("send_user_info_ex user.agent is nil")
	    return 0
	end

	local users_info = pload.encode("users.users_info",{
    userid = user.userid;
    money = user.money;
    exp = user.exp;
    level = user.level;
    ranksocre = user.ranksocre;
    gem = user.gem;
    head = user.head;
	awardkey = user.awardkey;
    })	
	local infos = {
    userid = user.userid;
    money = user.money;
    exp = user.exp;
    level = user.level;
    ranksocre = user.ranksocre;
    gem = user.gem;
    head = user.head;
	awardkey = user.awardkey;
    }
	--print_r(infos)
    local msg = pload.decode("users.users_info",users_info)
	--skynet.call(user.agent, "lua", "send",2009,users_info)
	--skynet.call(user.agent, "lua", "send",2009,users_info)
	user.send(2009,users_info)
end

-- message group_cards_result
-- {
	-- required int32 result = 1;
-- }
function user.group_cards_result(mResult)
	local infos = {
    result = mResult;
    }
	--print_r(infos)
    local msg = pload.decode("users.group_cards_result",infos)
	user.send(2006,users_info)
end

return user
