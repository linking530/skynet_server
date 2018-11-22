local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local player = require "npc.player"
local define_battle = require "define.define_battle"
local battle_send = require "battle.battle_send"
local skilldata =  require "data.skilldata"
local carddata =   require "data.carddata"

local pload = protobufload.inst() 
require "struct.globle"
local DEBUG = function (...) logstat.log_file2("battle.txt",...) end
local DEBUG_MOVE = function (...) logstat.log_file2("move.txt",...) end
local DEBUG_GUANHUAN = function (...) logstat.log_file2("guanhuan.txt",...) end

local skill_do = {}

function skill_do.change_props( war,carduse, uid,  mtype,  value, times, target,fparm)
    local  me
    local card;
    local i,size,fighter,pos,value1

    fighter = war:get_fighter(uid)
    size = #target    
    if(size==0 ) then
        return 0
    end

	if mtype == 1 then --攻击
            for i=1, size do
                card = target[i]
                if card then 
					card:add_ap(card,value,times)
					if(times~=-1) then
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
				end
            end
	elseif mtype== 2 then --生命上限
            for i=1, size do
                card = target[i]
                if card then 
                if( card.is_user) then --如果是指挥部
                    war:add_mhp(card.uid,value,times)
                    if(value>0) then                   
                        if(times==-1) then
                            card.hp2 = card.hp2+value
                        else
                            war:add_hp(card.uid,value) 
						end 
					end
                    if( war:get_hp(card.uid) <= 0 ) then
                        war:set_winner( war:get_fighter(card.uid))                    
                        return 1
					end
                else
                    card:add_mhp(value,times)
                    if(value>0) then
                        if(times==-1) then
                            card.hp2 = card.hp2+value
                        else
                            card:add_hp(value)
						end
					end
                    if(times~=-1) then
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
                    if(((card:get_mhp()<=0) or (card:get_hp()<=0)) and value<0) then
                        battle_ctrl.card_dead(war, card)
					end
				end
            end
		end
	elseif mtype== 3 then --生命
            if(carduse:getStatus(define_battle.BAOJI)) then
                if(value<0) then
                    value = value*2
				end
			end
            for i=1, size do
                card = target[i]
                if(card~=0) then             
                if( card.is_user) then --如果是指挥部
                    war:add_hp(card.uid,value)
                    if( war:get_hp(card.uid) <= 0 ) then
                        war:set_winner( war:get_fighter(card.uid))
                        return 1
					end
                else
                    if(value>0 and (card:get_hp()<card:get_mhp())) then 
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_46,0)
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_47,card.uid)	
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_48,war:get_fighter(card.uid))                                                                
						card:add_hp(value)
						if(carduse:getStatus(define_battle.ZHIMING)and(value<0)) then
							card:add_hp(-1000)
						end
						if(times~=-1) then
							battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
						end
						if(((card:get_mhp()<=0) or (card:get_hp()<=0)) and value<0) then
							battle_ctrl.card_dead(war, card)
						end
				    end
               end 
			   end
			end
	elseif mtype== 47 then--生命
            value = -carduse:get_ap()
            for i=1, size do
                card = target[i]
                if( card) then               
                if( card.is_user)  then--如果是指挥部
                    war:add_hp(card.uid,value)
                    if( war:get_hp(card.uid) <= 0 ) then
                        war:set_winner( war:get_fighter(card.uid))
                        return 1
					end
                else
                    if(value>0 and (card:get_hp()<card:get_mhp())) then
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_46,0)	
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_47,card.uid)
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_48,war:get_fighter(card.uid))	                                                        
					end
                    card:add_hp(value)
                    if(carduse:getStatus(define_battle.ZHIMING) and (value<0)) then
                        card:add_hp(-1000)
					end
                    if(times~=-1) then
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
					if(((card:get_mhp()<=0) or (card:get_hp()<=0)) and value<0) then
                        battle_ctrl.card_dead(war, card)
					end
				 end
            end    
			end
	elseif mtype== 45 then--生命上限和当前值一起减
            if(carduse:getStatus(define_battle.BAOJI)) then
                if(value<0) then
                    value = value*2
				end
			end
            for i=1, size do
                card = target[i]
                if( card.is_user) then--如果是指挥部
                    if(times==-1) then
                        card.hp2 = card.hp2+value
                    else
                        war:add_hp(card.uid,value)
					end
                    war:add_mhp(card.uid,value,times)
                    if( war:get_hp(card.uid) <= 0 ) then
                        war:set_winner( war:get_fighter(card.uid))                 
					end
                else
                    card.get["no_cond5"] = 1
                    if(times==-1) then
                        card.hp2 = card.hp2+value
                    else
                        card:add_hp(value)
					end
                    card.get["no_cond5"] = 0                        
                    card:add_mhp(value,times)
                    if(times~=-1) then
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
                        if(((card:get_mhp()<=0) or (card:get_hp()<=0)) and value<0) then
                            battle_ctrl.card_dead(war, card)
						end
					end
				end
			end     
	elseif mtype== 6 then --装甲
            for i=1, size do
                card = target[i]
                if(card) then
					card:add_dp(value,times)
					if(times~=-1) then
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
				end
            end            
	elseif mtype== 9 then --祝福
                for i=1, size do
                    card = target[i]
                    if card ~=0 then
						war:add_hp(card.uid, card.mpTmp["c_hurt"])
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
				end
	elseif mtype== 30 then --吸血
                if(uid~=war:get_turn()) then
					return 
				end
                for i=1, size do
                    card = target[i]
                    if( card) then
                    if(value>0 and (card:get_hp()<card:get_mhp())) then
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_46,0);	
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_47,card.uid);	
                        skill_rule.check_condition_skill(war,define_battle.TRIGGER_48,war:get_fighter(card.uid))                                                        
					end
					battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
				end
	elseif mtype== 33 then
                for i=1, size do
                    card = target[i]
                    if( card) then
						war:add_rc(card.uid,value)
					end
                end
	elseif mtype== 34 then --法力上限
                for i=1, size do
                    card = target[i];
                    if( card) then
						war:set_mrc(card.uid,war:get_mrc(card.uid)+value)
					end
                end
	elseif mtype== 102 then --回满法力
                for i=1, size do
                    card = target[i]
                    if( card) then
						war:set_rc(card.uid,war:get_mrc(card.uid))
					end       
                end
	elseif mtype== 22 then
                for i=1, size do
                    card = target[i]
                    if( card) then
                    card:resetCard(value)
                    if( card:getStatus(define_battle.CHONGFENG) ) then --有冲锋技能
                        card.zz = 0
                    else
                        card.zz = 1
					end
                    --send_user(war->get_send_users(),"%d%d%d%c", 0x2063, card->uid,card->cid,card->pos+1); 
					end
				end
                if(size>0) then
                    battle_ctrl.battle_next(war,BATTLE_GUANGHUAN)
                end
	elseif mtype== 47 then
                for i=1, size do
                    card = target[i]
                    if( card) then
                    if(value==1)  then       
                        card:add_hp(- carduse:get_ap())
                    elseif(value == 2) then
                        card:add_hp(- carduse:get_hp())
                    elseif(value == 3) then
                        card:add_hp(- skilldata.get_card_by_string(carduse.cid, "cost"))
					end
                   battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
                    if(((card:get_mhp()<=0) or (card:get_hp()<=0)) and value<0) then 
                        battle_ctrl.card_dead(war, card)
					end
                    if(((card:get_mhp()<=0) or (card:get_hp()<=0))) then
                        battle_ctrl.card_dead(war, card)
					end
                end       
				end
	elseif mtype== 50 then --攻击
			value1 = value
           for i=1, size do
                card = target[i]
                if( card) then
					value = value1-card:get_ap()	
					card:add_ap(value,times)
				   if(times~=-1) then
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
				   end
			   end
            end       
	elseif mtype== 51 then --血上限
			value1 = value;
            for i=1, size do
                card = target[i]
				value = value1-card:get_mhp()
                if( card) then
                if( card.is_user) then--如果是指挥部
                    war:add_mhp(card.uid,value,times)
                    if(value>0) then                     
                        if(times==-1) then
                            card.hp2 = card.hp2+value
                        else
                            war:add_hp(card.uid,value)
						end
                    if( war:get_hp(card.uid) <= 0 ) then
                        war:set_winner( war:get_fighter(card.uid))                 
                        return 1
					end
                else
                    card:add_mhp(value,times)
                    if(value>0) then
                        if(times==-1) then
                            card.hp2 = card.hp2+value
                        else
                            card:add_hp(value)
						end
					end
                    if(times~=-1) then
                        battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
                    if(((card:get_mhp()<=0) or (card:get_hp()<=0)) and value<0) then 
                        battle_ctrl.card_dead(war, card)
					end
				end
            end
				end
			end
	elseif mtype== 52 then --血当前
			value1 = value
            for i=1, size do
                card = target[i]
                if( card) then
                value = value1-card:get_hp()		
                if( card.is_user) then --如果是指挥部
                    war:add_mhp(card.uid,value,times)					
                    if(value>0) then                      
                        if(times==-1) then
                            card.hp2 = card.hp2+value
                        else
                            war:add_hp(card.uid,value)
						end 
					end
                    if( war:get_hp(card.uid) <= 0 ) then
                        war:set_winner( war:get_fighter(card.uid))                 
                        return 1
					end
                else
                    card:add_mhp(value,times)
                    if(value>0) then 
                        if(times==-1) then 
                            card.hp2 = card.hp2+value
                        else
                            card:add_hp(value)
						end
					end
                    if(times~=-1) then
						battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())
					end
                    if(((card:get_mhp()<=0) or (card:get_hp()<=0)) and value<0) then
                        battle_ctrl.card_dead(war, card)
					end
					end
				end
            end             
     else
	 end
    return 1; 
end

function skill_do.add_buff( war, carduse, uid,  mtype,  value, times, target, fparm)
    local card
    local i,size,fighter
    fighter = war:get_fighter(uid)    
	size = #target
    if( size==0 ) then
        return 0
    end
	for i=1, size do
        card = target[i];
        if(card) then
			card:addStatus(type,value,times)
        end
	end
    return 1
end

function skill_do.add_skill( war, carduse, uid,  mtype,  value, times, target, fparm)
    local card;
    local i,size,fighter;
    fighter = war:get_fighter(uid)  
	size = #target
    if( size==0 ) then
        return 0
    end
	
	for i=1, size do
        card = target[i];
        if(card) then
			card:addSkill(mtype)
        end
	end	
    return 1
end

function skill_do.xixue( war, card, value)

end

function skill_do.shibukedang( war, card)
    local pos,fighter,flag,id
    id = war:get_turn()
    if(war:get_front_begin() == id) then
        flag = 1
    else
        flag = -1
	end

    if(card~=0)  then return end

    fighter = war:get_fighter(card.uid)
    if((card.pos<6)or (card.pos>12)) then
        return
	end
    war:add_hp(fighter, -card:get_ap())
    if( war:get_hp(fighter) <= 0 ) then
        war:set_winner(card.uid)
	end
end

function skill_do.jianta( war, card)
   local pos,flag,id
   local def
    id = war:get_turn()
    if(war:get_front_begin() == id) then
        flag = 1
    else
        flag = -1     
	end
    if(card~=0) then return end
    if(card.get["j_hurt"]<0) then 
        return
	end
    pos =  card.pos + (flag * 6)
    def = war:get_front(pos)
    if(def) then
        def:add_hp(-card.get["j_hurt"])
		battle_send.cards_info(war,card.pos,card:get_hp(),card:get_mhp(),card:get_ap(),card:get_zz())          
        if def:get_hp()<=0 then
            battle_ctrl.card_dead(war, def)
		end
    else
        if((card.pos)>5 and (card.pos<12)) then
            return
		end
        wa:add_hp(card.uid, -card.get["j_hurt"])
        if( war:get_hp(card.uid) <= 0 ) then
            war:set_winner( war:get_fighter(card.uid))
		end
	end
end

function skill_do.change_shuxing( war,  uid,  card,  sid, destid, darea, dpos)
	DEBUG_GUANHUAN("改变属性 \n")
    local size, i,prop, value,times,poss = {},j
    local targets = {};
    local tmp, str_arr, str,sendstr
    
    local mtype = skilldata.get_skl_by_string(sid, "type");   --技能类型
    local fparm =  skilldata.get_skl_by_string(sid, "fparm");   --次数2
    local arg = skilldata.et_skl_by_string(sid, "farg");   --数值
    if(skilldata.get_skl_by_string(sid, "condition")==101) then 
			--arg = replace_string(arg,"$",sprintf("%d",sizeof(card->get["b_targs"])));  
	end
    tmp = explode(arg,"#")
    targets = target.find_target(war, uid, card, sid,destid, darea, dpos)
    if( #targets ==0) then -- 获取目标位置
        return
	end
    size = #tmp
	for i=1, size do
        str = tmp[i]
        str_arr = explode(str,",")
        if( 2 == #str_arr ) then    
            prop = tonumber(str_arr[0])--属性类型
            value = tonumber(str_arr[1])--数值
            times = 250
        elseif( 3 == #str_arr ) then 
            prop = tonumber(str_arr[0])--属性类型
            value = tonumber(str_arr[1])--数值
            times = tonumber(str_arr[2])--回合数     
        end
        
        if((skilldata.get_skl_by_string(sid, "condition")==define_battle.TRIGGER_1)or(skilldata.get_skl_by_string(sid, "condition")==define_battle.TRIGGER_41)) then 
           times = -1
		end
        if(mtype==10) then
            skill_do.add_buff(war,card, uid, prop, value,times, targets,fparm)
        elseif(mtype==18) then
            skill_do.add_skill(war,card, uid, prop, value,times, targets,fparm)
        else
            skill_do.change_props(war,card, uid, prop, value,times, targets,fparm) --更改属性
		end
	end
    return targets
end

--消灭技能处理(战术牌,主动触发处理)
function skill_do.destroy( war, target)
    local card
    local i,size
    size = #target
    for i = 1,size do
        card = target[i]
        if(card) then
			battle_ctrl.card_dead(war, card)
		end
	end
end

--抽牌技能处理(战术牌,主动触发处理)
function skill_do.draw_card( war, card,  id,  sid)
    local fighter, size, i, fcamp, times,result,mtype
    local str_arr,arg
    local targets

    arg = skilldata.get_skl_by_string(sid, "farg") --数值
    
    if(skilldata.get_skl_by_string(sid, "condition")==101) then 
       --     arg = replace_string(arg,"$",sprintf("%d",sizeof(card->get["b_targs"])))
     end           
    fcamp = skilldata.get_skl_by_string(sid, "fcamp")
    times = skilldata.get_skl_by_string(sid, "frepeat")
    if(times==-1) then 
        targets= card.get["b_targs"]
        times = #targets
	end
    if(fcamp~=0) then 
        return 0;
	end
    if( times~=0) then 
        return 0;
	end
    fighter = war:get_fighter(id)
    str_arr = explode(arg,",")
	size = #str_arr
    if( size==0 ) then 
        return
	end
    if( size ~= 2) then 
        return
	end
    mtype = tonumber(str_arr[1])    --抽牌类型 1：捉牌 2: 弃牌   
    if( fcamp == 1 or fcamp == 3 ) then  --己方抓弃牌
        for i=1,times do
            if( mtype == 1 ) then 
                if(war:get_crds_size(id)==0) then 
                     war:set_winner(fighter)
                     return
				end
                result = skill_do.zhuapai(war,id)--检查抽牌触发技能
			end
            if( mtype == 2 ) then 
                result = skill_do.qipai(war,id)
			end
		end
    end
    if( fcamp == 2 or  fcamp == 3 ) then --对方抓弃牌
        for i = 1,times do 
            if( mtype == 1 ) then 
                if(war:get_crds_size(fighter)==0) then 
                     war:set_winner(id);
                     return
				end
                result = result + skill_do.zhuapai(war,fighter)--/检查抽牌触发技能
			end
            if( mtype == 2 ) then 
                result = result +skill_do.qipai(war,fighter)     
			end
		end
	end
	
    return result
end

function skill_do.zhuapai( war, id)
    local fighter, dpos
    local  card
    local result
	card = war:pick_card(id)
    if(card==0 or card==nil) then  --牌库空
        war:set_winner(fighter)
        return 0
	end
    if(war:get_hnds_size(id) >= 9) then -- 超出手牌数量
        war:add_to_diss(id, card)   --丢弃卡牌
        result = 1;
    else
        dpos = war:add_to_hnds(id, card,1)   --卡牌加入手牌
        result = 1
	end
    return result
end

function skill_do.qipai( war, id)
    local size,pos
    local hands,card
    local player
	player = war:get_player(id)
    hands = player:get_hnds()
	size = #hands
    if( size==0 ) then
        return
	end
    pos = math.random(size)
    card = hands[pos]
    player:del_from_hnds( pos)--//删除手牌
    player:add_to_diss( card)--  //丢弃卡牌
    --[0x2066][卡牌id %d][pos %c]  自己丢牌//pos:手牌位置
    --send_user(war->get_send_users(),"%d%d%c",0x2013,id,war->get_hnds_size(id));
end

--召唤技能处理(战术牌,主动触发处理)
function skill_do.summon_monster( war,card,  uid,  sid, darea, dpos)
    local times, i, mtype, cardid, j,ftarget,mselect,targets
    local str_arr,arg,str_arr_size,msize
    arg = skilldata.get_skl_by_string(sid, "farg")   --数值
    if(skilldata.get_skl_by_string(sid, "condition")==101) then
		msize = #card.get["b_targs"]
		string.gsub(arg, "$", tostring(msize)) 
	end

    str_arr = explode(arg,",")
	str_arr_size = #str_arr
    if( str_arr_size~= 2) then
        return
	end
	cardid = tonumber(str_arr[1])
    if( cardid~=0 ) then
        return
	end
	mtype = skilldata.get_skl_by_string(sid,  "type") 
    if( mtype~= 3 ) then--不是召唤技能
        return
	end
	times = skilldata.get_skl_by_string(sid, "frepeat") 
    if( times==0  ) then
        return
	end
	ftarget = skilldata.get_skl_by_string(sid, "ftarget")
    if( ftarget==0  ) then
        return
	end
    mselect = skilldata.get_skl_by_string(sid,  "fselect")
    
    if(times==-1) then
        times = #card.get["b_targs"]
	end
      
	if( mselect == 8)  then  --客户端指定召唤位置
		if(dpos~=0) then
			table.insert(targets,dpos)
		else
			targets = {}
		end
		
		if(war:get_front_begin() == uid) then
			targets = table.insert(targets,skill_rule.randArr( {5,4,3,2,1,0} ))
		else
			targets = table.insert(targets,skill_rule.randArr( {12,13,14,15,16,17} ))
		end
	else
		if(ftarget==7) then
			 if(war:get_front_begin() == uid) then
				targets = skill_rule.randArr( {5,4,3,2,1,0} )
			 else
				targets = skill_rule.randArr( {12,13,14,15,16,17} )   
			end
		elseif(ftarget==17) then
			 if(war:get_front_begin() == uid) then
				targets = {11,10,9,8,7,6}
			else
				targets = {6,7,8,9,10,11}     
			end
		elseif(ftarget==4) then
			 targets = {card.get["die_pos"]}      
		end
    end
    i = 0;
   
    while(times>i and #targets>0) do--召唤次数
		msize = #targets
        for j = 1,msize do
            if(skill_do.zhaohuan(war,uid,targets[j],cardid)) then
                 i = i+1
			end
            targets[j] = 0
            if(times<=i) then
                return
			end
		end
		table.remove(targets,0)
	end
end

function skill_do.zhaohuan( war, uid, pos, cardid, card)
    local obj,cur
    local postype,player
    cur = war:get_front(pos)
    if(cur and cur.type ~= define_battle.JIEJIE_KA) then
        return 0
	end
    if(card~=0 and card~=nil) then
		player = war:get_player(uid)
		obj = card.new(war,player,cardid)
	    obj.type=define_battle.YANSHENG_KA
	else
	    obj = card
	end
	if(obj~=0 and obj~=nil)then
	    return 0
	end	
	obj.uid = uid
	postype = obj.postype
    if(battle_ctrl.move_to_battle(war,obj.cid,obj,pos+1)) then
        if(postype == define_battle.AREA_SHOUPAI) then
		end
        battle_ctrl.battle_next(obj.war,define_battle.BATTLE_GUANGHUAN)
        return 1
	end
	return 0
end

function skill_do.del_card( war, card)
   local mtype
   local sw
   local mtype= card.postype
   local player
    if mtype== define_battle.AREA_SHOUPAI then
			player = war:get_player(card.uid)
            card = player:del_hands_card( card) --删除手牌                 
    elseif mtype== define_battle.AREA_MUDI then
			player = war:get_player(card.uid)
            card = player:del_from_diss( card)--删除手牌          
    elseif mtype== define_battle.AREA_PAIKU then
			player = war:get_player(card.uid)
            card = player:del_crds( card)--删除牌库               
    elseif mtype== define_battle.AREA_ZHANCHANG then
            if(card.type==JIEJIE_KA) then
                sw = card.sw
                if(sw) then
                    sw:set_jj(0)
                else
                    war:set_front(0, card.pos)
				end
            else
                if(card.jj) then
                    war:set_front(card.jj, card.pos)
                else
                    war:set_front(0, card.pos)
				end
                card:set_jj(0)
			end
            battle_ctrl.battle_next(war,BATTLE_GUANGHUAN)          
	end
    card:resetStatus()
    return card
end

function skill_do.zhuanyi( war,  id,  sid, target)
    local str_arr,arg
    local card
    local dpos,targets,size
    local dtype,i,j,player,jsize
    arg = skilldata.get_skl_by_string(sid, "farg") --数值
    str_arr = explode(arg,",")
	size = #str_arr
    if( size ~= 2) then
        return
	end
	dtype = tonumber(str_arr[1]) 
    if( dtype==0) then
        return
	end
	size = #target
    for i = 1,size do
		card = target[i]
		if card then 
        if(skill_do.del_card(war,card)) then        
            if(card.type~=define_battle.YANSHENG_KA and card.get["derive"]~=0) then--衍生物不可转移
             if (dtype==1) then
				player = war:get_player(card.uid)
				dpos = player:add_to_hnds( card,1) --     卡牌加入手牌               
             elseif (dtype==2) then
				player = war:get_player(card.uid)
				player:add_to_crds2(card)                    
             elseif (dtype==3) then
				player:add_to_diss( card)--丢弃卡牌      
             elseif (dtype==5) then--对方防线
				if(war:get_front_begin() == war:get_fighter(id)) then 
					targets =skill_rule.randArr( {5,4,3,2,1,0} )
				else
					targets = skill_rule.randArr( {12,13,14,15,16,17} )   
			    end
				jsize = #targets
				for j = 1,jsize do
					if(skill_do.zhaohuan(war,war:get_fighter(id),targets[j],card.cid,card))then
						j = #targets+1
					end
				end
				if(card.postype==define_battle.AREA_SHOUPAI) then

					player = war:get_player(card.uid)
					player:add_to_hnds(card,1) 
				end
          elseif (dtype==6) then--//自己防线
					if(war:get_front_begin() == id) then
						targets =skill_rule.randArr( {5,4,3,2,1,0} )
					else
						targets =skill_rule.randArr( {12,13,14,15,16,17} )
					end
					for j = 1,jsize do
						if(skill_do.zhaohuan(war,war:get_fighter(id),targets[j],card.cid,card)) then
							j = #targets+1
						end
					end
					if(card.postype==define_battle.AREA_SHOUPAI) then
						player = war:get_player(card.uid)
						player:add_to_hnds(card,1) 
					end
          elseif (dtype==8) then
					card.postype = define_battle.AREA_XIAOSHI
          elseif (dtype==9) then--拥有者防线
					if(war:get_front_begin() == card.uid) then
						targets =skill_rule.randArr( {5,4,3,2,1,0} )
					else
						targets =skill_rule.randArr( {12,13,14,15,16,17} )
					end         
					for j = 1,jsize do
						if(skill_do.zhaohuan(war,war:get_fighter(id),targets[j],card.cid,card)) then
							j = #targets+1
						end
					end
					if(card.postype==AREA_SHOUPAI) then
						player = war:get_player(card.uid)
						player:add_to_hnds(card,1) 
					end
		 elseif (dtype==10) then
				player = war:get_player(id)
				dpos = player:add_to_hnds( card,1) --卡牌加入手牌
		 elseif (dtype==14) then--自己牌库顶
				player = war:get_player(id)
				player:add_to_crds(card)
		 elseif (dtype==16) then--
				player = war:get_player(war:get_fighter(id))
				player:add_to_crds()
		 elseif (dtype==18) then--拥有者牌库顶
				player = war:get_player(card.uid)
				player:add_to_crds()
		end
	end
	end
	end
	end
    return 0
end

function skill_do.hand_card( war, uid , sid)
    local card
    local tmp
    local arg = skilldata.get_skl_by_string(sid, "farg") --数值
    -- tmp = explode(arg,",")    
    -- card="sys/copy/war_card_obj"->create_card2(to_int(tmp[1]),war,uid);
    if(card==0 or card==nil) then  --牌库空
        return 0
	end
    war:add_to_hnds(uid,card,1)
end

--后退
function skill_do.back_forward( war,  card)
    local mbegin, mend, flag, pos,fight,id
    id = card.uid
    fight = war:get_fighter(id)
    if(fight==0)then
        return
	end
    if(war:get_front_begin() == id) then
	{
        mbegin = 5;  
		mend = -1;    
		flag = 1;
    }
    else
	{
        mbegin = 12; 
		mend = 18;   
		flag = -1;
    }
    mbegin = card.pos;
    if(mbegin<=5 or mbegin>=12) then
        return
	end
    card = war:get_front(begin)    
    pos = mbegin - (flag * 6);
    battle_ctrl.move_in_battle(war,begin,pos)
end


return skill_do