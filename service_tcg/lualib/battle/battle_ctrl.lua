local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local player = require "npc.player"
local define_battle = require "define.define_battle"
local battle_send = require "battle.battle_send"
local skill_rule = require "battle.skill_rule"
local target = require "battle.target"
local pload = protobufload.inst() 
require "struct.globle"
local DEBUG_GUANHUAN = function (...) logstat.log_file2("guanhuan.txt",...) end
local DEBUG = function (...) logstat.log_file2("battle.txt",...) end
local DEBUG_MOVE = function (...) logstat.log_file2("move.txt",...) end
--local DEBUG_MOVE = function (...)   end
local DEBUG_COUNT = function (...) logstat.log_file2("count.txt",...) end
local battle_ctrl = {}

function battle_ctrl.hand(war,player,card_id,num)
    for i =1,num do 		
		local mCard = player:new_card(card_id)
		player:add_to_hnds( mCard)	
    end
end

function battle_ctrl.ai(war,npc)
    local i
	local msg
	if war.turn_time <2 then
        return 0
	end
    -- for i = 1,7 do
        -- local msg = {cardid = 100001,s = 1,spos = 1,d = 7,dpos= i}	
        -- battle_ctrl.war_mov( war,npc,msg)
    -- end
    if war:get_front_begin()==1 then
        msg = {cardid = 100001,s = 1,spos = 1,d = 7,dpos= 1}
        battle_ctrl.war_mov( war,npc,msg)
        -- msg = {cardid = 100001,s = 1,spos = 1,d = 7,dpos= 2}
        -- battle_ctrl.war_mov( war,npc,msg)		
    else
        msg = {cardid = 100001,s = 1,spos = 1,d = 7,dpos= 18}	
        battle_ctrl.war_mov( war,npc,msg)
        -- msg = {cardid = 100001,s = 1,spos = 1,d = 7,dpos= 17}	
        -- battle_ctrl.war_mov( war,npc,msg)
    end
end

--战斗结算阶段状态
--客户端接受0x2060的status，对status不做改变，满足一定条件，返回接受到的status
function battle_ctrl.battle_next( war,  status)
    local id, fighter, uid
    local who, user
    if war== nil then return end
    id = war:get_turn()
    fighter = war:get_fighter(id)
	battle_send.battle_states(war,m_status,0)
    if status==define_battle.BATTLE_GUANGHUAN then --结算光环效果,结算光环效果最先结算反击  
            skill_rule.deal_guanhuan(war)
			DEBUG_GUANHUAN("deal_guanhuan ... \n")		
    elseif status==define_battle.BATTLE_DEPLOY then --结算部署技能效果 deploy    
            skill_rule.deal_deploy_effect(war,fighter);
            skill_rule.deal_deploy_effect(war,id);                
    elseif status==define_battle.BATTLE_DEF_STACK then --结算防御方堆叠区技能效果 order
            skill_rule.deal_stack_effect(war,fighter);
    elseif status==define_battle.BATTLE_ATK_STACK then --结算进攻方堆叠区技能效果 order
            skill_rule.deal_stack_effect(war,id);
    elseif status==define_battle.BATTLE_COUNT then --结算战斗伤害,
            --1.先被动技能
            --2.普攻的时候判断物理攻击
           battle_ctrl.count_all(war)        
    elseif status==define_battle.BATTLE_END then --结算战斗伤害后，回合结束前检查和技能触发      
            --skill_rule.check_turn_end_skill(war)     
    end
	if war~=nil then
		battle_send.battle_states(war,m_status,1)	
	end
end

--一回合内战斗阶段转换
function battle_ctrl.update_turn(war,status_value)
    local status,cur_status
    local npc
    if war:IsInit()==0 then
        return 
    end
    --DEBUG("battle_ctrl.update_turn:",status_value,war:get_cur_stutas())    
    status = war:get_turn_stutas()
    npc = war:get_npc()

    if status_value == -1 then
        if get_party_time() < war:get_turn_time() then
            --DEBUG("battle_ctrl.update_turn return ",get_party_time(),war:get_turn_time())            
            return
        end
    else
       if status_value~=war:get_cur_stutas() then       
            return
       end
    end

    cur_status = status
    war:set_cur_stutas(cur_status);
    --send_user(war->get_send_users(),"%d%c%c", 0x2004, cur_status,0);
    battle_send.cur_stutas(war,cur_status,0)
    if status == define_battle.JIEDUAN_CHUSHIHUA then
        status = define_battle.JIEDUAN_HUIHE_KAISHI
        war:set_turn_stutas(status)
        war:set_turn_time(get_party_time() + 8)
        war:set_another_ok(0)
        DEBUG("JIEDUAN_CHUSHIHUA")    
        if npc~=nil then
            battle_ctrl.ai(war,npc)
        end
    elseif status == define_battle.JIEDUAN_HUIHE_KAISHI then --1 回合开始阶段      己方布置出牌的状态。
		war.turn_time = war.turn_time +1
        battle_ctrl.start_turn(war)
        status = define_battle.JIEDUAN_GONGJI_BUSHU;
        war:set_turn_stutas(status)
        --war:set_turn_time(get_party_time() + define_battle.TURN_TIME) -- 当前阶段结束时间点
        war:set_turn_time(get_party_time() + 1) -- 当前阶段结束时间点		
        war:set_another_ok(0)
        if npc~=nil then
            battle_ctrl.ai(war,npc)
        end
        DEBUG("JIEDUAN_HUIHE_KAISHI")  
    elseif status == define_battle.JIEDUAN_GONGJI_BUSHU then    --攻击玩家部署阶段  对方布置状态
        status = define_battle.JIEDUAN_FANGSHOU_BUSHU
        war:set_turn_stutas(status)
        war:set_turn_time(get_party_time() + define_battle.TURN_TIME)    --当前阶段结束时间点
        war:set_another_ok(0)
        if npc~= nil then
            if war:get_turn()==1 then
                   battle_ctrl.ai(war,npc)
				   war:set_turn_time(get_party_time() + 1)
            end
        end
        DEBUG("JIEDUAN_GONGJI_BUSHU")    
    elseif status == define_battle.JIEDUAN_FANGSHOU_BUSHU then         --3 防御玩家部署阶段  开打表现          
        status = define_battle.JIEDUAN_KAIPAI_JIESUAN
        war:set_turn_stutas(status) 
        --war:set_turn_time(get_party_time() + define_battle.TURN_TIME)   --当前阶段结束时间点
		war:set_turn_time(get_party_time() + 1)
        war:set_another_ok(0)	
        -- if npc~= nil then
			-- npc:npcai()
            -- if war:get_turn()==1 then
                   
            -- end
        -- end
        DEBUG("war:get_turn()",war:get_turn())
        DEBUG("JIEDUAN_FANGSHOU_BUSHU")   
    elseif status == define_battle.JIEDUAN_KAIPAI_JIESUAN then  --4 卡牌结算阶段         
        status = define_battle.JIEDUAN_SHENGWU_ZHANDOU
        war:set_turn_stutas(status) 
        war:set_turn_time(get_party_time() + 1)    --当前阶段结束时间点
        war:set_another_ok(0) 
        DEBUG("JIEDUAN_KAIPAI_JIESUAN")   
    elseif status == define_battle.JIEDUAN_SHENGWU_ZHANDOU then    --5 生物战斗阶段
        DEBUG_COUNT("生物战斗阶段")
        battle_ctrl.battle_next(war,define_battle.BATTLE_GUANGHUAN)  
        battle_ctrl.battle_next(war,define_battle.BATTLE_DEPLOY)             
        battle_ctrl.battle_next(war,define_battle.BATTLE_DEF_STACK) 
        battle_ctrl.battle_next(war,define_battle.BATTLE_ATK_STACK)                        
        battle_ctrl.battle_next(war,define_battle.BATTLE_COUNT) 
        status = define_battle.JIEDUAN_HUIHE_JIESHU
        war:set_turn_stutas(status)
        war:set_turn_time(get_party_time() + 1)    --当前阶段结束时间点
        war:set_another_ok(0)
        DEBUG("JIEDUAN_SHENGWU_ZHANDOU")  
    elseif status == define_battle.JIEDUAN_HUIHE_JIESHU then  --6 回合结束阶段           
        battle_ctrl.battle_next(war,define_battle.BATTLE_END)
        battle_ctrl.battle_next(war,define_battle.BATTLE_TURN_END)
        status = define_battle.JIEDUAN_HUIHE_KAISHI 
        war:set_turn_stutas(status)
        war:set_turn_time(get_party_time() + define_battle.READY_GO) --当前阶段结束时间点
        war:set_another_ok(0)
        DEBUG("JIEDUAN_SHENGWU_ZHANDOU")             
    end
    
    if npc~=nil then
       DEBUG("npc war:set_another_ok(1)") 
       war:set_another_ok(1)
    end
        
    battle_send.cur_stutas(war,cur_status,1)
    if  war:get_winner() then
		battle_ctrl.war_end(war)
    end
end

function battle_ctrl.war_end( war )

end

--前进
function battle_ctrl.forward( war,id)
    DEBUG_MOVE("battle_ctrl.forward",id)  
    local begin, t_end, flag, pos,fight,id
    local card
    if war == nil then return end
    id = war:get_turn()
    fight = war:get_fighter(id)
    if fight == nil or fight == 0 then
        DEBUG_MOVE("battle_ctrl.forward return ",fight)  
        return
    end
    if war:get_front_begin() == id then
        begin = 6;  t_end = 0;    flag = -1;
    else
        begin = 13; t_end = 19;   flag = 1;
    end

    while  begin~= t_end do            
        card = war:get_front(begin)
        DEBUG_MOVE("get_front",begin) 
--        if card~=nil and card:get_uid()==id then 
		if card~=0 then
			DEBUG_MOVE("有牌："..begin) 
			DEBUG_MOVE(card:get_uid())
			DEBUG_MOVE(card:get_pos())
			DEBUG_MOVE(id) 
		end
        if card~=0 and card:get_uid()==id then         
            DEBUG_MOVE("card:get_uid",card:get_uid()) 
            pos = begin - (flag * 6)       
            battle_ctrl.move_in_battle(war,id,begin,pos)
            DEBUG_MOVE("battle_ctrl.move_in_battle",id,begin,pos) 
			card:set_zz(0)			
        end
        begin = begin+flag
    end
    
end

function battle_ctrl.move_in_battle( war,id, begin, dpos)
    local card
    card = war:get_front(dpos)
    
    if card~=0 then --目标位置有牌
        return DEBUG_MOVE("目标位置",dpos,"有牌",card:get_id()) 
    end
    
    card = war:get_front(begin)
    --检查结界
    --原位置有结界，删除结界效果
    war:set_front(card, dpos)
    war:set_front(0, begin)
    battle_send.front_mov(war,begin,dpos)
end

--回合开始
function battle_ctrl.start_turn( war)
    DEBUG_MOVE("battle_ctrl.start_turn")
    local id, id1, dpos = 0, tmp,dpos
    local card,player
    if war==nil then
        return
    end

    war:set_another_ok(0)
    id = war:get_turn()
    id1 = war:get_fighter(id)
    DEBUG_MOVE("start_turn",war:get_turn(),war:get_fighter(id),war:get_first_turn())    
    if war:get_first_turn()~=0 then
        war:set_first_turn(0)
        tmp = id1
        id1 = id
        id = tmp
    else
		print("set_turn id1:"..id1)
		player = war:get_player(id1)	
        war:set_turn(id1)-- 更换主场
        player:add_mrc( player:get_mrc(id)+1)
        player:set_rc(player:get_mrc(id))--1.资源恢复 补满攻击玩家资源
        --屏蔽抓牌
        card = player:pick_card()
        if card==nil then --牌库空
            war:set_winner(id);
            DEBUG_MOVE("牌库为空")  
            return
        end
        if player:get_hnds_size(id1) >= 10 then --超出手牌数量
            player:struct( card )   --丢弃卡牌
            DEBUG_MOVE("丢弃卡牌")  
        else			
            dpos = player:add_to_hnds( card)   --卡牌加入手牌 
            DEBUG_MOVE("卡牌加入手牌")              
        end
        battle_ctrl.forward(war,id1);
    end
	
end


function battle_ctrl.order_check( war,me, msg)
	local sid1Arr,k,v
	local size_j,j,id,result,cost,cost1
	local card,card_me
	local  oid, cardid,  stype,  spos,  destid,  darea, dpos, d_oid
	if oid~= 0 then --修正卡牌位置
        me:refresh_hand_pos()
        card = war:get_obj(oid)
        if card then
            spos = card.pos
		end
    end  

    id = me:get_number();
    card_me = war:get_player_card(id) 
    card = target.get_card(war,id,cardid, stype,spos)
    if  card == 0 or card == nil then
        return 0
    end
  
   if((card.type==define_battle.FASHU_KA) or card.type==define_battle.SHUNJIAN_KA or card.type==define_battle.JIEJIE_KA)  then
        cost1 =  skilldata.get_card_by_string(cardid, "cost")
        if me:get_rc() < cost1 then
            return 0
        end    
  end

   if stype == battle_ctrl.JIEJIE_ORDER then
        result = result+battle_ctrl.order(war,me,  card, -1,stype, spos,  destid,  darea, dpos,d_oid)
        if result~=0 and result~=nil then
            me:add_rc(-cost) --费用
		end
   else

   table.join(sid1Arr,skilldata.check_skill_trigger2(cardid, TRIGGER_19))
   table.join(sid1Arr,skilldata.check_skill_trigger2(cardid, TRIGGER_30))
   table.join(sid1Arr,skilldata.check_skill_trigger2(cardid, TRIGGER_31))
   print_r(sid1Arr)
	for k,v in pairs(sid1Arr) do
		cost = skilldata.get_skl_by_string(k,"cost") 
		if me:get_rc( ) < cost then
			return 0
		end	

		if skilldata.get_skl_by_string(sid1Arr[j],"fselect")==8 then
			result = result+battle_ctrl.order(war,me,  card, k,stype, spos,  destid,  darea, dpos,d_oid)
		else
			result = result+battle_ctrl.order(war,me,  card, k, stype, spos, destid,  darea, dpos,d_oid)        
		end
		if result~=0 then
			me:add_rc(-cost) --费用
		end
	end
   end
	
    if result==0 then
        return
    end

    if (stype == define_battle.SHOUPAI_ORDER) or (stype == define_battleJIEJIE_ORDER) then
		if result~=0 then
            me:add_rc( -cost1) --费用          
		end
        skill_rule.check_condition_skill(war,define_battle.TRIGGER_35,me:get_number()) --35：每当使用一张非部队牌时，
        me:del_from_hnds(spos)
        if stype == define_battle.SHOUPAI_ORDER then
            card.get["dis"]=1
		end
    end 
	
end

--使用卡牌技能
--war order cardid stype spos destid darea dpos      cardid 发送效果的卡牌id(装备牌，装备牌id)  pos 战场上的牌的位置  destid 目标牌id  darea 效果区域  dsop  目标位置
--stype 1圣物-从command牌上发出的技能 2手牌 3战场牌发出技能       spos位置
--如果有目标:destid darea dpos
--目标是指挥部：destid为0，darea为指挥部区域（5、6）,dpos 为0
function battle_ctrl.order(war, me,card, sid1,  stype,  spos,  destid,  darea, dpos, d_oid)
    local id, fight,cons, cost, cardid
    local skl_str,targ
    local skillStack = {}
    cardid=  card.cid
    id = me:get_number()
    fight = war:get_fighter(id)
    if fight~=0 then
        DEBUG_SKILL(sprintf("!fight "));
        return 0
    end
    cons = skilldata.get_skl_by_string(sid1, "condition")

    if stype==define_battle.JIEJIE_ORDER then
		  sid1 = -1
		  cost = 0
    else
        cost = skilldata.get_skl_by_string(sid1,"cost")
    end

    targ=target.get_card(war,card.uid,destid, darea,dpos,d_oid)
    card.get["targ"]=targ
    war:set_obj(card,card.oid)

    skillStack.card = card
    skillStack.oid = card.oid
    skillStack.cardid = cardid
    skillStack.sid1 = sid1
    skillStack.stype = stype
    skillStack.spos = spos
    skillStack.destid = destid
    skillStack.darea = darea
    skillStack.dpos = dpos
    skillStack.targ = targ

    if(card.type==define_battle.SHUNJIAN_KA)then
            skill_rule.check_condition_skill(war,define_battle.TRIGGER_36,card.uid)
	end
    if(card.type==define_battle.FASHU_KA)then
            skill_rule.check_condition_skill(war,define_battle.TRIGGER_37,card.uid)
    end
    if(card.postype ~= define_battle.AREA_XIAOSHI)then
        if(card.type==define_battle.FASHU_KA or card.type==define_battle.SHUNJIAN_KA) then
            skill_rule.check_condition_skill(war,define_battle.TRIGGER_10,war:get_fighter(card.uid))
            skill_rule.check_condition_skill(war,define_battle.TRIGGER_13,card.uid)
            skill_rule.check_condition_skill(war,define_battle.TRIGGER_17,0)
		end
    end
	
    if(skilldata.get_skl_by_string(sid1, "runtime")==2)then
        skill_rule.deal_effect_skl(war,id,card,sid1,destid,darea,dpos)   
        if((card.type==define_battle.FASHU_KA)or(card.type==define_battle.SHUNJIAN_KA))then
            if(card:getStatus(define_battle.MINGYUE))then
                me:add_to_crds2(card)
            else
                me:add_to_diss(card)
			end
        end                   
    else
        war:add_stack(skillStack)
		battle_send.add_stack(war,me:get_number(), cardid, sid1, stype, spos, darea, dpos)
    end
    cons = skilldata.get_skl_by_string(sid1, "condition");
    if( cons == 30 )then
        card.zz=1
		battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
    end

    if( stype == define_battle.COMMAND_ORDER ) then
		battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
	end	
    if( stype == define_battle.ZHANCHANG_ORDER ) then
        battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
	end	
    if(stype == define_battle.JIEJIE_ORDER) then
        skill_rule.check_condition_skill(war,define_battle.TRIGGER_38,card.uid) --使用工事牌
        skill_rule.check_condition_skill(war,define_battle.TRIGGER_35,card.uid)--使用非部队牌
    else
        --"sys/task/daily"->check_task(me,HERO_TROOPS,war->get("war.type"),0);
    end

    return 1

end

function battle_ctrl.deploy_check( war,me,  cardid,  spos,  destid,  darea, dpos, target, d_oid)
   local sid1Arr,size_j,j,cost,result
   local id = me:get_number()
   sid1Arr = skilldata.check_skill_trigger2(cardid, 2)
  
   size_j=#sid1Arr
   for j = 1,size_j do
        cost = skilldata.get_skl_by_string(sid1Arr[j],"cost") 
        if(me:get_rc(id) < cost) then
            return 0;
		end
        if(target==1)then
            if(skilldata.get_skl_by_string(sid1Arr[j],"fselect")==8)then
                result=battle_ctrl.deploy(me,  cardid, sid1Arr[j], spos,  destid,  darea, dpos,d_oid)
                if(result) then
                    me:add_rc(-cost) 
				end
                return
            end
        else
             result = battle_ctrl.deploy(me,  cardid, sid1Arr[j], spos,  destid,  darea, dpos,d_oid)  
             if(result) then
                me:add_rc(-cost)-- 费用
			 end
        end
   end  
end

-- //部署主动选择技能协议 源区域默认手牌
-- // war deploy cardid spos destid darea dpos 
-- //[0x2062][0自己/1对方 %c][cardid %d][spos %c][目标区域 %c][dpos %c]
function battle_ctrl.deploy(war, me,  cardid,  sid1, spos,  destid,  darea, dpos, d_oid)
    local id, fight,  last
    local skl_str
    local card,targ,skillStack
    local stype,cost    
    id = me:get_number()
    fight = war:get_fighter(id)
	
    if fight ==0 or fight == nil then return end
	
    card = target:get_card(war,id,cardid, 7,spos)
	
    if(card~=0 or card~=nil)then
        return
    end
	
    if(skilldata.get_skl_by_string(sid1,"fselect")==8)then
        if(destid~=0)then
            if(darea~=5)and(darea~=6)then
                if(skilldata.get_skl_by_string(sid1,"type")~=3)then
                    return
                else
                    if(darea==0)then return end
				end
			end
		end
    end	
    cost = skilldata.get_skl_by_string(sid1,"cost") --使用技能的扣费,通过技能上的费用消耗，不用全牌表费用
    if(me:get_rc(id) < cost)then
        return
    end
    targ=target.get_card(war,id,destid, darea,dpos,d_oid)
    card.get["targ"]=targ
    war:set_obj(card,card.oid)
    skillStack = {}
    skillStack.card = card
    skillStack.oid = card.oid
    skillStack.cardid = cardid
    skillStack.sid1 = sid1
    skillStack.stype = define_battle.ZHANCHANG_ORDER
    skillStack.spos = spos
    skillStack.destid = destid
    skillStack.darea = darea
    skillStack.dpos = dpos
    skillStack.targ = targ
    war:add_deploy(id,skillStack)
end

--确认完成操作
function battle_ctrl.card_ok( war,me,status)
    local id
    DEBUG("battle_ctrl.card_ok:"..status,war:get_cur_stutas(),me:get_number())

    if me==nil then
      return
    end

    id = me:get_number()
    if war == nil then 
        return
    end

    if(war:get_cur_stutas()== define_battle.JIEDUAN_GONGJI_BUSHU) -- A部署 服务器计时,
    or (war:get_cur_stutas() == define_battle.JIEDUAN_FANGSHOU_BUSHU) then-- B针对A部署的反应 服务器计时,
        battle_ctrl.update_turn(war,status)
    else   
        if war:get_another_ok() and (war:get_another_ok() ~= id) then -- 另一个确认完,开始战斗
            battle_ctrl.update_turn(war,status)          
        else  --否则等待
            war:set_another_ok(id)
        end       
    end
end

function battle_ctrl.move_to_battle( war,id, cid, card, dpos)
   DEBUG_MOVE("move_to_battle:",id, cid, dpos)
   dcard=war:get_front(dpos)
   if dcard~=0 then -- 目标位置有牌
        DEBUG_MOVE("move_to_battle:","目标位置有牌")   
		return 0
   end

   war:set_front(card, dpos)
   return 1
end

function battle_ctrl.move_to_battle( war, id,cid, card,dpos )
    local dcard,jj,id
    dcard=war:get_front(dpos)
    if(dcard~=0) then--目标位置有牌
		DEBUG_MOVE("move_to_battle:","目标位置有牌 0") 
        if(dcard.type==define_battle.JIEJIE_KA) then
            DEBUG_MOVE("结界 %O %O",dcard.uid,card.uid)
            if(dcard.uid==card.uid)then
                DEBUG_MOVE("附加结界 %O %O",dcard.uid,card.uid)
                war:set_front(card, dpos)
                card:set_jj(dcard)
            else
                DEBUG_MOVE("摧毁结界",dcard.uid,card.uid)          
                battle_ctrl.card_dead(war, dcard)
                war:set_front(0, dpos)
                dcard = 0
			end
        else
            DEBUG_MOVE("move_to_battle:","目标位置有牌") 
            return 0
		end
	else
		DEBUG_MOVE("move_to_battle:","dpos:",dpos) 
		war:set_front(card, dpos)
	end
    
    if card:getStatus(define_battle.CHONGFENG) then -- 有冲锋技能
        card.zz=0
    else
        card.zz=1
    end
	
    if skilldata.has_skill(cid,define_battle.CHIHUAN) then --迟缓
         card:addStatus(define_battle.CHIHUAN,1,99)
    end
    jj = card.jj
    if(jj~=nil )then
        jj.pos=card.pos
    end
    return 1
end

--移动
--s区域spos的牌,移动到 d区域dpos的位置 手牌不需要 spos
function battle_ctrl.war_mov( war,me,msg)
    local  card_temp = war:get_front(msg.dpos)
	print("msg.dpos:"..msg.dpos)
	--print_r(card_temp)
	if card_temp ~= 0 or card_temp == nil then
		DEBUG_MOVE("已有卡牌 \n")
		return
	end
	id = me:get_number()

    -- if  war:get_cur_stutas() ~= define_battle.JIEDUAN_GONGJI_BUSHU then	-- 其他阶段不能操作         
        -- return DEBUG_MOVE("其他阶段不能操作:"..war:get_cur_stutas() )
    -- end
    if msg.s == define_battle.AREA_SHOUPAI and msg.d == define_battle.AREA_ZHANCHANG then 
	
	--手牌到战场
        card =  me:get_hnd(msg.spos)         
        if card == nil then
            DEBUG_MOVE("找不到牌 spos:"..msg.spos)                
            --print_r(me:get_hnds())
            return
        end
        if card:get_id() ~= msg.cardid then
            DEBUG_MOVE("card:get_id() ~= msg.cardid",card:get_id(),msg.cardid)
            return;
        end
        --print_r(msg)
        if battle_ctrl.move_to_battle(war,id,msg.cardid,card,msg.dpos)==1 then
            DEBUG_MOVE("move_to_battle")
            battle_send.move_to_fronts(war,id,msg.cardid,msg.spos,msg.dpos)
            me:del_from_hnds(msg.spos)
            card:set_zz(0)
        end

    elseif msg.s == define_battle.AREA_ZHANCHANG and msg.d == define_battle.AREA_ZHANCHANG then -- 战场内移动
       card = war:get_front(msg.spos)
        
       if card:get_id()~= msg.cardid then
           DEBUG_MOVE("card:get_id()~= cid",card:get_id(),msg.cardid)
           return
       end
       if card:get_uid()~=id then
           DEBUG_MOVE("card:get_uid()~=id",card:get_uid(),id)         
       end	   
       battle_ctrl.move_in_battle(war,id,msg.spos,msg.dpos);
	end
end

function battle_ctrl.can_sacrifice(battle,player)
	if battle:get_cur_stutas()~=define_battle.JIEDUAN_GONGJI_BUSHU then
		print(battle:get_cur_stutas()..","..define_battle.JIEDUAN_GONGJI_BUSHU)
		print("can_sacrifice:war:get_cur_stutas()~=JIEDUAN_GONGJI_BUSHU")
		return 0
	end
	
	if player:get_number()~=battle:get_turn() then
		print("player:get_number()~=battle:get_turn()")
		return 0
	end
	
	-- if player:get_ops(2) then
		-- return 0	
	-- end
    return 1
end

-- message war_sacrifice
-- {
	-- required int32 cardid = 1;
	-- required int32 pos = 2;
-- }
--献祭
function battle_ctrl.war_sacrifice(battle,player,msg)
	print("battle_ctrl.war_sacrifice")
	if player==nil or msg.cardid==0 then
		print("war_sacrifice no player or cardid == 0")
		return 0
	end
    if msg.pos < 1 then
		print("war_sacrifice msg.pos < 1")
        return 0
	end
    local id = player:get_number()
	print("player:get_hnd:"..msg.pos)
	local card = player:get_hnd(msg.pos)
    if card ==nil or card==0 then
		print("war_sacrifice card is not exist")
        return 0
	end
	
	print(card)
	print_r(msg)
	if card:get_id()~=msg.cardid then
		player:send_game_result(2016,1,nil)	
		return 0
	end
	
	-- if battle_ctrl.can_sacrifice(battle,player) then
		-- print("battle_ctrl.can_sacrifice(battle,player)")		
		-- player:send_game_result(2016,0,nil)	
		-- return 0
	-- end

	player:set_ops( 2,1 )
	player:add_mrc(1)
	player:set_rc(player:get_mrc())--1.资源恢复 补满攻击玩家资源	

	card:set_postype(define_battle.AREA_XIAOSHI)
    player:del_from_hnds( msg.pos )

	player:send_game_result(2016,battle_ctrl.can_sacrifice(battle,player),nil)	
	--player:send_war_sacrifice(cardid, msg.pos)
    skill_rule.check_condition_skill(battle,define_battle.TRIGGER_53,id);
    skill_rule.check_condition_skill(battle,define_battle.TRIGGER_55,battle:get_fighter(id))

end

--处理部署技能效果
function battle_ctrl.deal_deploy_skl( war,  id,  pos)
    local cardid,i, sid, condition,card
    card = war:get_front(pos)
    if card~=0 then return end
    cardid = card.cid
    sid = skilldata.get_card_by_string(cardid, "skill_id")
    for i = 1, 4 do
		condition = skilldata.get_skl_by_string(sid, i, "condition") 
        if( condition == 1 and condition == 2 ) then -- 2：部署（当xxx进场时触发）  1：持续被动
			if( skilldata.get_skl_by_string(sid, i, "fselect") ~= 8 ) then --玩家主动选择目标，走 deploy 流程
				skill_rule.deal_effect_skl(war,id,card,cardid,i,0,0)
			end
		end
    end
    return 1
end

--卡牌死亡
function battle_ctrl.card_dead( war,  card)
	local  cid, id, id1, uid,pos,me

	if war== nil then
	   return
	end

	cid = card:get_id()
	uid = card:get_uid()
	id = war:get_turn()
	id1 = war:get_fighter(id)

	pos = card:get_pos()

	if pos < 1 or pos > 18 then
	   return
	end
	me = war:get_player(uid)
	
	war:set_front(0, pos)
	me:add_to_diss( card )	--丢弃卡牌
	battle_send.card_dead(war,uid,cid,pos)
end

--战斗结束
function battle_ctrl.war_end( war )

end

function battle_ctrl.checkdie(war,first,second)
	battle_send.cards_info(war,second:get_pos(),second:get_hp(),second:get_mhp(),second:get_ap(),second:get_zz())
	battle_send.cards_info(war,first:get_pos(),first:get_hp(),first:get_mhp(),first:get_ap(),first:get_zz())	
    if second:get_hp()<=0 then
        battle_ctrl.card_dead(war, second)
	end
    if first:get_hp()<=0 then
        battle_ctrl.card_dead(war, first)
	end
end

function battle_ctrl.attack(war, first, second)
    DEBUG_COUNT("battle_ctrl.attack ",first:get_id(), second:get_id())

    if first:get_uid() == second:get_uid() then
        return
    end
    --攻击
    hurt = first:get_ap() - second:get_dp()

    --[0x2053%d][玩家ID %d][cardid %d][spos %c][目标区域 %c][dpos %c]     
	battle_send.battle_card_attack(war,1,first:get_uid(),first:get_id(),first:get_pos(),define_battle.AREA_ZHANCHANG,second:get_pos())    
	if hurt>0 then
        second:add_hp( -hurt )
	end

    --反击
    hurt = second:get_ap() - first:get_dp() 
            
    if hurt>0 then
        first:add_hp(-hurt)
    end
	
    battle_ctrl.checkdie(war,first,second)	
end

function battle_ctrl.attack_command( war,att_card, id, fighter)
DEBUG_COUNT("battle_ctrl.attack_command ",att_card:get_id(), id, fighter)

    --[0x2053%d][玩家ID %d][cardid %d][spos %c][目标区域 %c][dpos %c]
 	battle_send.battle_card_attack(war,1,att_card:get_uid(),att_card:get_id(),att_card:get_pos(),define_battle.AREA_DUIFANG_ZHIHUIBU,0)       
	hurt = att_card:get_ap()

    war:add_hp(fighter, -hurt)

    if war:get_hp(fighter) <= 0 then --指挥部血量为0，战斗结束
        war:set_winner(id)
    end
	
end


--清算普攻
function battle_ctrl.count_all(war) 
    local id,begin,t_end,flag,fighter,att_card,def_card
    id = war:get_turn()
    if war:get_front_begin() == id then
        begin = 1
		t_end = 13 
		flag = 1
    else
        begin = 18
		t_end = 6
		flag = -1
    end
    fighter = war:get_fighter(id)
    DEBUG_COUNT("battle_ctrl.count_all ",id,begin,t_end,flag,fighter)
    while begin~=t_end do
        att_card = war:get_front(begin)
        if att_card~=0 and att_card:get_uid() == id then
			DEBUG_COUNT("get_uid.count_all ",att_card:get_uid(),id)
			def = begin + (flag * 6)
			def_card = war:get_front(def)
			if def_card == 0 then
					if begin>6 and begin <13 then
						battle_ctrl.attack_command(war,att_card,id,fighter)
					end
				else
					battle_ctrl.attack(war,att_card, def_card )
			end
		end
		begin = begin+flag
	end	
end

return battle_ctrl