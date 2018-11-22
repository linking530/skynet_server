local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local player = require "npc.player"
local define_battle = require "define.define_battle"
local battle_send = require "battle.battle_send"
local pload = protobufload.inst() 
require "struct.globle"
---------------------------------------------------------------------------
local DEBUG_MOVE = function (...) logstat.log_file2("move.txt",...) end
local DEBUG_MOVE_TABLE = function (table) logstat.log_file_r("move.txt",table) end
local DEBUG_COUNT = function (...) logstat.log_file2("count.txt",...) end
----------------------------------------------------------------------------
local battle = {}
local mt = { __index = battle }

function battle.new ()
    o = o or {}   -- create object if user does not provide one
	setmetatable (o, mt)
	o:set_init(0)
    return o	
end

function battle:set_obj(card,oid)
	self.objsmap[oid]=card
end

function battle:get_obj(oid)
    return self.objsmap[oid]
end

function battle:get_player(userId)
    return self.playMap[userId]
end

function battle:init(agent,userId,agent2,userId2)
    self.isinit = 0
    logstat.log_day("battle","battle:init! \n")
    self.send_users = {}        --发送方包括观战者
    self.player_me = player.new()
    self.player_other = player.new()
    self.player_me:init(agent,userId)
    self.player_other:init(agent2,userId2)
    self.playMap = {}
    self.playMap[userId] = self.player_me
    self.playMap[userId2] = self.player_other
	self.turn_time = 0
	print("userId:"..userId..",userId2:"..userId2)
	self:get_fighter(userId)
	self:get_fighter(userId2)
    if userId == 1 then
        self.npc = self.player_me
    else
        self.npc = self.player_other
    end   
    -- 战场区域
    -- front_begin == uid  从上而下从左向右索引递增,否则从下向上从右向左递增
    -- front_begin == uid 的排列:
    -- 1  2  3  4  5  6
    -- 7  8  9  10 11 12
    -- 13 14 15 16 17 18
    -- front_begin != uid的排列:
    -- 18 17 16 15 14 13
    -- 12 11 10 9 8 7
    -- 6 5 4 3 2 1
    self.front_begin = 0
    --战场牌序
    self.front = {0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0
                    }
    ---------------------------------------------------------------------------------
    --状态控制
    self.war_stutas = 0         --战场阶段
    self.turn_stutas = 0        -- 回合下一个阶段
    self.cur_turn_stutas = 0    --当前回合阶段
    self.turn_time = 0          --回合阶段结束时间点
    self.turn = 0               --Aid , Bid
    self.another_ok = 0         --一方确认开始,等待另一个或时间结束
    self.first_turn = 0         --标记第一回合
    self.winner= nil            --胜利玩家id
	self.mpdata	= {}
  
	self.mpdata[userId] = {}
    self.mpdata[userId]["crd"]={}
    self.mpdata[userId]["cmd"]={}
    self.mpdata[userId]["hnd"]={}
    self.mpdata[userId]["stk"] = {}
    self.mpdata[userId]["dep"] = {}
    self.mpdata[userId]["dis"] = {}
    self.mpdata[userId]["std"]={}
    self.mpdata[userId]["mrc"]=0
    self.mpdata[userId]["rc"]=0	
	
	self.mpdata[userId2] = {}	
    self.mpdata[userId2]["crd"]={}
    self.mpdata[userId2]["cmd"]={}
    self.mpdata[userId2]["hnd"]={}
    self.mpdata[userId2]["stk"] = {}
    self.mpdata[userId2]["dep"] = {}
    self.mpdata[userId2]["dis"] = {}
    self.mpdata[userId2]["std"]={}
    self.mpdata[userId2]["mrc"]=0
    self.mpdata[userId2]["rc"]=0	
	
    self:enter_war()

    self.isinit = 1
end

function battle:get_front_begin()
    return self.front_begin
end

function battle:get_front_begin()
    return self.front_begin
end

function battle:set_front_begin(value)
    self.front_begin = value
end

function battle:set_front(card,pos)
    if card~=nil then
	    self.front[pos] = card
	else
	    self.front[pos] = 0
	end
	if card~=nil and card~=0 then
		card:set_pos(pos)
		--DEBUG_MOVE("set_front",card:get_id(),card:get_uid(),card:get_pos())
	end

end

function battle:get_front(pos)
--    if self.front[pos]~=0 then
--        DEBUG_MOVE(self.front[pos]:get_id())
--    end
	return self.front[pos]
end

function battle:get_fronts()
	return self.front
end

function battle:get_first_turn()
    return self.first_turn
end

function battle:set_first_turn( value )
    self.first_turn = value
end

function battle:get_turn()
    return self.turn
end

function battle:set_init(value)
    self.isinit = value
end

function battle:IsInit()
    return self.isinit
end

function battle:get_turn_time()
    return self.turn_time
end

function battle:set_turn_time(value)
    self.turn_time = value
end

function battle:set_front_begin(value)
    self.front_begin = value
    battle_send.front_begin(self,value)
end

function battle:set_turn(value)
    self.turn = value
	battle_send.set_turn(self,value)
end

function battle:set_war_stutas( value)
    self.war_stutas = value
end
--服务器下一个状态
function battle:set_turn_stutas( value)
    self.turn_time = 0;
    self.turn_stutas = value
end

function battle:add_send_users( value )
    if value:get_userid() ~=1 then
        table.insert(self.send_users,value)
    end
end

function battle:sub_send_users( value )
    for _,user in ipairs(self.send_users) do
        if value:get_userid() == user:get_userid() then
            table.remove(self.send_users,value)        
        end  
    end
end

function battle:get_send_users()
	return self.send_users
end

function battle:set_cur_stutas(value)
     self.cur_turn_stutas = value
end

function battle:get_cur_stutas(value)
     return self.cur_turn_stutas
end

function battle:get_turn_stutas()
    return self.turn_stutas
end

function battle:get_npc()
    return self.npc
end

function battle:set_npc( value )
    self.npc = value
end

function battle:set_another_ok( value)
    self.another_ok = value
end

function battle:get_another_ok()
    return self.another_ok
end

function battle:get_send_users()
    return self.send_users
end

--双方进入牌局
function battle:enter_war()
    logstat.log_day("battle","enter_war!\n")
    self.player_me:set_battle(self)
    self.player_other:set_battle(self)
  
    self:add_send_users(self.player_me)
    self:add_send_users(self.player_other)  

    self:init_ply_info(self.player_me)  
    self:init_ply_info(self.player_other)

    self:set_front_begin(self.player_other:get_userid())                                      
    self:set_turn(self.player_me:get_userid())

    self:set_first_turn(1)
    self:set_war_stutas(define_battle.WAR_READY); -- 战斗准备
    self:set_turn_stutas(define_battle.JIEDUAN_HUIHE_KAISHI)
    self:set_cur_stutas(define_battle.JIEDUAN_CHUSHIHUA)
    
    self:set_turn_time(os.time() + 1)    -- 当前阶段结束时间点
    if self:get_npc() then
       self:set_another_ok(1)
    end
----------------------发送初始化消息---------------------------------------------------
    self.player_me:send_user_info(self.send_users)
    self.player_other:send_user_info(self.send_users)	
    battle_send.cur_stutas(self,self:get_cur_stutas(),0)
    battle_send.set_turn(self,self:get_turn())
    battle_send.cur_stutas(self,self:get_cur_stutas(),1)	
------------------------------------------------------------------------------------
end

--==================== 发送协议 start ====================
--初始化手牌，牌库，装备
function battle:init_ply_info( me)
    me:init_crd()
    me:init_cmd()
    me:init_hand()
end

function battle:send(users,code,msg)
    print("player:send:"..code)
    print("--------------------------------------")
    for _,user in ipairs(users) do
        print("send user.agent:"..user:get_agent())
	    skynet.call(tonumber(user:get_agent()), "lua", "send",code,msg)
	    --skynet.call(agent[fd], "lua", "start", gate, fd,gamed)	    
    end
end

function battle:get_fighter(userId)
    local user,k
    for k,user in pairs(self.playMap) do
        if k ~= userId then
            return k
        end
    end
    return 0
end

function battle:get_winner()
    return self.winner
end

function battle:set_winner(userId)
    self.winner = userId
end

function battle:set_obj(card,oid)
 if _G.objsmap==nil then
	_G.objsmap = {}
 end
  _G.objsmap[oid]=card;  
end
--------------------------------------------------------------------
-- 最大血量
function battle:get_mhp( id)
    local me
    if ~self.isinit then
        return 0
	end
    if(self.id_1~=id)and(self.id_2~=id) then   
        return 0
    end
    me = self.playMap[id]      
    return card:get_mhp()
end

--最大血量
function battle:add_mhp(id, value, times)
    local me
    if ~self.isinit then
        return 0;
	end
    if(self.id_1~=id)and(self.id_2~=id) then   
        return 0
    end
    me = self.playMap[id]
	if value>0 then
		me:add_hp(value)
	end
end

function battle:set_mhp( id,  i)
    local me
    if ~self.isinit then
        return 0
	end
    me = self.playMap[id]
    me:set_mhp(i)
end

-- // =======================================================================
-- // 当前血量
function battle:get_hp( id)
    local me
    if ~self.isinit then
        return 0
	end
	me = self:get_player(id)
    return me:get_hp()
end

function battle:set_hp( id,  i)
    local me
    if ~self.isinit then
        return 0
	end
    me = self.playMap[id]
    me:set_hp(i)
    -- send_user(war->get_send_users(),"%d%d%d",0x2011, id,CARD_CLASS->get_hp(card) ); 
end


function battle:add_hp( id,  value)
    local card,me
	DEBUG_COUNT("battle:add_hp",id,value,self.isinit)	
    if self.isinit == 0 then
        return 0
	end
	me = self:get_player(id)
	me:set_hp(me:get_hp()+value)
    --send_user(this_object()->get_send_users(),"%d%d%d",0x2011, id,CARD_CLASS->get_hp(card) );       
end
--------------------------------------------------------------------------------------------------
--发送牌库信息
function battle_send.card_dead(war,m_user_id,m_cardid,m_pos)
	local msg = pload.encode("game.card_dead",{
	cardid = m_cardid;
    pos =m_pos;
	user_id = m_user_id;
    })
    local d_msg = pload.decode("game.card_dead",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4019,msg)
	DEBUG_MOVE("card_dead",m_user_id,m_cardid,m_pos)
end
return battle