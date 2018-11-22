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
local skilldata = require "data.skilldata"
require "struct.globle"

local DEBUG = function (...) logstat.log_file2("battle.txt",...) end
local DEBUG_MOVE = function (...) logstat.log_file2("move.txt",...) end
local DEBUG_GUANHUAN = function (...) logstat.log_file2("guanhuan.txt",...) end

local skill_rule = {}
skilldata = skilldata.inst()

-- 处理技能效果
-- war, 
-- uid, 主动方ID
-- pos, 卡牌位置
-- sid, 技能大类 
-- flag
-- darea 效果区域
-- dpos 目标位置
function skill_rule.deal_effect_skl( war, uid, card, sid, destid, darea, dpos)
	local size, i,j, prop, value, frepeat,nextskill,targets_pos,temp,area
	local targets = {}
	local me
	local poss = {}
	local sendstr
	local mtype
	local fun
	
	mtype = skilldata.get_skl_by_string(sid,"type")
	frepeat = skilldata.get_skl_by_string(sid,"frepeat")
	area = skilldata.get_skl_by_string(sid,"area");
	DEBUG_GUANHUAN("sid:"..sid,mtype,frepeat,area)
	if war:get_winner()~=0 then
		DEBUG_GUANHUAN("war:get_winner()","return")
		return
	end
	if card:getStatus(QUSAN) then
		DEBUG_GUANHUAN("card:getStatus(QUSAN)","return")
		return
	end
	
    if frepeat==-1 then
        targets= card:get_b_targs()
        frepeat = #targets
    end
	--改变属性
	if mtype == define_battle.SKILL_TYPE_1 or mtype == define_battle.SKILL_TYPE_11 or mtype ==define_battle.SKILL_TYPE_18 or type ==define_battle.SKILL_TYPE_10 then
		DEBUG_GUANHUAN("改变属性 \n")
		for i = 1,frepeat do
			targets = skill_do.change_shuxing(war, uid, card, sid,destid, darea, dpos)
		end
	elseif mtype == define_battle.SKILL_TYPE_2 then --获取参数
	   targets = skill_target.find_target(war, uid, card, sid,destid, darea, dpos)
	elseif mtype == define_battle.SKILL_TYPE_3 then --召唤
	   skill_do.summon_monster(war,card,uid,sid,darea,dpos)
	   skill_rule.battle_next(war,BATTLE_GUANGHUAN)
	elseif mtype == define_battle.SKILL_TYPE_4 then --捉牌
	   skill_do.draw_card(war,card,uid,sid)
	elseif mtype == define_battle.SKILL_TYPE_5 then --消灭
	   targets = skill_target.find_target(war, uid, card, sid,destid, darea, dpos)           
	   skill_do.destroy(war,targets);
	elseif mtype == define_battle.SKILL_TYPE_6 then --转移
	   targets = skill_target.find_target(war, uid, card, sid,destid, darea, dpos)    			  
	   skill_do.zhuanyi(war,uid,sid,targets)
	elseif mtype == define_battle.SKILL_TYPE_13 then 	--hand指定卡牌到自己手中	
	   		for i = 1,frepeat do
			end
	elseif mtype == define_battle.SKILL_TYPE_14 then--hand指定卡牌到对手手中 		
	   		for i = 1,frepeat do
			end
	elseif mtype == define_battle.SKILL_TYPE_16 then --交换双方玩家的生命值		
	   --
	elseif mtype == define_battle.SKILL_TYPE_17 then--复制 		
	   --
	elseif mtype == define_battle.SKILL_TYPE_22 then --前进至前线（必须合法）		
	   --
	elseif mtype == define_battle.SKILL_TYPE_23 then--后退至防线（必须合法） 		
	   -- 
	end
    card:set_b_targs(0)
    nextskill = skilldata.get_skl_by_string(sid,"nextskill")
    if nextskill~=nil then
        if targets~=nil then
            card:set_b_targs(targets)
            skill_rule.deal_effect_skl( war,  uid,  card,  nextskill, destid, darea, dpos)
        end
    end	
end


--返回目标的位置 战场0 - 17,  uid 手牌:20-29 对手手牌:30-39 坟墓 40/41 堆叠区 50/51 指挥官:60/61
function skill_rule.find_target( war,  uid,  cardpos,  sid,  darea, dpos, flag)

    local targets = {}
    local camp,target,select
    local fs_arg,arg
    local dp
    camp =  skilldata.get_skl_by_string(sid, "fcamp")--有效的阵营    
    target =  skilldata.get_skl_by_string(sid, "ftarget")--有效种类对象    
    select =  skilldata.get_skl_by_string(sid, "fselect")    
    fs_arg =  skilldata.get_skl_by_string(sid, "fs_arg")
    dp = math.floor(dpos/6)*6
    if select == 8 then
        targets = {dpos,dp,dp+1,dp+2,dp+3,dp+4,dp+5}
        return targets
    end
    return targets
end

--光环统计
function skill_rule.deal_guanhuan( war )
    local i, card_id,fronts,card
    fronts = war:get_fronts() 
    for i = 1, 18 do
       card = fronts[i]
       if card~=0 then
			card:cleanBuffStatus()
	   end
    end
	DEBUG_GUANHUAN("skill_rule.deal_guanhuan:"..define_battle.TRIGGER_1)
    skill_rule.check_condition_skill(war,define_battle.TRIGGER_1,0)
    for i = 1, 18 do	
       card = fronts[i]
       if card~=0 then 
		   if card.mhp22> card.mhp2 then
				card:add_hp(card.mhp22-card.mhp2)
				card.mhp22=0
		   end
		   battle_send.cards_info(war,card:get_pos(),card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz()) 
	   end
    end
end


--检查战场是否有要触发的技能
function skill_rule.check_condition_skill( war, condition, uid)
    local i, fronts,card
	DEBUG_GUANHUAN("skill_rule.check_condition_skill condition:"..condition)
	print("skill_rule.check_condition_skill condition:"..condition)
    fronts = war:get_fronts()
    for i = 1, 18 do
       card = fronts[i]
       if card~=0 then
		   if (uid~=0) and (uid~=card:get_uid()) then
				--continue
		   else	
				--检查单张卡牌是否有触发的技能
				if card~=nil then
					DEBUG_GUANHUAN("检查单张卡牌是否有触发的技能")
					skill_rule.check_condition_card(war,card,condition)
				end
		   end
	   end
    end
end

--检查单张卡牌是否有触发的技能
function skill_rule.check_condition_card( war,  card, condition)
	local sid1Arr,j,k
	sid1Arr = skilldata.check_skill_trigger2(card:get_cid(), condition)
	--print_r(sid1Arr)
	sid1Arr = skilldata.check_skill_trigger(card, condition,sid1Arr)
	--print_r(sid1Arr)
	DEBUG_GUANHUAN("skill_rule.check_condition_card:",card.pos,condition)
	if sid1Arr==nil then
		DEBUG_GUANHUAN("skill_rule.check_condition_card:sid1Arr==nil \n")
		return
	end
	for k,v in pairs(sid1Arr) do
		DEBUG_GUANHUAN("skill_rule.check_condition_card:sid1Arr:",k)
		skill_rule.deal_effect_skl(war,card:get_uid(),card,k,0,0,0)
	end
end

-- 处理堆叠区战术牌效果
--  [0x2050 %d][8]
--  [0x2050 %d][0自己/1对方 %c][cardid %d][技能编号 %d][技能2级编号 %c]
--  [0x2050 %d][9]
function skill_rule.deal_deploy_effect( war, uid)
    local fighter, key, i, size, num,sc
    local cardid,sid1,stype,spos,destid,darea,dpos,oid
    local str;
    local who, me;
    local card,card1
    local skillStack
    local mpTmp, tmp
	local player = war:get_player(uid)	
    if war==nil then    return end
    fighter = war:get_fighter(uid) 
	mpTmp = player:get_mpdep(uid)
    if( mpTmp==0 or mpTmp==nil  ) then return end
	size = #mpTmp
    if( #mpTmp==0 ) then return end
	battle_send.battle_card_effect(war,uid,8,0,0,0) 

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
	
	for i=1,size do
        num = key[i]
        skillStack = player:get_deploy(num)
        oid = skillStack.oid
        cardid = skillStack.cardid
        sid1 = skillStack.sid1
        stype = skillStack.stype
        spos = skillStack.spos
        destid = skillStack.destid
        darea = skillStack.darea
        dpos = skillStack.dpos
        if(sid1==0) then
            player:del_deploy(num)
		else
			card = war:get_obj(oid)
			if (card.postype==define_battle.AREA_ZHANCHANG) then
				battle_send.battle_card_effect(war,m_user_id,1,card.cid,card.pos,sid1)                  
				if(card:getStatus(define_battle.QUSAN_DEPLOY)~=0)then 
					skill_rule.deal_effect_skl(war,uid,card,sid1,destid,darea,dpos);
				end
			else
				battle_send.battle_card_effect(war,m_user_id,1,card.cid,card.pos,sid1)
			end
			player:del_deploy(num)
		end
	end
	battle_send.battle_card_effect(war,uid,9,0,0,0) 
end

-- //处理堆叠区战术牌效果
-- // [0x2050 %d][8]
-- // [0x2050 %d][0自己/1对方 %c][cardid %d][技能编号 %d][技能2级编号 %c]
-- // [0x2050 %d][9]
function skill_rule.deal_stack_effect( war, uid)
    local fighter, key, i, size, num,sc
    local cardid,sid1,stype,spos,destid,darea,dpos,oid
    local str
    local who, me
    local user,card,card1
    local skillStack 
    local mpTmp, tmp

	local player = war:get_player(uid)	
    if war==nil then    return end	
    fighter = war:get_fighter(uid)
    mpTmp = player:get_mpstk() 
	size = #mpTmp
    if( mpTmp==nil or #mpTmp==0 ) then return end
	battle_send.battle_card_effect(war,uid,8,0,0,0)   
    for i=1,size do
        num = key[i]
        skillStack = player:get_stack(num)
        oid = skillStack.oid
        cardid = skillStack.cardid
        sid1 = skillStack.sid1
        stype = skillStack.stype
        spos = skillStack.spos
        destid = skillStack.destid
        darea = skillStack.darea
        dpos = skillStack.dpos
        card = war:get_obj(oid)
        if(card==0 or card==nil ) then return end
        if(card.type==2) then --如果是结界
            card1 = war:get_front(dpos)
            if(card1) then--如果有牌
                if(card1.type==2) then
                    player:add_to_diss(card)
                else
                    if(card1.jj~=0) then
                        battle_ctrl.card_dead(war, card1.jj)
					end
                    card1:set_jj(card)
				end
            else
                player:add_to_diss( card )
			end
            skill_rule.check_condition_card(war,card,define_battle.TRIGGER_43)      
        else
            if((card.type==1) or (card.type==9)) then
                if(card.postype==battle_define.AREA_ZHANCHANG or skilldata.get_skl_by_string(sid1,"type")==6) then
					battle_send.battle_card_effect(war,m_user_id,1,card.cid,card.pos,sid1)					
                    skill_rule.deal_effect_skl(war,uid,card,sid1,destid,darea,dpos)
                else
					battle_send.battle_card_effect(war,m_user_id,1,card.cid,card.pos,sid1)
				end
            else
				battle_send.battle_card_effect(war,m_user_id,1,card.cid,card.pos,sid1)	
                skill_rule.deal_effect_skl(war,uid,card,sid1,destid,darea,dpos)
			end
        end
        player:del_stack(num)
        if(card and card.get["dis"] and (card.postype~=battle_define.AREA_MUDI)) then
            if(card.type~=2) then--结界不去墓地
				if(card:getStatus(battle_define.MINGYUE)) then
					player:add_to_crds2(card)
				else
					player:add_to_diss(card)
				end
			end
		end
	end
    battle_send.battle_card_effect(war,uid,9,0,0,0) 
end

return skill_rule