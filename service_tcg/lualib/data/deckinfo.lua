local logstat = require "base.logstat"
require "struct.globle"
require "base.readconfig"
require "struct.globle"
local DEBUG_DECK_TABLE = function (table) logstat.log_file_r("deck.txt",table) end
-- <file srcFile = "µØÍ¼¹ÖÎïÅäÖÃ.xls" sheet= "Íæ¼ÒÌ×ÅÆ" dstFile = "comPlay.txt" />
-- <file srcFile = "µØÍ¼¹ÖÎïÅäÖÃ.xls" sheet= "µçÄÔÌ×ÅÆ" dstFile = "comNpc.txt" />
local deckinfo = {}
local comPlay
local comNpc
--Íæ¼ÒÌ×ÅÆ
local deckplay = {}
--µçÄÔÌ×ÅÆ
local decknpc = {}

function deckinfo.inst()
	-- body
	print("deckinfo.inst")
	if(_G.deckinfo == nil) then
		--setmetatable(protobufload,{__index=protobufload})--ÉèÖÃs µÄ __index ÎªStudent
	    _G.deckinfo = deckinfo
	    --deckinfo.initload()
	end
	return _G.deckinfo
end


function deckinfo.getdeckplay( id )
    local mpTemp =_G.deckplay[id]
	return mpTemp
end

function deckinfo.getdecknpc( id )
    local mpTemp =_G.decknpc[id]
	return mpTemp
end

function deckinfo.get_deck_play_copy( id )
	--print("deckinfo.get_deck_play_copy:"..id)
	--print(_G)
    local mpTemp =_G.deckplay[id]
	print_r(deckplay[id])
	print_r(mpTemp)
	return _G.deckplay[id]
end

function deckinfo.get_deck_npc_copy( id )
	--print("deckinfo.get_deck_npc_copy id:",id)
	--print("deckinfo.get_deck_npc_copy------------------------------")
	--print(_G)
	--print_r(_G.mpCmds[10001])
	--print_r(_G.decknpc[1])	
	--print("deckinfo.get_deck_npc_copy------------------------------")
    local mpTemp =_G.decknpc[id]
	return clone(mpTemp)
end

function deckinfo.init(com)
	local temp,i,result
	local deck = {}
	result = {}
	for k, v in pairs(com) do
		--print("comPlay:"..k)
		temp={}	
		temp.equip	= {}
		temp.common = {}
		for i=1, 3 do
			table.insert(temp.equip, v[i])
		end
		for i=4, #v do
			table.insert(temp.common, v[i])
		end
		result[k]=temp
	end
	return result
end

function deckinfo.get_deckplay()
	return _G.deckplay
end

function deckinfo.get_decknpc()
	return _G.decknpc
end

function deckinfo.initload()
	print("deckinfo.initload")
    comPlay = read_config("../res/cn/comPlay.txt",1)
    comNpc = read_config("../res/cn/comNpc.txt",1)	
	deckplay = deckinfo.init(comPlay)
	decknpc =  deckinfo.init(comNpc)
	return deckplay,decknpc
	--print_r("------------------------------------------------------")			
end

return deckinfo

