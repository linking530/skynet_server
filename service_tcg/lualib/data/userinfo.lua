local logstat = require "base.logstat"
require "struct.globle"
require "base.readconfig"
require "struct.globle"
--基本属性
local data_userinfo = {}
--经验表
local mpExp

local userinfo = {}

function userinfo.inst()
	-- body
	print("userinfo.inst")
	if(_G.userinfo == nil) then
		--setmetatable(protobufload,{__index=protobufload})--设置s 的 __index 为Student
	    _G.userinfo = userinfo
	    --userinfo.initload()
	end
	return _G.userinfo
end

function userinfo.get( id,  key)
    local mpTemp =_G.data_userinfo[id]
    if mpTemp == nil then
        return 0
    elseif mpTemp[key] == nil then
        return 0
    else
        return mpTemp[key]
    end
end

function userinfo.getMap( id )
    local mpTemp =_G.data_userinfo[id]
	return mpTemp
end

function userinfo.get_data_userinfo()
	return _G.data_userinfo
end

function userinfo.get_mpBase()
	return _G.mpBase
end

function userinfo.initload()
	print("userinfo.initload")
    data_userinfo = read_config("../res/cn/userinfo.txt",0)
    mpBase = read_config("../res/cn/base.txt",0)	
	return data_userinfo,mpBase
	--print_r("------------------------------------------------------")			
end

return userinfo

