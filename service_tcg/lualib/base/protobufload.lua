local skynet = require "skynet"
local protobuf = require "protobuf"
local protobufload = {}

local m_instance = nil

function protobufload.get_protobuf()
    if  _G.protobuf == nil then
       protobufload.initload(protobuf)
       _G.protobuf = protobuf
    end
    return _G.protobuf
end

function protobufload.inst()
	-- body
	if(_G.protobufload == nil) then
		--setmetatable(protobufload,{__index=protobufload})--设置s 的 __index 为Student
	    _G.protobufload = protobufload
	    protobufload.initload(protobuf)
	end
	return _G.protobufload
end

function protobufload.encode(CObj, message_type, t)
    return protobuf.encode(CObj, message_type, t)
end

function protobufload.decode(message , buffer, length)
    return protobuf.decode(message , buffer, length)
end

function protobufload.loadpb(pro,name)
--    local player_data = io.open("../res/talkbox.pb","rb")
--    local buffer = player_data:read "*a"
--    player_data:close()
--    protobuf.register(buffer)
--这个函数用字符串 mode 指定的模式打开一个文件。 返回新的文件句柄。 当出错时，返回 nil 加错误消息。
    local player_data = io.open("../res/"..name,"rb")
    print("open:".."../res/"..name)
	-- 从当前位置开始读取整个文件。 如果已在文件末尾，返回空串。
    local buffer = player_data:read "*a"
    player_data:close()
	--print("buffer:"..buffer)
    protobuf.register(buffer)
end

function protobufload.initload(pro)
    print("protobufload begin ........")
    protobufload.loadpb(pro,"login.pb")
    protobufload.loadpb(pro,"game.pb")
    protobufload.loadpb(pro,"users.pb")
    print("protobufload end ........")
end

return protobufload

