local logstat = require "base.logstat"
require "struct.globle"
require "base.readconfig"
require "struct.globle"
local carddata = require "data.carddata"

local skilldata = {}

function skilldata.inst()
	-- body
	print("skilldata.inst")
	if(_G.skilldata == nil) then
		--setmetatable(protobufload,{__index=protobufload})--设置s 的 __index 为Student
	    _G.skilldata = skilldata
		_G.card_skill = {}
	    --skilldata.initload()
	end
	return _G.skilldata
end

function skilldata.check_skill_trigger( card,  condition, reArr )
    local i, con
	if reArr==nil then reArr = {} end
	if card==nil or card==0 then return end
	for k, v in ipairs( card.mpStates ) do 
		--print( k .. ":" .. v )
		if v["t"]>=1 then
			con = skilldata.get_skl_by_string(k,"condition") 
            if( condition == con ) then
				reArr[k]=1
			end
		end
	end
    return reArr
end

function skilldata.check_skill_trigger2(card_id, condition)
	local i, j,sidArr, size, con,reArr,v
	reArr = {}
	--print("skilldata.check_skill_trigger2 card_id:"..card_id..",".."condition:"..condition)
	sidArr = skilldata.get_skill(card_id)
	if sidArr==0 then  return reArr end
	size = #sidArr
	for i = 1,size do
		con = skilldata.get_skl_by_string(sidArr[i],"condition")
		--print("con:",con)
		if( condition == con ) then
			v = sidArr[i]
			--print("v:"..v)
			reArr[v]=1
		end
	end
	return reArr
end

--根据技能id获得技能数据块
function skilldata.get_skl_by_id(  id )
	id = tonumber(id)
--	print_r(_G.mpSkill)
    return _G.mpSkill[id]
end

function skilldata.get_skl_by_string(id,  key)
    local mp
	id = tonumber(id)	
	--print("skilldata.get_skl_by_string:"..id..","..key)
    mp = skilldata.get_skl_by_id(id)
	-- if(mp~=0) then
		-- print_r(mp)
	-- else
		-- print(mp)
	-- end
    if mp == nil then
		return nil
	end
    return mp[key]
end

function skilldata.get_skill(id)
	id = tonumber(id)
	local arr,i
	local strArr,str
	if _G.card_skill == nil then
		_G.card_skill ={}
	end
	arr = {}
	if _G.card_skill[id]~=nil then
		return _G.card_skill[id]
	end
	if id == nil then 
		return {}
	end
	--print("get_skill id:"..id)
	str =  carddata.get(id,"skill_id")
	--print("carddata.get,"..id..","..str)
	if str ==nil or str==0 then
		return {}
	end
   strArr = explode(str,",")
   for i = 1, #strArr do
			for j=1,#arr do
				if arr[j]==strArr[i] then return end
			end
			table.insert(arr,strArr[i])		
   end   
   _G.card_skill[id] = arr
   --print(arr)
   return arr
end

function skilldata.has_skill(card_id,num)
    local i, sidArr, size;
	card_id = tonumber(card_id)
    sidArr = skilldata.get_skill(card_id)
	if sidArr==nil or sidArr==0 then
		--print("skilldata.has_skill card_id:"..card_id.."num:".. num)
		return 0
	end
	
    for i = 1,#sidArr,1 do
        if( sidArr[i] == num ) then
            return 1
		end
    end 
    return 0
end

function skilldata.initload()
	print("skilldata.initload")
    mpSkill = read_config("../res/cn/skill.txt",0)
	--print_r(mpSkill[1000011])
	return mpSkill
	--print_r("------------------------------------------------------")		
end

return skilldata

