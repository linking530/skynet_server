local logstat = require "base.logstat"
require "struct.globle"
require "base.readconfig"

local carddata = {}
--卡表
local mpCards
local mpCmds
local card_skill

function carddata.inst()
	-- body
	print("carddata.inst")
	if(_G.carddata == nil) then
	    _G.carddata = carddata
	end
	return _G.carddata
end

function carddata.get_obj( id)
	--print("cards.get_obj:"..id)
    local mp,mpTemp
    if id<100000 then
        mp = _G.mpCmds
    else
        mp = _G.mpCards
    end
	--print_r(mp)
    mpTemp = mp[id]
    if mpTemp == nil then
        return 0
    else
		--print_r(mpTemp)
        return mpTemp
    end
end

function carddata.get( id,  key)
    local mp,mpTemp
    if id<100000 then
        mp = _G.mpCmds
    else
        mp = _G.mpCards
    end
    mpTemp = mp[id]
    if mpTemp == nil then
        return 0
    elseif mpTemp[key] == nil then
        return 0
    else
        return mpTemp[key]
    end
end

function carddata.get_mpCards()
    return _G.mpCards
end

function carddata.get_mpCmds()
    return _G.mpCmds
end

function carddata.initload()
	print("carddata.initload")
    mpCards = read_config("../res/cn/cards.txt",0)
    mpCmds = read_config("../res/cn/commander.txt",0)
	return mpCards,mpCmds
	--print_r(mpCards)
	--print_r("------------------------------------------------------")
	--print_r(mpCmds)
end

return carddata

