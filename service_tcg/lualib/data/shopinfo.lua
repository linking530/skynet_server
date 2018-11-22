local logstat = require "base.logstat"
require "struct.globle"
require "base.readconfig"
--基本属性
local data_shop = {}
local data_market = {}

local shopinfo = {}

function shopinfo.inst()
	-- body
	print("shopinfo.inst")
	if(_G.shopinfo == nil) then
		--setmetatable(protobufload,{__index=protobufload})--设置s 的 __index 为Student
	    _G.shopinfo = shopinfo
	    --shopinfo.initload()
	end
	return _G.shopinfo
end

function shopinfo.get( id,  key)
    local mpTemp =_G.data_shop[id]
    if mpTemp == nil then
        return 0
    elseif mpTemp[key] == nil then
        return 0
    else
        return mpTemp[key]
    end
end

function shopinfo.getMap( id )
    local mpTemp =_G.data_shop[id]
	return mpTemp
end

function shopinfo.get_data_shop()
	return _G.data_shop
end

function shopinfo.get_data_market()
	return _G.data_market
end


function shopinfo.initload()
	print("data_shop.initload")
    data_shop = read_config("../res/cn/shop.txt",1)
	data_market = read_config("../res/cn/market.txt",0)
	--print_r(data_shop)
	--print_r(data_market[100000])
	return data_shop,data_market
	--print_r("------------------------------------------------------")			
end

return shopinfo
