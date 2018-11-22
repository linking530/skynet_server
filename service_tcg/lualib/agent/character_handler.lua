local base_type =require "struct.base_type"
local protobufload = require "protobufload"
local p_core = require "p.core"
local skynet = require "skynet.manager"
local logstat = require "base.logstat"
local handler = require "agent.handler"
local define_public = require "define.define_public"

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
local user = nil


function handler.init(u)
    user = u
end

function handler.login(login_enter)
	-- print("handler.login------------------------------")
	-- print(_G)
	-- print_r(_G.mpCmds[10001])
	-- print_r(_G.decknpc[1])	
	-- print("handler.login------------------------------")
	print_r("handler.login user.agent 2:"..user.agent)
    local ret,sql
    local mysqlserver = skynet.localname(".mysqlserver")		
	local sql = "select * from name_list where player_name=\""..login_enter.account.."\""
	logstat.log_day("sql","sql:"..sql.."\n")
	local ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]== nil then
		sql = "INSERT INTO name_list (player_name, player_account) VALUES ('"..login_enter.account.."', '"..login_enter.account.."')"
		ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
		if ret then
			sql = "select * from name_list where player_name=\""..login_enter.account.."\""
			ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))
			handler.createuser(login_enter.account,ret[1]["uid"])
			user.insert_new_user_data(user)
		end
		print("create new user!!!")
	else
		print("has user exit!!!!")
	    sql = "select * from name_list where player_name=\""..login_enter.account.."\""
		ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))
		user.name = login_enter.account
		user.userid = ret[1]["uid"]
		user.retore_data(user) 
		print("role"..ret[1]["uid"]..ret[1]["player_name"]..ret[1]["player_account"])
	end
    --如果在线踢人下线
    print("login_enter.account:"..login_enter.account)
	handler.send_user_info(user)
	handler.send_user_info_ex(user)

	local pload = protobufload.inst()
	local result = pload.encode("login.login_result",{id = 1001})--登录成功	
	--skynet.call(user.agent, "lua", "send",1002,result)
	user.send(1002,result)
    user.send_common_cards(user)
    user.send_equip_cards(user)
    user.send_group_cards(user)
	user.send_map_npc(user)

    local shopserver = skynet.localname(".shopserver")			
	skynet.call( shopserver, "lua", "init_user",user.agent,user.userid)
end




-- message buy_item
-- {
	-- required int32 buy_type = 1 ;			//消耗类型
	-- required int32 currency_type = 2 ;	//道具id
	-- required int32 item_id = 3 ;			//数量
	-- required int32 item_num = 4 ;		//数量
-- }
--//购买类型：1卡包  2卡背  3单卡市场    消耗类型：1金币 2钻石
function handler.buy_item(msg)
	print("handler.buy_item")
	if msg.buy_type==1 then
	
	elseif msg.buy_type==2 then
	
	elseif msg.buy_type == 3 then		
		handler.buy_card(msg)
	end
	
end

function handler.buy_card(msg)
	print("handler.buy_card")	
    local shopserver = skynet.localname(".shopserver")			
	local card_info = skynet.call( shopserver, "lua", "get_shop_info",msg.item_id)
	local sum = 0
	if msg.currency_type==define_public.GOLD then
		print("define_public.GOLD")
		sum = msg.item_num* card_info.buy
		if user.money< sum then return end
		user.money = user.money - sum
	end
	if msg.currency_type==define_public.GEM then
		sum = msg.item_num* card_info.buy
		if user.gem< sum then return end
		user.gem = user.gem - sum
	end	
	
	user.add_card(user,msg.item_id,msg.item_num)	
	if msg.item_id <=100000 then
		user.send_equip_cards(user)	
	else 
		user.send_common_cards(user)
	end
	handler.send_user_info_ex(user)
end

-- message user_cmd
-- {
	-- required int32 user_id = 1;
	-- required string msg = 2;	    //名字
-- }
function handler.user_cmd(msg)
	local cmd_str = msg.msg
	

end

--创建角色
function handler.createuser(account,userid)
	local mp = userinfo.getMap(10000)
	print_r(mp)
    user.name = account
    user.userid = userid
-- 起始资金	起始经验	起始等级	起始天梯分	起始钻石	起始头像	起始套牌
-- money	exp	level	feats	gem	head	card

    user.money = mp.money
    user.exp = mp.exp
    user.level = mp.level
    user.ranksocre = mp.feats
    user.gem = mp.gem
    user.head = mp.head
	user.map_npc = {1,2,3}	
	user.awardkey = 4
	handler.initcard(mp.card)
	
    user.sex = 1
    user.school = 1
    user.vip = 1
	
end

--初始化套牌组
function handler.initcard(card)
	--local deck = deckinfo.getdeckplay( id )
	user.add_card_by_deck(user,card)
end

--发送玩家信息
function handler.send_user_info(user)
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
    print_r(msg)
	--skynet.call(user.agent, "lua", "send",2001,game_users)
	user.send(2001,game_users)
end


function handler.send_user_info_ex(user)
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
	print_r(infos)
    local msg = pload.decode("users.users_info",users_info)
	--skynet.call(user.agent, "lua", "send",2009,users_info)
	--skynet.call(user.agent, "lua", "send",2009,users_info)
	user.send(2009,users_info)
end


function handler.AnalyseMsg(messageId,msg)
	if messageId == 1004 then--登录
		handler.login(msg)
	elseif messageId == 1010 then
		handler.user_cmd(msg)
	elseif messageId == 1011 then
		handler.buy_item(msg)
	 end
end

return handler