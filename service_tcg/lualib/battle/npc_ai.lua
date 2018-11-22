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
local DEBUG = function (...) logstat.log_file2("battle.txt",...) end
local DEBUG_MOVE = function (...) logstat.log_file2("move.txt",...) end
local DEBUG_MOVE_TABLE = function (table) logstat.log_file_r("move.txt",table) end
local DEBUG_TABLE = function (table) logstat.log_file_r("battle.txt",table) end
local npc_ai = {}

function npc_ai.battle_next( war,  status)

end

function npc_ai.getUser(war)
    local card = {}

	card.mData={}
	card.mData.ID = 0
	card.ctype = 6
	card.mPos = 0

    return card
end

function npc_ai.getTargeEmpty(war)
    local posArr = npc_ai.getEmptyPos(war)
    if posArr[1]~=nil then
        card.targets = {}
        card.targets.mData={}
        card.targets.mData.ID = 0
        card.ctype = 1
        card.mPos = posArr[1]
    else
        card = {}
        card.targets={}
        card.mData={}
        card.mData.ID = 0
        card.ctype = 0
        card.mPos = 0
    end
end

function npc_ai.getEmptyPos(war)
    local posArr = {}
    local i_begin,i_end
    local BattleCardList = war2CardManager:getBattleCardList()
    if isMain == false then
        i_begin = 1
        i_end = 6
    else
        i_begin = 13
        i_end = 18
    end
    for pos=i_begin,i_end do
        if BattleCardList[pos] == nil then
            table.insert(posArr,pos)
        end
    end   
    return posArr
end

function npc_ai.getFullPos(war)
    local posArr = {}
    local i_begin,i_end
    local BattleCardList = war2CardManager:getBattleCardList()
    if isMain == false then
        i_begin = 1
        i_end = 12
    else
        i_begin = 7
        i_end = 18
    end
    for pos=i_begin,i_end do
        if BattleCardList[pos] ~= nil then
            table.insert(posArr,pos)
        end
    end     
    return pos
end


--1：优先选择敌方生命值最低的生物为目标，若无，则随机选择敌方一个生物为目标；
function npc_ai.getLowHp(war)
    local BattleCardList
     
    BattleCardList = war2CardManager:getBattleCardList()

    local card = nil
    local curhp = 10000
    for pos=1,18 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mData.curHealth <curhp)  and (BattleCardList[pos].mIsMain~= isMain) then
                card = BattleCardList[pos]
            end
        end
    end
    return card
end

--2：优先选择己方已受伤的随从或英雄为目标，如果同时有多个目标，则选择生命值最低的一个，如果条件相同则随机选择。没有符合条件的目标则指定为己方英雄；
function npc_ai.getHurtLowHp(war)
    local BattleCardList = war2CardManager:getBattleCardList()
    local card=nil
    local curhp=1000
    for pos=1,18 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mData.curHealth~= BattleCardList[pos].mData.health ) and  (BattleCardList[pos].mData.curHealth < curhp)  and (BattleCardList[pos].mIsMain~= isMain)then
                card = BattleCardList[pos]
            end
        end
    end
    if card~=nil then
        card.ctype = 7
        return card
    else
        return warAi:getUser(war)
    end
end


--4：优先己方随机一个随从，如果没有则全场随机。
function npc_ai.getBattle(war)
    local result = {}
     
    BattleCardList = war2CardManager:getBattleCardList()

    local card = nil
    local curhp = 10000
    for pos=1,18 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mIsMain == isMain) then
                card = BattleCardList[pos]                 
                talbe.insert(result,card)
            end
        end
    end
    pos = math.random(1,#result)
    if(result[pos]~=nil) then
        return result[pos]
    end

end

--5：优先选择敌方生命值最低的生物/英雄为目标，如果同时有多个目标，如果条件相同则随机选择。没有符合条件的目标则指定为敌方英雄；
function npc_ai.getLowHp_Hero(war)
    local BattleCardList
     
    BattleCardList = war2CardManager:getBattleCardList()

    local card = nil
    local curhp = 10000
    for pos=1,18 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mData.curHealth <curhp)  and (BattleCardList[pos].mIsMain~= isMain) then
                card = BattleCardList[pos]
            end
        end
    end
    if card ~= nil then
        return card
    else
        return warAi:getUser(war)
    end
end

--6：优先选择敌方带有buff效果的随从，如果没有则随机敌方任一选择。
function npc_ai.getBattle2(war)
    local result = {}
     
    BattleCardList = war2CardManager:getBattleCardList()

    local card = nil
    local curhp = 10000
    for pos=1,18 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mIsMain ~= isMain) then
                card = BattleCardList[pos]                 
                talbe.insert(result,card)
            end
        end
    end
    pos = math.random(1,#result)
    if(result[pos]~=nil) then
        return result[pos]
    end

    result = {}
    for pos=1,18 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mIsMain ~= isMain) then
                card = BattleCardList[pos]                 
                talbe.insert(result,card)
            end
        end
    end

    pos = math.random(1,#result)
    if(result[pos]~=nil) then
        return result[pos]
    else
        return nil
    end
end

--8：优先选择敌方生命值最高的生物为目标，若无，则随机选择敌方一个生物；
function npc_ai.getHurtHighHp(war)
    local BattleCardList = war2CardManager:getBattleCardList()
    local card=nil
    local curhp=0
    for pos=1,18 do
        if BattleCardList[pos] ~= nil then
            if  (BattleCardList[pos].mData.curHealth > curhp)  and (BattleCardList[pos].mIsMain~= isMain)then
                card = BattleCardList[pos]
            end
        end
    end
    if card~=nil then
        card.ctype = 7
        return card
    else
        return nil
    end
end
--9：优先选择前线上的敌方生物，若无则选择敌方防御区域的生物。
function npc_ai.getBattle3(war)
    local BattleCardList = war2CardManager:getBattleCardList()
    local card=nil
    local curhp=0
    for pos=7,12 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mIsMain~= isMain) then
                card = BattleCardList[pos]
            end
        end
    end

    for pos=1,6 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mIsMain~= isMain) then
                card = BattleCardList[pos]
            end
        end
    end

    for pos=13,18 do
        if BattleCardList[pos] ~= nil then
            if (BattleCardList[pos].mIsMain~= isMain) then
                card = BattleCardList[pos]
            end
        end
    end

    if card~=nil then
        card.ctype = 7
        return card
    else
        return nil
    end
end

function npc_ai.getTargetAI1(war,mtype)
    local card
    if mtype == 1 then
        card =  warAi:getLowHp(isMain)
    elseif mtype == 2 then
        card =  warAi:getHurtLowHp(isMain)
    elseif mtype == 3 then
        card = warAi:getTargeEmpty(isMain)
    elseif mtype == 4 then
        card = warAi:getBattle(isMain)
    elseif mtype == 5 then
        card = warAi:getLowHp_Hero(isMain)
    elseif mtype == 6 then
        card = warAi:getBattle2(isMain)
    elseif mtype == 8 then
        card = warAi:getHurtHighHp(isMain)
    elseif mtype == 9 then
        card = warAi:getBattle3(isMain)
    else 
        --print("getTargetAI1 no  type:"..type)

    end
    if card==nil then
        card = {}
        card.targets={}
        card.mData={}
        card.mData.ID = 0
        card.ctype = 0
        card.mPos = 0
    end
    return card
end

--使用手牌 type "ATK_PRI" "DEF_PRI"
function npc_ai.UseHand(war, npc, mtype )
    local handCard
    local i,id,obj,temp
    local aiHandCard = {};
    local pos,posArr
    local card = nil

    handCard = war2CardManager:getMainHandCardList()

    local handstrTab = {}

    for i = 1, #handCard do

        id = handCard[i]["id"]
        table.insert(handstrTab,id)
        obj = DataManager:getCardObjByID(id)
        temp = id+obj[mtype]*1000000+math.random(1,9)*100000
        if temp > id then
            id = temp
            card = handCard[i]
        end
        
    end
    print("handstrTab:"..table.concat(handstrTab, ",").."\n")
    if card == nil then
        return false
    end

    obj = DataManager:getCardObjByID(card["id"])
    if  obj["cost"] > war2CardManager.mOtherCandUseRes  then
        warAi:SMTWarSacrifice(isMain,card)
        return false
    else--使用卡牌
        if obj["type"] == 1 then --使用生物卡
            posArr = warAi:getEmptyPos(isMain)
            if posArr[1]~=nil then
                warAi:SMTWarMov(isMain, card["id"], 1, card["pos"], 7, posArr[1] )
            end
        elseif obj["type"] == 2 then --结界卡
            posArr = warAi:getFullPos(isMain)
            if posArr[1]~=nil then
                warAi:SMTWarMov(isMain, card["id"], 1, card["pos"], 7, posArr[1] )
            end
        elseif obj["type"] == 3 then --法术卡
            local targets = warAi:getTargetAI1(isMain,card["AiTar1"])
            warAi:SMTWarOrder(isMain, card["id"], 1, card["pos"], targets.mData.ID, targets.ctype, targets.mPos )
        elseif obj["type"] == 4 then --瞬间卡
            local targets = warAi:getTargetAI1(isMain,card["AiTar1"])
            warAi:SMTWarOrder(isMain, card["id"], 1, card["pos"], targets.mData.ID, targets.ctype, targets.mPos )
        end
        return true
    end

end

function npc_ai.canUseSkill(isMain,card)
        local skillArr = card.mData.skillList
        local t_cost
        for i = 1, #skillArr do
            if skillArr[i] ~= nil then
                local skillData = SkillManager:getSkillData(skillArr[i])
                if skillData ~= nil then
                    if skillData.condition	==30 or skillData.condition	==31 then
                        t_cost = warAi:getRes(isMain)
                        if  t_cost >= skillData.cost then
                            return true
                        end
                    end

                end
            end
        end
        return false
end


--使用战场生物技能
function npc_ai.UseFrontSkill(isMain)
    -- local BattleCardList = war2CardManager:getBattleCardList()
    -- local card=nil
    -- local curhp=0
    -- for pos=1,18 do
        -- if BattleCardList[pos] ~= nil then
            -- if BattleCardList[pos].mIsMain == isMain then
                -- card = BattleCardList[pos]
                -- local obj = DataManager:getCardObjByID(card.mData.ID)
                -- if warAi:canUseSkill(isMain,card) then
                    -- local targets = warAi:getTargetAI1(isMain,obj["AiTar1"])
                    -- warAi:SMTWarOrder(isMain, card.mData.ID, 1, card.mPos, targets.mData.ID, targets.ctype, targets.mPos )
                -- end
            -- end
        -- end
    -- end
end

function npc_ai.getSw(isMain)
local sw = nil
    if isMain==true then
        sw = war2CardManager:get_mMainEq()
    else
        sw = war2CardManager:get_mOtherEq()
    end
    return sw
end

--使用圣物技能
function npc_ai.UseSwSkill(war,npc)
    -- local sw = npc_ai.getSw(npc)
    -- local card=nil
    -- local curhp=0
    -- local obj=nil
    -- for pos=1,3 do
        -- if sw[pos] ~= nil then
            -- card = sw[pos]
            -- obj = DataManager:getEq(card.mData.ID)
            -- if warAi:canUseSkill(isMain,card) then
                -- local targets = warAi:getTargetAI1(isMain,obj["AiTar1"])
                -- warAi:SMTWarOrder(isMain, card.mData.ID, 4, pos, targets.mData.ID, targets.ctype, targets.mPos )
            -- end
        -- end
    -- end
end


--主回合使用级别	
function npc_ai.AttackUse(war,npc)
	
--a)使用手牌，不同卡牌的使用优先级别通过表格获得。

    npc_ai.UseHand(war,npc,"ATK_PRI")

--b)若未达到套牌费用要求，献祭一张费用不满足要求且费用最大的手牌

--c)使用生物的技能

	npc_ai.UseFrontSkill(war,npc)

--d)使用圣物技能
	npc_ai.UseSwSkill(war,npc)

end




return npc_ai