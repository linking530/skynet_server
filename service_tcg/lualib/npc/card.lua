local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core = require "p.core"
local battle_send = require "battle.battle_send"
local cards = require "data.carddata"
cards = cards.inst()
require "struct.globle"

local card = {}
local mt = { __index = card }

local function get_out_oid()
    if _G.card_oid==nil then
        _G.card_oid = 1
	end	
    if _G.card_oid>100000000 then
        _G.card_oid = 1
	end
    _G.card_oid= _G.card_oid+1
    return _G.card_oid
end


function card.new(war,player,cid)
    local o = {}   -- create object if user does not provide one
	setmetatable (o, mt)
	o:init(war,player,cid)	
	return o
end

function card:set_postype(value)
	self.postype = value
end

function card:get_postype()
	return postype
end

function card:set_mp( value )
	self.mp = value
end

function card:get_mp()
	return self.mp
end

function card:init(war,player,cid)
	self.war = war
	self.uid = player:get_userid()
	self.player = player
	self:set_id(cid)
	--init状态
    self.zz = 0
end

function card:set_oid(value)
	self.oid = value
end

function card:get_oid()
	return self.oid
end

function card:set_id(value)
    self.id = value --卡牌ID
	--print("card:"..value)
	local mp = cards.get_obj( value )
	--print_r(mp)
	
	self:set_mp( table_copy( mp ) )
	--print_r(mp)

    self.ap = mp["atk"]
    self.mhp = mp["health"]   
    self.hp = mp["health"]
	
    self.type = mp["type"]			--	种类
    self.skill_id = mp["skill_id"]	--	技能编号 
    self.zz = 0
	
    self.oid = get_out_oid()
	
    self.mpStates = {}
    self.mpBufStates = {}
	
    self.war:set_obj(self,self.oid)
	

    self.ap1 = 0
    self.ap2 = 0
    self.ap99 = 0

    self.hp1 = 0
    self.hp2 = 0
    self.hp99 = 0

    self.dp1 = 0
    self.dp2 = 0
    self.dp99 = 0

    self.mhp1 = 0
    self.mhp2 = 0
    self.mhp22 = 0
    self.mhp99 = 0
	
	if self.ap == nil then
		self.ap = 0
	end
	
end

function card:get_id()
	print(self.id)
    return self.id
end

function card:get_cid()
    return self.id
end

function card:set_pos(value)
	self.pos = value
end

function card:get_pos()
    return self.pos
end

function card:set_uid(value)
	self.uid = value
end

function card:get_uid()
    return self.uid
end

function card:get_zz()
    return self.zz
end

function card:set_zz(value)
    self.zz = value
	--print("self:get_hp()"..self:get_hp())
    battle_send.cards_info(self.war,self:get_pos(),self:get_hp(),self:get_mhp(),self:get_ap(),self:get_zz())    
end

function card:get_war()
    return self.war
end

function card:set_war(value)
    self.war = value
end

function card:set_player(value)
    self.player = value
end

function card:get_player()
    return self.player
end

function card:add_hp(mValue, times)

    local k = self:get_mhp( )-self:get_hp( )
    if mValue>k then
        mValue = k
	end	
    self.hp = self.hp+mValue
    return self.hp
end

function card:get_hp( )
    local i,j	
    i = self.hp + self.hp2
    
    if i<0 then
		i = 0
	end
	
    j = self:get_mhp()
    if i>j then
        self.hp = self.hp-i+j
        return j     
    end
    return i
end

function card:add_ap(mValue, times)
    local value	
    if times==1 then
        self.ap1 = self.ap1+i
    elseif times==-1 then --光环
        self.ap2 = self.ap2+i  
    else
        self.ap99 = self.ap99+i
	end
end

function card:get_ap( )
    local value;
    value = self.ap + self.ap1 + self.ap99 + self.ap2;
    if value<0 then
        value = 0
	end
    return value
end

function card:add_dp(mValue, times)
    local value
    if times==1 then
        self.dp1 = self.dp1+i
    elseif times==-1 then --光环
        self.dp2 = self.dp2+i  
    else
        self.dp99 = self.dp99+i
	end
end

function card:get_dp( )
    local value
    value = self.dp1 + self.dp99 + self.dp2
    if value<0 then
        value = 0
	end
    return value
end

function card:add_mhp( mValue, times )
    local value
    if times==1 then
        self.mhp1 = self.mhp1+i
    elseif times==-1 then		--光环
        self.mhp2 = self.mhp2+i
    else
        self.mhp99 = self.mhp99+i
	end
end

function card:get_mhp( )
    local value
    value = self.mhp + self.mhp1 + self.mhp99 + self.mhp2
    if value<0 then
        value = 0
	end
    return value
end

function card:addBuffStatus(  mType, value )
    if self.mpBufStates[mType] == nil then
		self.mpBufStates[mType] = {}
	end
	
	self.mpBufStates[mType][v] = value

end

function card:delBuffStatus(  mType )
    if self.mpBufStates[mType] == nil then
		return
	end        
    self.mpBufStates[mType] = nil;
end

function card:cleanBuffStatus(  )
    self.mpBufStates = {}
    if self.ap2 or self.hp2 or self.mhp2 or self.dp2 then
        self.ap2 = 0
        self.mhp22 = self.mhp2
        self.hp2 = 0
        self.mhp2 = 0
        self.dp2 = 0  
    end
end

function card:onTimeStatus( )
    local keys,i,size;
	
    for k,v in pairs(card.mpStates) do
	    if v["t"] <=1 then
	        card.mpStates[k]= nil
		else
	        v["t"] = v["t"] -1
		end	
    end		
	
	if self.ap1 or self.mhp1 or self.dp1 then
        self.ap1 = 0
        self.mhp1 = 0
        self.dp1 = 0	          
		battle_send.cards_info(self.war,self:get_pos(),self:get_hp(),self:get_mhp(),self:get_ap(),self:get_zz())    
    end
end

function card:addStatus( mType, value, times )
    if times==-1 then
        self:addBuffStatus(mType,value)
        return
    else
        if self.mpStates[mType]==nil then		
			self.mpStates[mType] = {}
		end
		self.mpStates[mType]["v"] = value
		self.mpStates[mType]["t"] = times
    end

end

function card:delStatus(  mType )
	if self.mpStates[mType]==nil then		
	 self.mpStates[mType] = {}
	end
    battle_send.cards_info(self.war,self:get_pos(),self:get_hp(),self:get_mhp(),self:get_ap(),self:get_zz())
    self.mpStates[mType] = nil
end

function card:resetStatus( )
    self.ap	= 0
    self.ap1 = 0
    self.ap2 = 0
    self.ap99 = 0
    self.hp = 0
    self.hp1 = 0
    self.hp2 = 0
    self.hp99 = 0
    self.dp = 0
    self.dp1 = 0
    self.dp2 = 0
    self.dp99 = 0
    self.mhp = 0
    self.mhp1 = 0
    self.mhp2 = 0
    self.mhp22 = 0
    self.mhp99 = 0	          
    self:set_id(self.cid)
end


function card:get_mhp2()
	return self.get_mhp2
end

function card:get_mhp22()
	return self.get_mhp22
end

function card:getStatus( mType )
    if self.mpStates[mType] == nil then
        if self.mpBufStates[mType] == nil then
            return 0
        else
            return self.mpBufStates[mType]["v"]
		end
    else
        if self.mpStates[mType] == nil then
            return 0
        else
            return self.mpStates[mType]["v"]
		end
	end
end
--sw 属于
function card:set_jj(i)
    local hp
    if((self.jj==0)and(i==0)) then return end
    if(card.jj~=0) then
        hp = self.jj.hp
        self.jj.sw=0
	end
    card.jj = i
    if i then
        i.sw = self
        i.pos = card.pos
        i.postype = define_battle.AREA_ZHANCHANG   
    end
    card.hp = card.hp+hp
    battle_ctrl.battle_next(self.war,define_battle.BATTLE_GUANGHUAN)
	battle_send.jiejie_mov(self.war,self.uid,self.oid,self.cid,self.pos,self.postype)
end

function card:get_jj()
    return self.jj
end

return card
