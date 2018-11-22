local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local carddata = require "data.carddata"
local card = require "npc.card"
local List = require "struct.List"
local battle_send = require "battle.battle_send"
local define_battle = require "define.define_battle"
require "struct.globle"
------------------------------------------------------------------------------
local DEBUG_MOVE = function (...) logstat.log_file2("move.txt",...) end
local DEBUG_MOVE_TABLE = function (table) logstat.log_file_r("move.txt",table) end
--------------------------------------------------------------------------------

local pload = protobufload.inst()
carddata = carddata.inst()
---------------------------------------------------------------------
local player = {}
local mt = { __index = player }

function player.new(o)
    o = o or {}   -- create object if user does not provide one
	setmetatable (o, mt)
	print_r(o)
	return o
end


function player:set_battle(value)
    self.battle = value
end

function player:get_battle(m_player)
    return self.battle
end

function player:get_userid()
    --print("self.userid:"..self.userid)
    return self.userid
end

function player:get_number()
    return self.userid
end

function player:get_agent()
    return self.agent
end

function player:init (agent,userid)
    print("init agent:("..agent..") ("..userid..")")
    self.agent = agent
    self.userid = userid
-- mrc:最大资源 int
-- rc:当前资源 int
-- mhp:最大血量 int
-- hp:当前血量 int
-- crd:({}) 牌库
-- std:堆叠区
-- had:({})                     10张手牌
-- dis:({}) 丢弃牌
-- cmd:({}) 3个指挥官ID
    self.mrc = 10
    self.rc = 10
    self.mhp = 300
    self.hp = 500

    self.hand = {}
    self.cmd = {}
    self.std = {}
    self.dis = {}
    self.crd = {}
	self.dep = {}
	self.stk = {}
	self.ops = {}
end

function player:set_ops(m_key,m_value)
	self.ops[m_key] = m_value
end

function player:get_ops()
	return self.ops[m_key]
end

function player:init_hand()
    local i,mCard
    for i=1,3,1 do
        mCard = self:pick_up()
        if mCard~=nil then
            table.insert(self.hand,mCard)
        end
    end
end

--从牌库抓牌
function player:pick_up()
    local mCard = table.remove(self.crd,#self.crd)
    return mCard
end

function player:new_card(card_id)
	local mCard = card.new(self.battle,self,card_id)
	return mCard
end

function player:init_crd( )
    local i,j,j_end
    local temp,mCard

    for i = 1,100,1 do
        if carddata.get_obj(i)~= nil then
            j_end = math.random(1,5)
            for j = 1,j_end,1 do
                mCard = card.new(self.battle,self,100001)
                table.insert(self.crd,mCard)
            end
        end
    end

    --洗牌
    for i = 1,50,1 do
        j = math.random(1,#self.crd)
        temp = self.crd[j]
        self.crd[j] = self.crd[1]
        self.crd[1] = temp
    end
    DEBUG_MOVE_TABLE({"init_crd \n",self.crd})	
end
---------------------------------------------------------------------------------------------------------------
function player:init_cmd(value)
    local mCard
    for i = 1,3,1 do
        mCard = card.new(self.battle,self,10001)
        mCard:set_war(self.battle)
        mCard:set_player(self)
        table.insert(self.cmd,mCard)
    end
    DEBUG_MOVE_TABLE({"init_cmd \n",self.cmd})	
end


function player:get_cmds( )
	return self.cmd
end

function player:set_cmds( value)
    self.cmd = value
    i[1].pos = 1
    i[2].pos = 2
    i[3].pos = 3
end

function player:get_cmd(pos)
	if pos>3 then return 0 end
	return self.cmd[pos]
end

---------------------------------------------------------------------------------------------------------------
--当前血量
function player:set_hp(value)
    self.hp = value
    battle_send.res(self.battle,self.userid,self.mhp,self.hp,self.mrc,self.rc)    
end

function player:get_hp()
    return self.hp
end

--最大血量
function player:set_mhp(value)
    self.mhp = value
    battle_send.res(self.battle,self.userid,self.mhp,self.hp,self.mrc,self.rc)  
end

function player:get_mhp()
    return self.mhp
end

--当前资源
function player:set_rc(value)
    self.rc = value
	print("player:set_rc:"..self.rc )
    battle_send.res(self.battle,self.userid,self.mhp,self.hp,self.mrc,self.rc)      
end

function player:get_rc()
    return self.rc
end

--最大资源
function player:set_mrc(value)
    self.mrc = value  
	print("player:set_mrc:".. self.mrc)
    battle_send.res(self.battle,self.userid,self.mhp,self.hp,self.mrc,self.rc)      
end

function player:get_mrc()
    return self.mrc
end

function player:add_mrc(value)
    self.mrc = self.mrc+value
end
-------------------------------------deploy----------------------------------------------------------
function player:get_deploy(pos)
	return self.dep[pos]
end

function player:set_deploy(pos,  skillStack)
    self.dep[pos] = skillStack;
end

function player:add_deploy( id,  skillStack)
	table.insert(self.dep,skillStack)
end

function player:del_deploy( id,  pos)
	table.remove(self.dep,pos)
end

function player:get_deploy_size( id)
    return #self.dep
end

function player:get_deploy_max( id)
	local max_size = #self.dep
	return self.dep[max_size]
end

-- 部署技能
function player:get_mpdep( )
    return self.dep
end

function player:set_mpdep( tmp)
    self.dep = tmp
end
----------- std:堆叠区-----------------------------------------------------------
--堆叠区
function player:get_stds( id)
    return self.std
end

function player:set_stds( tmp)
    self.std = tmp
end

function player:get_std( key)
    return self.std[key]
end

function player:set_std( key, i)
    self.std[key] = i
end

function player:add_std(key, i)
	if self.std[key]==nil then
		self.std[key] = {}
	end
	table.insert(self.std[key],i)
end

function player:del_std(key, pos)
	if self.std[key]~=nil then
		table.remove(self.std[key],pos)
	end
	
end
---------------------------------------------------------------------

-----------------------------------------------------------------------

function player:get_mpstk()
	return self.stk
end

function player:set_mpstk( tmp)
	self.stk = tmp
end

function player:get_stack( pos)
	return self.stk[pos]
end

function player:add_stack(skillStack)
	table.insert(self.stk,skillStack)
end

function player:del_stack(pos)
	table.remove(self.stk,pos)
end

function player:get_stack_size()
	return #self.stk
end
------------------------------------------------------------------------------------------------------
--牌库
function player:set_crds(value)
    self.crd = value
end

--获得一张牌库牌
function player:get_crds()
    return self.crd
end

--==================牌库========================
function player:get_crd( pos)
    return self.crd[pos]
end

function player:get_crds_size( )
    return #self.crd
end

function player:del_from_crds( pos)
	table.remove (self.crd, pos)
 end

function player:del_crds( id,  card)
	local tmps,i,size,oid
    tmps = self.crd
    oid = card.oid
    size = sizeof(tmps)
	for i=1,size do
        if tmps[i]:get_oid()==oid then
			card = tmps[i]
			table.remove (self.crd, i)
            --send_user(war->get_send_users(),"%d%d%c", 0x2014, id, war->get_crds_size(id));   
			self:send_crds()			
            return card
        end
    end
    --send_user(war->get_send_users(),"%d%d%c", 0x2014, id, war->get_crds_size(id));    
	self:send_crds()
    if self.battle:get_crds_size() == 0 then
		self.battle:set_winner(self.battle:get_fighter(self.userid ))
	end
    return 0
end

function  player:add_to_crds( card)
		table.insert(self.crd,card)
		card:set_uid(self.userid )
--send_user(this_object()->get_send_users(),"%d%d%c%d%c%c", 0x2014, id, this_object()->get_crds_size(id),card->cid,card->postype,card->pos+1);         
        card:set_postype(define_battle.AREA_PAIKU)
		card.pos = #self.crd
		self:send_crds()
end

function  player:add_to_crds2( card)
    local  size,rand,obj

	table.insert(self.crd,card)
	size = #self.crd
	rand = math.random(size);
	obj = self.crd[size]
	self.crd[size] = self.crd[rand]
	self.crd[rand] = self.crd[size]		
	card:set_uid(self.userid )
--send_user(this_object()->get_send_users(),"%d%d%c%d%c%c", 0x2014, id, this_object()->get_crds_size(id),card->cid,card->postype,card->pos+1);         
	card:set_postype(define_battle.AREA_PAIKU)
	card.pos = rand;
    self:send_crds()
end

function  player:get_top_crd( )
    local rnd, sz,card
	sz = self:get_crds_size()
    if  sz==0 then
        return 0
	end
    card = self:get_crd( sz)
    return card
end

function  player:pick_card( id)
    local rnd, sz,card
	sz = self:get_crds_size()
    if  sz==0 then
        return 0
	end
    card = self:get_crd( sz)
    self:del_from_crds( sz)
    -- SKILL_RULE->check_condition_skill(me,TRIGGER_49,card->uid);	
    -- SKILL_RULE->check_condition_skill(me,TRIGGER_50,me->get_fighter(card->uid));	
    -- SKILL_RULE->check_condition_skill(me,TRIGGER_51,0);
    return card;
end

function player:pick_card2( )
    local rnd, sz, card
	sz = self:get_crds_size()
    if  sz==0 then
        return 0
	end
    rnd = math.random(sz)
    card = me:get_crd( rnd)
    me:del_from_crds( rnd)
    return card
end

function player:xipai()
    local  index,value,length,median 
    length = #self.crd

   -- /* 发牌的时候对于已经分配的数据不再修改 */  
	for index=1,length do
        value = index + math.random(100) % (length - index)     
        median = self.crd[index]
        self.crd[index] = self.crd[value]
        self.crd[value] = median
    end
end

---------------------------------end牌库---------------------------------------------------------------------------------------------
--手牌
function player:set_hands(value)
    self.hand = value
end

function player:get_hands()
    return self.hand
end

function player:set_hand(pos,value)
    self.hand = value
end

function player:get_hnd(pos)
	--print_r(self.hand)
    return self.hand[pos]
end

function player:get_hnds()
    return self.hand
end

function player:del_from_hnds( pos)
	print("player:del_from_hnds:"..pos)	
    if pos>table.getn(self.hand) then
		print("pos>table.getn(self.hand)",pos,table.getn(self.hand))
		print_r(self.hand)		
        return 
    end
	local card = self.hand[pos]
	table.remove(self.hand, pos)
	self:send_change_hand(self.userid,card,pos,2,0,0)	
    for i = 1,table.getn(self.hand),1 do
		card = self.hand[i]
		card:set_pos(i)
    end
end

function player:pick_card()
    card = table.remove(self.crd)
    return card
end

function player:add_to_hnds( card)
	DEBUG_MOVE("add_to_hnds:"..card:get_id())	
	table.insert(self.hand, card)	
	pos = table.getn(self.hand)
	self:send_change_hand(self.userid,card,pos,1,card.postype,card.pos)	
    for i = 1,table.getn(self.hand),1 do
		card = self.hand[i]
		card:set_pos(i)
		card.postype = define_battle.AREA_SHOUPAI
    end
end

function player:get_hnds_size()
	return table.getn(self.hand)
end

-- dis:墓地
function player:set_dis(value)
    self.dis = value
end

function player:get_dis()
    return self.dis
end

function player:del_from_diss( pos)
	local card = self.dis[pos]
	table.remove(self.dis, pos)	
	self:send_change_diss(card:get_id(),table.getn(self.dis),2)	
end

function player:add_to_diss( card)
	table.insert(self.dis,card)
	card.postype = define_battle.AREA_MUDI
	card.pos = table.getn(self.dis)
	self:send_change_diss(card:get_id(),table.getn(self.dis),1)	
end


----------------------------------------------------------------------
--发送战场初始化玩家信息 users可收到玩家列表
function player:send_user_info(users)
    logstat.log_day("battle","layer:send_user_info!")
	--发送装备牌
	local mList={}
	local mCard,k,v
	for k,v in pairs(self.cmd) do
    	mCard={cardid = v:get_id(),pos = k,}	
		table.insert(mList,mCard)
	end	

	local msg = pload.encode("game.cmds",{
	size = #mList;
	user_id=self.userid;
	max_hp = self.mhp;
	cur_hp = self.hp;
	max_res = self.mrc;
	cur_res = self.rc;	
	list=mList;
    name = "test";})
	self:send(users,4005,msg)

	--发送手牌
	mList = {}	
	for k,v in pairs(self.hand) do
    	mCard={cardid = v:get_id(),pos = k,cardobj = v:get_oid()}	
		table.insert(mList,mCard)
	end
	
	
	print_r({size = #mList,list=mList,user_id=self.userid,})

	msg = pload.encode("game.hands",{size = #mList;list=mList;user_id=self.userid;})		
	self:send(users,4003,msg)
	
	self:send_crds()
	
end

function player:send_hands()
	DEBUG_MOVE("send_hands")	
	local users = self.battle:get_send_users()
	--发送手牌
	local mList = {}
	local mCard
	for k,v in pairs(self.hand) do
    	mCard={cardid = v:get_id(),pos = k,cardobj = v:get_oid()}	
		table.insert(mList,mCard)
	end
	
	print_r({size = #mList,list=mList,user_id=self.userid,})

	msg = pload.encode("game.diss",{size = #mList;list=mList;user_id=self.userid;})		
	self:send(users,4003,msg)
end

--type 1增加 2删除
function player:send_change_hand(m_user_id,card,m_pos,m_type,src_postype,src_pos)
	DEBUG_MOVE("send_change_hand")	
	local users = self.battle:get_send_users()
	msg = pload.encode("game.change_hand",{
	user_id = m_user_id;
	cardid = card:get_id();
	cardobj = card:get_oid();
	pos=m_pos;
	mtype=m_type;
	s_area = src_postype;
	s_pos = src_pos;
	})	
	print_r({
		cardid = m_cardid;
		pos=m_pos;
		mtype=m_type;})	
	self:send(users,4004,msg)
end


--type 1增加 2删除
function player:send_change_diss(m_cardid,m_pos,m_type)
	DEBUG_MOVE("send_change_diss",m_cardid,m_pos,m_type,self.userid)	
	local users = self.battle:get_send_users()
	msg = pload.encode("game.change_diss",{
	cardid = m_cardid;
	pos=m_pos;
	user_id = self.userid;
	type=m_type;})
	
	print_r({
	cardid = m_cardid;
	pos=m_pos;
	user_id = self.userid;
	type=m_type;})
	self:send(users,4010,msg)
end

--墓地
function player:send_diss()
	DEBUG_MOVE("send_diss")	
	local users = self.battle:get_send_users()
	--发送手牌
	local mList = {}
	local mCard
	for k,v in pairs(self.dis) do
    	mCard={cardid = v:get_id(),pos = k,}
		table.insert(mList,mCard)
	end

	print_r({size = #mList,list=mList,user_id=self.userid,})

	msg = pload.encode("game.diss",{size = #mList;list=mList;user_id=self.userid;})
	self:send(users,4009,msg)

end

function player:send(users,code,msg)
    print("player:send:"..code)
    --print_r(users)
    print("--------------------------------------")
    for _,user in pairs(users) do
        print("player:send:"..user:get_agent())
	    skynet.call(user:get_agent(), "lua", "send",code,msg)
    end
end

--墓地
function player:send_change_diss(m_cardid,m_pos,m_type)
	DEBUG_MOVE("send_change_diss",m_cardid,m_pos,m_type,self.userid)	
	local users = self.battle:get_send_users()
	msg = pload.encode("game.change_diss",{
	cardid = m_cardid;
	pos=m_pos;
	user_id = self.userid;
	type=m_type;})
	
	print_r({
	cardid = m_cardid;
	pos=m_pos;
	user_id = self.userid;
	type=m_type;})
	self:send(users,4010,msg)
end

-- //牌库
-- message crds
-- {
	-- required int32 user_id = 1;	//所属玩家
	-- required int32 size = 2;	//牌库
	-- repeated int32 list = 3;	//牌库
-- }
--牌库
function player:send_crds()

	local users = self.battle:get_send_users()
	local m_list = {}
	local i
    for i = 1,#self.crd do
		table.insert(m_list,self.crd[i]:get_id())
    end
	
	msg = pload.encode("game.crds",{
	user_id = self.userid;
	size=#self.crd;
	list = m_list;
	})
	
	print_r(msg)
	
	self:send(users,4006,msg)
end


-- //2016是否献祭
-- //2006 卡组操作是否成功
-- //11组成卡牌成功保存数据，10不成功
-- //21 修改卡组名称成功保存数据，20不成功
-- //31 删除卡组成功保存数据，30不成功 
-- message game_result
-- {
	-- required int32 id = 1;   	//结果id
	-- optional int32 value = 2;   //结果数值	
	-- optional string msg = 3;   	//信息
-- }
function player:send_game_result(m_id,m_value,m_msg)

	local users = self.battle:get_send_users()	
	msg = pload.encode("game.game_result",{
	id = m_id;
	value=m_value;
	msg = m_msg;
	})
	
	print_r(msg)
	
	self:send(users,4006,msg)
end

return player
