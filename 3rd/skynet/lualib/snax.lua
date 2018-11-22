local skynet = require "skynet"
local snax_interface = require "snax.interface"

local snax = {}
local typeclass = {}

local interface_g = skynet.getenv("snax_interface_g")
local G = interface_g and require (interface_g) or { require = function() end }
interface_g = nil

skynet.register_protocol {
	name = "snax",
	id = skynet.PTYPE_SNAX,
	pack = skynet.pack,
	unpack = skynet.unpack,
}


function snax.interface(name)
	if typeclass[name] then
		return typeclass[name]
	end

	local si = snax_interface(name, G)

	local ret = {
		name = name,
		accept = {},
		response = {},
		system = {},
	}

	for _,v in ipairs(si) do
		local id, group, name, f = table.unpack(v)
		ret[group][name] = id
	end

	typeclass[name] = ret
	return ret
end

local meta = { __tostring = function(v) return string.format("[%s:%x]", v.type, v.handle) end}

local skynet_send = skynet.send
local skynet_call = skynet.call

local function gen_post(type, handle)
	return setmetatable({} , {
		__index = function( t, k )
			local id = type.accept[k]
			if not id then
				error(string.format("post %s:%s no exist", type.name, k))
			end
			return function(...)
				skynet_send(handle, "snax", id, ...)
			end
		end })
end

local function gen_req(type, handle)
	return setmetatable({} , {
		__index = function( t, k )
			local id = type.response[k]
			if not id then
				error(string.format("request %s:%s no exist", type.name, k))
			end
			return function(...)
				return skynet_call(handle, "snax", id, ...)
			end
		end })
end

local function wrapper(handle, name, type)
	return setmetatable ({
		post = gen_post(type, handle),
		req = gen_req(type, handle),
		type = name,
		handle = handle,
		}, meta)
end

local handle_cache = setmetatable( {} , { __mode = "kv" } )

function snax.rawnewservice(name, ...)
	local t = snax.interface(name)
	local handle = skynet.newservice("snaxd", name)
	assert(handle_cache[handle] == nil)
	if t.system.init then
		skynet.call(handle, "snax", t.system.init, ...)
	end
	return handle
end

--把handle转换成服务对象。
--这里第二个参数需要传入服务的启动名，以用来了解这个服务有哪些远程方法可以供调用。
--当然，你也可以直接把 .type 域和 .handle 一起发送过去，而不必在源代码上约定。
function snax.bind(handle, type)
	local ret = handle_cache[handle]
	if ret then
		assert(ret.type == type)
		return ret
	end
	local t = snax.interface(type)
	ret = wrapper(handle, type, t)
	handle_cache[handle] = ret
	return ret
end

--可以把一个服务启动多份。传入服务名和参数，它会返回一个对象，用于和这个启动的服务交互。
--如果多次调用 newservice，即使名字相同，也会生成多份服务的实例，
--它们各自独立，由不同的对象区分。注意返回的不是服务地址，是一个对象。
function snax.newservice(name, ...)
	local handle = snax.rawnewservice(name, ...)
	return snax.bind(handle, name)
end

local function service_name(global, name, ...)
	if global == true then
		return name
	else
		return global
	end
end

--和上面 api 类似，但在一个节点上只会启动一份同名服务。如果你多次调用它，会返回相同的对象。
function snax.uniqueservice(name, ...)
	local handle = assert(skynet.call(".service", "lua", "LAUNCH", "snaxd", name, ...))
	return snax.bind(handle, name)
end

--和上面的 api 类似，但在整个 skynet 网络中（如果你启动了多个节点），只会有一个同名服务。
function snax.globalservice(name, ...)
	local handle = assert(skynet.call(".service", "lua", "GLAUNCH", "snaxd", name, ...))
	return snax.bind(handle, name)
end

--查询当前节点的具名服务，返回一个服务对象。如果服务尚未启动，那么一直阻塞等待它启动完毕。
function snax.queryservice(name)
	local handle = assert(skynet.call(".service", "lua", "QUERY", "snaxd", name))
	return snax.bind(handle, name)
end

--查询一个全局名字的服务，返回一个服务对象。如果服务尚未启动，那么一直阻塞等待它启动完毕。
function snax.queryglobal(name)
	local handle = assert(skynet.call(".service", "lua", "GQUERY", "snaxd", name))
	return snax.bind(handle, name)
end

--如果你想让一个 snax 服务退出，调用 
function snax.kill(obj, ...)
	local t = snax.interface(obj.type)
	skynet_call(obj.handle, "snax", t.system.exit, ...)
end

--用来获取自己这个服务对象,与skynet.self不同，它不是地址。
function snax.self()
	return snax.bind(skynet.self(), SERVICE_NAME)
end

--退出当前服务，它等价于 snax.kill(snax.self(), ...) 。
function snax.exit(...)
	snax.kill(snax.self(), ...)
end

local function test_result(ok, ...)
	if ok then
		return ...
	else
		error(...)
	end
end

function snax.hotfix(obj, source, ...)
	local t = snax.interface(obj.type)
	return test_result(skynet_call(obj.handle, "snax", t.system.hotfix, source, ...))
end

function snax.printf(fmt, ...)
	skynet.error(string.format(fmt, ...))
end

return snax
