local skynet = require "skynet"
local c = require "skynet.core"

--启动一个 C 服务。
function skynet.launch(...)
	local addr = c.command("LAUNCH", table.concat({...}," "))
	if addr then
		return tonumber("0x" .. string.sub(addr , 2))
	end
end
--强行杀掉一个服务。
function skynet.kill(name)
	if type(name) == "number" then
		skynet.send(".launcher","lua","REMOVE",name, true)
		name = skynet.address(name)
	end
	c.command("KILL",name)
end

--退出 skynet 进程。
function skynet.abort()
	c.command("ABORT")
end

local function globalname(name, handle)
	local c = string.sub(name,1,1)
	assert(c ~= ':')
	if c == '.' then
		return false
	end

	assert(#name <= 16)	-- GLOBALNAME_LENGTH is 16, defined in skynet_harbor.h
	assert(tonumber(name) == nil)	-- global name can't be number

	local harbor = require "skynet.harbor"

	harbor.globalname(name, handle)

	return true
end

--给自身注册一个名字。
function skynet.register(name)
	if not globalname(name) then
		c.command("REG", name)
	end
end

--为一个服务命名。
function skynet.name(name, handle)
	if not globalname(name, handle) then
		c.command("NAME", name .. " " .. skynet.address(handle))
	end
end

local dispatch_message = skynet.dispatch_message
--将本服务实现为消息转发器，对一类消息进行转发。
function skynet.forward_type(map, start_func)
	c.callback(function(ptype, msg, sz, ...)
		local prototype = map[ptype]
		if prototype then
			dispatch_message(prototype, msg, sz, ...)
		else
			dispatch_message(ptype, msg, sz, ...)
			c.trash(msg, sz)
		end
	end, true)
	skynet.timeout(0, function()
		skynet.init_service(start_func)
	end)
end

--过滤消息再处理。（注：filter 可以将 type, msg, sz, session, source 五个参数先处理过再返回新的 5 个参数。）
function skynet.filter(f ,start_func)
	c.callback(function(...)
		dispatch_message(f(...))
	end)
	skynet.timeout(0, function()
		skynet.init_service(start_func)
	end)
end

--给当前 skynet 进程设置一个全局的服务监控。
function skynet.monitor(service, query)
	local monitor
	if query then
		monitor = skynet.queryservice(true, service)
	else
		monitor = skynet.uniqueservice(true, service)
	end
	assert(monitor, "Monitor launch failed")
	c.command("MONITOR", string.format(":%08x", monitor))
	return monitor
end

return skynet
