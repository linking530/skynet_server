local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local player = require "npc.player"
local define_battle = require "define.define_battle"
local pload = protobufload.inst() 
local skilldata = require "data.skilldata"
require "struct.globle"
local DEBUG = function (...) logstat.log_file2("target.txt",...) end
local target = {}


function target.find_war_char( war, uid)
	local me
    if(uid==1) then
        me = war:get_npc()
    else
		me = war:get_player(uid)
	end
    return me
end

function target.get_card( war, uid, cardid, stype, spos, d_oid)
    local i, card,u_player
    if d_oid~=nil and d_oid~=0 then
        card = war:get_obj(d_oid)
        if card~=nil and card~=0 then            
            return card
        end
    end

	u_player = war:get_player(uid)
    if  stype == define_battle.COMMAND_ORDER then --装备
        for i = 1,3 do
            card = u_player:get_cmd(i)
            if card and cardid== card.cid and spos==card.pos then
				return card
			end
        end
        if card == nil then
            return 0
		end
        if  card.pos ~=spos then
            return 0
		end
    end
    if (stype == define_battle.SHOUPAI_ORDER) or(define_battle.JIEJIE_ORDER ==stype) then --手牌
        card = u_player:get_hnd(spos)
        if (card==nil or card== 0) then return 0 end
        if cardid ~= card.cid then
            return 0
		end
    end
    if stype == define_battle.AREA_ZHANCHANG then   --战场
        card = war:get_front(spos)
        if (card==nil or card== 0) then return 0 end
        if  cardid ~= card.cid then
            card = card.jj
			if card==nil or card== 0 then return 0 end
            if cardid ~= card.cid then
                 return 0
		    end
		end
     end
	
    if(stype == define_battle.AREA_DUIFANG_ZHIHUIBU) then
        card = war:get_player_card(war:get_fighter(uid))
    end
    
    if(stype == define_battle.AREA_ZIJI_ZHIHUIBU) then
        card = war:get_player_card(uid)
    end
    return card
end

function target.check_target( war, uid, card,  target, camp, ftarget)
    return  target
end

--处理技能效果
--war, 
-- uid, 主动方ID
-- pos, 卡牌位置
--sid, 技能大类 
--flag
-- darea 效果区域
-- dpos 目标位置
function target.find_target( war, uid,  card, sid, destid, darea, dpos)
    local i, j, filter, size, value, fid, str 
    local fs_arg_tmp ={}
    local targets = {}
	local chufa, mubiao,jj
	local objs={}
    local camp,target,select,campArr = {0,0}
    local fs_arg  
	DEBUG("target.find_target",uid,card.id,sid,destid,darea,dpos,"\n")
    camp = skilldata.get_skl_by_string(sid,  "fcamp")  --有效的阵营    
    target = skilldata.get_skl_by_string(sid, "ftarget")  --有效种类对象    
    select = skilldata.get_skl_by_string(sid,  "fselect")    
    fs_arg = skilldata.get_skl_by_string(sid, "fs_arg")
	DEBUG("target.find_target",camp,target.select,fs_arg,"\n")	
    if( select == 8) then  --客户端指定召唤位置
        mubiao = card.get["targ"]
        if(mubiao==nil or mubiao ==0 ) then
			DEBUG("mubiao==nil or mubiao ==0 \n")
			return 
		end
        if(target==15) then
            if(mubiao.type~=2)then
                mubiao = mubiao.jj
			end
		end
        if(target==16) then
            jj = mubiao.jj
			table.insert(targets,jj)
		end
        table.insert(targets,jj)
        targets = target.check_target(war, uid,card, targets, camp, target)
        return targets
	end

    if( select == 2) then
        mubiao = card.sw  
		table.insert(targets,mubiao)
        return targets
    end
    if(select == 17)then --客户端选择阵营
        mubiao = card.get["targ"]
        if(mubiao==0 or mubiao ==nil) then return end
        if(uid == mubiao.uid)then
            camp = 1
        else
            camp = 2
	    end
	end
       
    --camp 有效的阵营 1己方 2敌方 3不限
    --tid 被排除的对象
    fid = war:get_fighter(uid) 
    if (camp==1) then
            campArr[0] = uid
            campArr[1] = 0
    elseif (camp==2) then
            campArr[0] = 0
            campArr[1] = fid
    else
            campArr[0] = uid
            campArr[1] = fid
    end
    --ftarget 有效种类对象
    if (target==1) then --指挥部
            targets = table.insert( targets,war:get_ord(campArr[0]) )
            targets = table.insert( targets,war:get_ord(campArr[1]) )
    elseif (target==2) then         
            targets = table.insert( targets,target.get_front_budui(war,campArr[0]) )
            targets = table.insert( targets,target.get_front_budui(war,campArr[1])  )    
    elseif (target==3) then --指挥部&战场里的部队
            targets = table.insert( targets,war:get_ord(campArr[0])  )
            targets = table.insert( targets,war:get_ord(campArr[1])  )
            targets = table.insert( targets,target.get_front_budui(war,campArr[0])  )
            targets = table.insert( targets,target.get_front_budui(war,campArr[1])  )                
    elseif (target==4) then --拥有者
            targets = table.insert( targets,card)
    elseif (target==5) then --触发的对象
            targets = table.insert( targets, war:get_cur_con_do(card) )        
    elseif (target==6) then --牌库顶
            targets = table.insert( targets,war:get_top_crd(campArr[0]) )
            targets = table.insert( targets,war:get_top_crd(campArr[1]) )         
    elseif (target==7) then --防线 没有
    elseif (target==8) then --8坟墓
            objs =table.merge_card( targets,war:get_dis_all(campArr[0]) )     
            if(objs) then
                targets = table.merge_card( targets,objs)
			end
            objs = war:get_dis_all(campArr[1])
            if(objs) then           
                targets = targets +objs;
            end
    elseif (target==10) then 
            objs = war:get_crds(campArr[0])           
            if(objs) then
                targets =table.merge_card( targets ,objs)
			end
            objs = war:get_crds(campArr[1])
            if(objs)  then          
                targets = table.merge_card(targets , objs )     
			end	
    elseif (target==11) then --11手牌
             objs = war:get_hnds(campArr[0])
            if(objs) then
                targets = table.merge_card( targets ,objs )
			end
            objs = war:get_hnds(campArr[1])
            if(objs)  then     
                targets =table.merge_card( targets +objs)
			end
    elseif (target==15) then 		--15领域	
            targets = table.merge_card(  targets ,target.get_front_linyu(war,campArr[0]) )
            targets = table.merge_card(  targets ,target.get_front_linyu(war,campArr[1]) )       
    elseif (target==16) then 
            targets = table.merge_card(  targets ,target.get_front_budui2(war,campArr[0]) )
            targets = table.merge_card(  targets ,target.get_front_budui2(war,campArr[1]) ) 
    elseif (target==18) then 
            targets = table.merge_card(  targets ,{war.get("user_card")} )
    elseif (target==19) then 
            targets = war:get_cur_con_bedo(card)  
    elseif (target==20) then 
            targets = table.merge_card(  targets ,{war:get_rand_crd(campArr[0],define_battle.SHENGWU_KA)})
            targets = table.merge_card(  targets ,{war:get_rand_crd(campArr[1],define_battle.SHENGWU_KA)})
    elseif (target==21) then 
            targets = table.merge_card(  targets ,{war:get_rand_crd(campArr[0],define_battle.SHUNJIAN_KA)})
            targets = table.merge_card(  targets ,{war:get_rand_crd(campArr[1],define_battle.SHUNJIAN_KA)})
    end
    -- fselect 释放筛选
    --  1国家阵营
    --  2处于同一位置（主要用于工事判断）
    --  6对阵目标及其左右相邻
    --  7相邻随从（参数0：1个相邻）
    --  8已筛选目标
    --  9所有已筛选对象
    --  10所有已筛选对象（除发起者）
    --  11同线攻击部队
    --  12 部队牌
    --  13 战术牌
    --  14同线所有部队
    if (select==2) then --获得领域上放置的对象
	
    elseif (select==8) then --客户端选定的目标           
		table.remove(targets,mubiao)
    elseif (select==17) then
		table.remove(targets,mubiao)	
    elseif (select==9) then
    elseif (select==10) then  --所有已筛选对象（除发起者）
			table.remove(targets,card)
    elseif (select==11) then --对阵不对
            targets =  target.duizhen(targets,card)
    elseif (select==12) then --生物，部队类型的牌
            targets = target.get_budui(targets) 
    elseif (select==13) then --法术类型的牌 
            targets =  target.get_fashu(targets)
    elseif (select==14) then 
            targets = target.get_sjfashu(targets)
    elseif (select==15) then 
            targets =  target.get_gongshi(targets)
    else
	
    end

	table.remove( targets, 0)
    if( fs_arg ) then
        fs_arg_tmp = explode(fs_arg,"#")
		size = #fs_arg_tmp
        if(size == 0) then  
			return targets 
		end
        objs = {}
        fori = 1,size do
            str = fs_arg_tmp[i]
            objs =  table.merge_card(  objs ,get_fs_arg(targets,str,card) )
       end
       targets = objs
	end
    return targets
end

function target.get_fs_arg(  targets, str, card)
    return targets
end

--获得战场部队
function target.get_front_budui( war, id)
    local i
    local front,card,budui
    if(id==0) then return {} end
    --DEBUG(sprintf("war:%O id:%O",war,id))      
    budui ={}
    front = war:get_fronts()
    --DEBUG(sprintf("front %O",front))
    for i =1,  18 do 
        card = front[i]
        if card~= 0 and card.type~=2 then 
			 --DEBUG(sprintf("card:%O uid:%O id:%O\n",card,card->uid,id));				
			if(card.uid==id) then 
				if(card.get["ak"]==1) then
					 if(card:get_hp()>0) then
						table.insert(budui,card)
					 end
				else
					 table.insert(budui,card)
				end
			end
		end
    end
    return budui
end

function target.get_front_budui2( war, id)
    local i;
    local front,card
	local budui = {}
    if(id==0) then return budui end
    --DEBUG(sprintf("war:%O id:%O",war,id))        
    front = war:get_fronts()
    --DEBUG(sprintf("front %O",front))
    for i = 1,18 do
        card = front[i]
        if(card~=0) then
        --DEBUG(sprintf("card:%O uid:%O id:%O\n",card,card->uid,id));
			if(card.uid==id) then
				if(card.get["ak"]==1) then
					 if(card:get_hp()>0) then
						table.insert(budui,card)
					 end
					 if(card.jj)then
						table.insert(budui,card.jj)
					 end
				else
					 table.insert(budui,card)
					 if(card.jj) then
						table.insert(budui,card.jj)
					 end
				 end
			end
		end
	end
    return budui
end

function target.get_front_linyu( war, id)
    local i
    local front,card,budui
	local budui = {}
    if(id==0) then return budui end
    front = war:get_fronts()
	
    --DEBUG(sprintf("get_front_linyu front %O",front))
    for i = 1,18 do
        card = front[i]
        if(card~=0) then
			--DEBUG(sprintf("i:%O card:%O uid:%O id:%O\n",i,card,card->uid,id));
			if(card.uid==id) then
				if(card.type==2) then
					table.insert(budui,card)
				else
					if(card.jj) then
						table.insert(budui,card.jj)
					end              
				end
			end
		end
	end
    --DEBUG(sprintf("get_front_linyu budui %O",budui))
    return budui
end

--获得派系
function target.get_paixi(  tag, paixi)
    local i,size
    paixi = paixi-30
    --DEBUG(sprintf("paixi %O %O",tag,paixi));
	table.remove(tag,0)
    size = #tag
    for i = 1,size do
        --DEBUG(sprintf("check %O,%O,%O,%O",paixi,tag[i]->get["race1"],tag[i]->get["race2"],tag[i]->get["race3"]));
        if(paixi==0) then      
            if((tag[i].get["race1"]~=paixi)or(tag[i].get["race2"]~=paixi)or(tag[i].get["race3"]~=paixi)) then
                tag[i]=0
			end
        else        
			if((tag[i].get["race1"]==paixi)or(tag[i].get["race2"]==paixi)or(tag[i].get["race3"]==paixi)) then
				
			else
				tag[i]=0
			end
		end
	end
	table.remove(tag,0)
    return tag 
end

--获得tag中的所有部队牌
function target.get_budui( tag)
    local i,size
	table.remove(tag,0)
    --DEBUG(sprintf("get_budui begin %O",tag));  
    size = #tag      
    for i = 1,size do
        if(tag[i].type~=define_battle.SHENGWU_KA) then
            tag[i]=0
		end
    end
	table.remove(tag,0)
    --DEBUG(sprintf("get_budui begin %O",tag));      
    return tag;
end

--获得防线上的对象
function target.get_fangxian( tag)
    local pos,i,size
    --DEBUG(sprintf("get_fangxian begin %O",tag));    
	table.remove(tag,0)
    size = #tag   
    for i = 1,size do
	if((tag[i].pos>5) and (tag[i].pos<12)) then
            tag[i]=0
		end
	end
	table.remove(tag,0)
    --DEBUG(sprintf("get_fangxian begin %O",tag));    
    return tag
end

--获得前线上的对象
function target.get_qianxian( tag)
    local pos,i,size
	table.remove(tag,0)
    --DEBUG(sprintf("qianxian begin %O",tag));
    size = #tag   
    for i = 1,size do
        if((tag[i].pos<=5) or (tag[i].pos>=12)) then
            tag[i]=0
		end
    end
	table.remove(tag,0)
    --DEBUG(sprintf("qianxian end %O",tag));    
    return tag
end

--获得tag中的所有法术牌
function target.get_fashu( tag)
    local pos,i,size
	table.remove(tag,0)
    --DEBUG(sprintf("qianxian begin %O",tag));
    size = #tag   
    for i = 1,size do
        if(tag[i].type~=define_battle.FASHU_KA) then
            tag[i]=0
		end
    end
	table.remove(tag,0)
    --DEBUG(sprintf("get_fashu end %O",tag));        
    return tag
end

function target.get_sjfashu( tag)
    local pos,i,size
	table.remove(tag,0)
    --DEBUG(sprintf("qianxian begin %O",tag));
    size = #tag   
    for i = 1,size do
        if(tag[i].type~=define_battle.SHUNJIAN_KA) then
            tag[i]=0
		end
    end
	table.remove(tag,0)
    --DEBUG(sprintf("get_fashu end %O",tag));        
    return tag
end


function target.get_gongshi( tag)
    local pos,i,size
	table.remove(tag,0)
    --DEBUG(sprintf("qianxian begin %O",tag));
    size = #tag   
    for i = 1,size do
        if(tag[i].type~=define_battle.JIEJIE_KA) then
            tag[i]=0
		end
    end
	table.remove(tag,0)
    --DEBUG(sprintf("get_fashu end %O",tag));        
    return tag
end

--对阵
function target.duizhen( tag,card)
    local pos,i,size
    pos = card.pos%6;
	table.remove(tag,0)
    size = sizeof(tag)   
    size = #tag   
    for i = 1,size do
        if((tag[i].pos%6)~=pos) then
			tag[i]=0
		end
    end
	table.remove(tag,0)
    return tag
end
return target