--路径3rd\skynet\lualib\sprotoparser.lua
local parser = require "sprotoparser"
--sproto.so : lualib-src/sproto/sproto.c lualib-src/sproto/lsproto.c
local core = require "sproto.core"
--路径\3rd\skynet\lualib\sproto.lua
local sproto = require "sproto"

local loader = {}

function loader.register(filename, index)
    --print("filename:"..filename.."index:"..index)
	local f = assert(io.open(filename), "Can't open sproto file")
	local data = f:read "a"
	f:close()
	local sp = core.newproto(parser.parse(data))
	core.saveproto(sp, index)
end
--bin 协议定义字符串
--index 对应协议编号
function loader.save(bin, index)
	local sp = core.newproto(bin)
	core.saveproto(sp, index)
end



function loader.load(index)
    --print("loader.load index:"..index)
	local sp = core.loadproto(index)
	--  no __gc in metatable
	return sproto.sharenew(sp)
end

return loader

