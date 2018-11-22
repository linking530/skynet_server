local c = require "skynet.core"
local tostring = tostring
local tonumber = tonumber
local coroutine = coroutine
local assert = assert
local pairs = pairs
local pcall = pcall

local profile = require "profile"

local coroutine_resume = profile.resume
local coroutine_yield = profile.yield
-- proto[name] = class
-- proto[id] = class
local proto = {}
local skynet = {
	-- read skynet.h
	PTYPE_TEXT = 0,
	PTYPE_RESPONSE = 1,
	PTYPE_MULTICAST = 2,
	PTYPE_CLIENT = 3,
	PTYPE_SYSTEM = 4,
	PTYPE_HARBOR = 5,
	PTYPE_SOCKET = 6,
	PTYPE_ERROR = 7,
	PTYPE_QUEUE = 8,	-- used in deprecated mqueue, use skynet.queue instead
	PTYPE_DEBUG = 9,
	PTYPE_LUA = 10,
	PTYPE_SNAX = 11,
}

-- code cache
skynet.cache = require "skynet.codecache"

function skynet.print_r(table,str,r,k,n)
	local str =  str or ' '--�ָ����
	local n =  n or 0--�ָ��������
	local k =  k or ''--KEYֵ
	local r =  r or false--�Ƿ񷵻أ�����Ϊ��ӡ
	
	local tab = ''	
	local val_str = ''

	tab = string.rep(str,n)
	
	if type(table) == "table" then
		n=n+1
		val_str = val_str..tab..k.."={"		
		for k,v in pairs(table) do
			if type(v) == "table" then
				val_str = val_str.."\n"..print_r(v,str,true,k,n)
			else
				val_str = val_str..k..'='..tostring(v)..','
			end
		end
		if string.sub(val_str,-1,-1) == "," then
			val_str = string.sub(val_str,1,-2)
			val_str = val_str..' '.."}"
		else
			val_str = val_str.."\n"..tab..' '.."}"
		end
	else
		val_str = val_str..tab..k..tostring(table)
	end
	
	if r then
		return val_str
	else
		print(val_str)
	end
end

--ע��Э�飬Э��������ID���ַ�ʽ����
-- id= 
-- name= 
-- pack= 
-- unpack= 
-- dispatch= 
function skynet.register_protocol(class)
	local name = class.name
	local id = class.id
	assert(proto[name] == nil)
	assert(type(name) == "string" and type(id) == "number" and id >=0 and id <=255)
	proto[name] = class
	proto[id] = class
end

local session_id_coroutine = {}
local session_coroutine_id = {}
local session_coroutine_address = {}
local session_response = {}
local unresponse = {}

local wakeup_session = {}
local sleep_session = {}

local watching_service = {}
local watching_session = {}
local dead_service = {}
local error_queue = {}
local fork_queue = {}

-- suspend is function
local suspend

local function string_to_handle(str)
	return tonumber("0x" .. string.sub(str , 2))
end

----- monitor exit

local function dispatch_error_queue()
	local session = table.remove(error_queue,1)
	if session then
		local co = session_id_coroutine[session]
		session_id_coroutine[session] = nil
		return suspend(co, coroutine_resume(co, false))
	end
end

local function _error_dispatch(error_session, error_source)
	if error_session == 0 then
		-- service is down
		--  Don't remove from watching_service , because user may call dead service
		if watching_service[error_source] then
			dead_service[error_source] = true
		end
		for session, srv in pairs(watching_session) do
			if srv == error_source then
				table.insert(error_queue, session)
			end
		end
	else
		-- capture an error for error_session
		if watching_session[error_session] then
			table.insert(error_queue, error_session)
		end
	end
end

-- coroutine reuse
-- ��� coroutine ���������
local coroutine_pool = setmetatable({}, { __mode = "kv" })

local function co_create(f)
-- �ȴ�������ȡ�� coroutine ����������ɾ���ǽ�ֹ�� coroutine ��������Ϣʹ��
--pos Ĭ��Ϊ #list�� ��˵��� table.remove(l) ���Ƴ��� l �����һ��Ԫ�ء�
	local co = table.remove(coroutine_pool)
	if co == nil then
		co = coroutine.create(function(...)
			f(...)-- ִ�����Ǵ���ĺ���
			while true do
				-- ִ�������� coroutine 
				f = nil
				coroutine_pool[#coroutine_pool+1] = co
				-- �ó�ִ�У�֪ͨ main_thread ��Щ������
				-- coroutine �����Ѻ󣬴���������ĵ����з��ز���ֵ f Ϊ������Ҫִ�еĺ�����Ȼ�����ִ��
				f = coroutine_yield "EXIT"
				f(coroutine_yield())-- �����ٴε����ó���������Ϊ�˽��ղ������ݸ� f 
			end
		end)
	else
		coroutine_resume(co, f)-- ����һ�� coroutine ����������� f ��f ��������Ҫִ�еĺ���
	end
	return co
end

local function dispatch_wakeup()
	local co = next(wakeup_session)
	if co then
		wakeup_session[co] = nil
		local session = sleep_session[co]
		if session then
			session_id_coroutine[session] = "BREAK"
			return suspend(co, coroutine_resume(co, false, "BREAK"))
		end
	end
end

local function release_watching(address)
	local ref = watching_service[address]
	if ref then
		ref = ref - 1
		if ref > 0 then
			watching_service[address] = ref
		else
			watching_service[address] = nil
		end
	end
end

-- suspend is local function
function suspend(co, result, command, param, size)
	if not result then
		local session = session_coroutine_id[co]
		if session then -- coroutine may fork by others (session is nil)
			local addr = session_coroutine_address[co]
			if session ~= 0 then
				-- only call response error
				c.send(addr, skynet.PTYPE_ERROR, session, "")
			end
			session_coroutine_id[co] = nil
			session_coroutine_address[co] = nil
		end
		error(debug.traceback(co,tostring(command)))
	end
	if command == "CALL" then
		session_id_coroutine[param] = co
	elseif command == "SLEEP" then
		session_id_coroutine[param] = co
		sleep_session[co] = param
	elseif command == "RETURN" then
		local co_session = session_coroutine_id[co]
		local co_address = session_coroutine_address[co]
		if param == nil or session_response[co] then
			error(debug.traceback(co))
		end
		session_response[co] = true
		local ret
		if not dead_service[co_address] then
			ret = c.send(co_address, skynet.PTYPE_RESPONSE, co_session, param, size) ~= nil
			if not ret then
				-- If the package is too large, returns nil. so we should report error back
				c.send(co_address, skynet.PTYPE_ERROR, co_session, "")
			end
		elseif size ~= nil then
			c.trash(param, size)
			ret = false
		end
		return suspend(co, coroutine_resume(co, ret))
	elseif command == "RESPONSE" then
		local co_session = session_coroutine_id[co]
		local co_address = session_coroutine_address[co]
		if session_response[co] then
			error(debug.traceback(co))
		end
		local f = param
		local function response(ok, ...)
			if ok == "TEST" then
				if dead_service[co_address] then
					release_watching(co_address)
					unresponse[response] = nil
					f = false
					return false
				else
					return true
				end
			end
			if not f then
				if f == false then
					f = nil
					return false
				end
				error "Can't response more than once"
			end

			local ret
			if not dead_service[co_address] then
				if ok then
					ret = c.send(co_address, skynet.PTYPE_RESPONSE, co_session, f(...)) ~= nil
					if not ret then
						-- If the package is too large, returns false. so we should report error back
						c.send(co_address, skynet.PTYPE_ERROR, co_session, "")
					end
				else
					ret = c.send(co_address, skynet.PTYPE_ERROR, co_session, "") ~= nil
				end
			else
				ret = false
			end
			release_watching(co_address)
			unresponse[response] = nil
			f = nil
			return ret
		end
		watching_service[co_address] = watching_service[co_address] + 1
		session_response[co] = true
		unresponse[response] = true
		return suspend(co, coroutine_resume(co, response))
	elseif command == "EXIT" then
		-- coroutine exit
		local address = session_coroutine_address[co]
		release_watching(address)
		session_coroutine_id[co] = nil
		session_coroutine_address[co] = nil
		session_response[co] = nil
	elseif command == "QUIT" then
		-- service exit
		return
	elseif command == "USER" then
		-- See skynet.coutine for detail
		error("Call skynet.coroutine.yield out of skynet.coroutine.resume\n" .. debug.traceback(co))
	elseif command == nil then
		-- debug trace
		return
	else
		error("Unknown command : " .. command .. "\n" .. debug.traceback(co))
	end
	dispatch_wakeup()
	dispatch_error_queue()
end

--[[
�ÿ���� ti ����λʱ��󣬵��� func ���������
�ⲻ��һ������ API ����ǰ coroutine ������������У��� func ���������µ� coroutine ��ִ�С�
skynet �Ķ�ʱ��ʵ�ֵķǳ���Ч������һ�㲻��̫�����������⡣
�����������ķ��������ʹ�ö�ʱ���Ļ������Կ���һ�����õķ�����
����һ��service�����ֻʹ��һ�� skynet.timeout �������������Լ��Ķ�ʱ�¼�ģ�顣
�������Լ��ٴ����ӿ�ܷ��͵��������Ϣ�������Ͼ�һ��������ͬһ����λʱ���ܴ�����ⲿ��Ϣ���������޵ġ�
timeout û��ȡ���ӿڣ�������Ϊ����Լ򵥵ķ�װ�����ȡ����������

function cancelable_timeout(ti, func)
  local function cb()
    if func then
      func()
    end
  end
  local function cancel()
    func = nil
  end
  skynet.timeout(ti, cb)
  return cancel
end

local cancel = cancelable_timeout(ti, dosomething)
cancel()  -- canel dosomething
]]--
function skynet.timeout(ti, func)
	local session = c.intcommand("TIMEOUT",ti)
	assert(session)
	local co = co_create(func)
	assert(session_id_coroutine[session] == nil)
	session_id_coroutine[session] = co
end

-- ����ǰ coroutine ���� ti ����λʱ�䡣һ����λ�� 1/100 �롣
-- ��������ע��һ����ʱ��ʵ�ֵġ�
-- ��ܻ��� ti ʱ��󣬷���һ����ʱ����Ϣ��������� coroutine ��
-- ����һ������ API �����ķ���ֵ���������ʱ�䵽�ˣ����Ǳ� skynet.wakeup ���� ������ "BREAK"����
function skynet.sleep(ti)
	local session = c.intcommand("TIMEOUT",ti)
	assert(session)
	local succ, ret = coroutine_yield("SLEEP", session)
	sleep_session[coroutine.running()] = nil
	if succ then
		return
	end
	if ret == "BREAK" then
		return "BREAK"
	else
		error(ret)
	end
end

-- �൱�� skynet.sleep(0) ��������ǰ����� CPU �Ŀ���Ȩ��
-- ͨ���������������Ĳ�������û�л���������� API ʱ������ѡ����� yield ��ϵͳ�ܵĸ�ƽ����
function skynet.yield()
	return skynet.sleep(0)
end

--�ѵ�ǰ coroutine ����ͨ�����������Ҫ��� skynet.wakeup ʹ�á�
function skynet.wait(co)
	local session = c.genid()
	local ret, msg = coroutine_yield("SLEEP", session)
	co = co or coroutine.running()
	sleep_session[co] = nil
	session_id_coroutine[session] = nil
end

--���ص�ǰ�����handleID,�����ûע�����ע��(������skynet.register)
local self_handle
function skynet.self()
	if self_handle then
		return self_handle
	end
	self_handle = string_to_handle(c.command("REG"))
	return self_handle
end

function skynet.localname(name)
	local addr = c.command("QUERY", name)
	if addr then
		return string_to_handle(addr)
	end
end

-- ������ skynet �ڵ����������ʱ�䡣
-- �������ֵ����ֵ�������岻�󣬲�ͬ�ڵ���ͬһʱ��ȡ����ֵҲ����ͬ��
-- ֻ�����ε��õĲ�ֵ�������塣��������������ʱ�䡣ÿ 100 ��ʾ��ʵʱ�� 1 �롣
-- ��������Ŀ���С�ڲ�ѯϵͳʱ�ӡ���ͬһ��ʱ��Ƭ�����ֵ�ǲ���ġ�
-- (ע��:�����ʱ��Ƭ��ʾС��skynet�ڲ�ʱ�����ڵ�ʱ��Ƭ,
-- ����ִ���˱ȽϷ�ʱ�Ĳ����糬��ʱ���ѭ��,���ߵ������ⲿ����������,��os.execute('sleep 1'),
 -- ��ʹ�м�û��skynet������api����,���ε��õķ���ֵ���ǻ᲻ͬ��.)
skynet.now = c.now

local starttime

--���� skynet �ڵ���������� UTC ʱ�䣬����Ϊ��λ��
function skynet.starttime()
	if not starttime then
		starttime = c.intcommand("STARTTIME")
	end
	return starttime
end


--��������Ϊ��λ������ΪС�������λ���� UTC ʱ�䡣��ʱ���ϵȼ��ڣ�
function skynet.time()
	return skynet.now()/100 + (starttime or skynet.starttime())
end

function skynet.exit()
	fork_queue = {}	-- no fork coroutine can be execute after skynet.exit
	skynet.send(".launcher","lua","REMOVE",skynet.self(), false)
	-- report the sources that call me
	for co, session in pairs(session_coroutine_id) do
		local address = session_coroutine_address[co]
		if session~=0 and address then
			c.redirect(address, 0, skynet.PTYPE_ERROR, session, "")
		end
	end
	for resp in pairs(unresponse) do
		resp(false)
	end
	-- report the sources I call but haven't return
	local tmp = {}
	for session, address in pairs(watching_session) do
		tmp[address] = true
	end
	for address in pairs(tmp) do
		c.redirect(address, 0, skynet.PTYPE_ERROR, 0, "")
	end
	c.command("EXIT")
	-- quit service
	coroutine_yield "QUIT"
end

function skynet.getenv(key)
	return (c.command("GETENV",key))
end

function skynet.setenv(key, value)
	c.command("SETENV",key .. " " ..value)
end

function skynet.send(addr, typename, ...)
	local p = proto[typename]
	return c.send(addr, p.id, 0 , p.pack(...))
end

skynet.genid = assert(c.genid)

skynet.redirect = function(dest,source,typename,...)
	return c.redirect(dest, source, proto[typename].id, ...)
end

skynet.pack = assert(c.pack)
skynet.packstring = assert(c.packstring)
skynet.unpack = assert(c.unpack)
skynet.tostring = assert(c.tostring)
skynet.trash = assert(c.trash)

local function yield_call(service, session)
	watching_session[session] = service
	local succ, msg, sz = coroutine_yield("CALL", session)
	watching_session[session] = nil
	if not succ then
		error "call failed"
	end
	return msg,sz
end


function skynet.call(addr, typename, ...)
	--��proto["lua"] ,��Ϣ����id����msg��
	local p = proto[typename]
	--skynet.error(sprintf("skynet.call addr:%s typename:%s ",addr,typename))
	local session = c.send(addr, p.id , nil , p.pack(...))
	if session == nil then
		error("call to invalid address " .. skynet.address(addr))
	end
	--�ȴ�����
	return p.unpack(yield_call(addr, session))
end

function skynet.rawcall(addr, typename, msg, sz)
	local p = proto[typename]
	local session = assert(c.send(addr, p.id , nil , msg, sz), "call to invalid address")
	return yield_call(addr, session)
end

function skynet.ret(msg, sz)
	msg = msg or ""
	return coroutine_yield("RETURN", msg, sz)
end

function skynet.response(pack)
	pack = pack or skynet.pack
	return coroutine_yield("RESPONSE", pack)
end

function skynet.retpack(...)
	return skynet.ret(skynet.pack(...))
end

-- ����һ���� skynet.sleep �� skynet.wait ����� coroutine ��
-- �� 1.0 ���� wakeup ����֤����Ŀǰ�İ汾����Ա�֤��
function skynet.wakeup(co)
	if sleep_session[co] and wakeup_session[co] == nil then
		wakeup_session[co] = true
		return true
	end
end

function skynet.dispatch(typename, func)
	local p = proto[typename]
	if func then
		local ret = p.dispatch
		p.dispatch = func
		return ret
	else
		return p and p.dispatch
	end
end

local function unknown_request(session, address, msg, sz, prototype)
	skynet.error(string.format("Unknown request (%s): %s", prototype, c.tostring(msg,sz)))
	error(string.format("Unknown session : %d from %x", session, address))
end

function skynet.dispatch_unknown_request(unknown)
	local prev = unknown_request
	unknown_request = unknown
	return prev
end

local function unknown_response(session, address, msg, sz)
	skynet.error(string.format("Response message : %s" , c.tostring(msg,sz)))
	error(string.format("Unknown session : %d from %x", session, address))
end

function skynet.dispatch_unknown_response(unknown)
	local prev = unknown_response
	unknown_response = unknown
	return prev
end

-- �ӹ����ϣ����ȼ��� skynet.timeout(0, function() func(...) end) ���Ǳ� timeout ��Чһ�㡣
-- ��Ϊ��������Ҫ����ע��һ����ʱ����
function skynet.fork(func,...)
	local args = table.pack(...)
	local co = co_create(function()
		func(table.unpack(args,1,args.n))
	end)
	table.insert(fork_queue, co)
	return co
end

local function raw_dispatch_message(prototype, msg, sz, session, source)
	-- skynet.PTYPE_RESPONSE = 1, read skynet.h
	if prototype == 1 then
		local co = session_id_coroutine[session]
		if co == "BREAK" then
			session_id_coroutine[session] = nil
		elseif co == nil then
			unknown_response(session, source, msg, sz)
		else
			session_id_coroutine[session] = nil
			suspend(co, coroutine_resume(co, true, msg, sz))
		end
	else
		local p = proto[prototype]
		if p == nil then
			if session ~= 0 then
				c.send(source, skynet.PTYPE_ERROR, session, "")
			else
				unknown_request(session, source, msg, sz, prototype)
			end
			return
		end
		local f = p.dispatch
		if f then
			local ref = watching_service[source]
			if ref then
				watching_service[source] = ref + 1
			else
				watching_service[source] = 1
			end
			local co = co_create(f)
			session_coroutine_id[co] = session
			session_coroutine_address[co] = source
			suspend(co, coroutine_resume(co, session,source, p.unpack(msg,sz)))
		else
			unknown_request(session, source, msg, sz, proto[prototype].name)
		end
	end
end

function skynet.dispatch_message(...)
	local succ, err = pcall(raw_dispatch_message,...)
	while true do
		local key,co = next(fork_queue)
		if co == nil then
			break
		end
		fork_queue[key] = nil
		local fork_succ, fork_err = pcall(suspend,co,coroutine_resume(co))
		if not fork_succ then
			if succ then
				succ = false
				err = tostring(fork_err)
			else
				err = tostring(err) .. "\n" .. tostring(fork_err)
			end
		end
	end
	assert(succ, tostring(err))
end

-- ����lua���� skynet.rawcall(".launcher", "lua" , skynet.pack("LAUNCH", "snlua", name, ...))
-- ��ʵ��skynet_context_new(module_name("snlua"), param("cmaster"))
-- ������snlua������һ��lua�߼���(service/cmaster.lua),snlua������һ��lua������ɳ��
-- ����service/launch.lua�������⣬����lua����һ�㶼����service/launch.lua���lua�����𴴽���
-- ��Ȼ��launch�����ջ��ǵ��õ�skynet.launch("snlua","xxx")����������
function skynet.newservice(name, ...)
	return skynet.call(".launcher", "lua" , "LAUNCH", "snlua", name, ...)
end


--����һ��Ψһ�ķ��񣬵��ö��service/***.luaҲֻ��һ��ʵ��������clusterd��multicastd
function skynet.uniqueservice(global, ...)
	if global == true then
		return assert(skynet.call(".service", "lua", "GLAUNCH", ...))
	else
		return assert(skynet.call(".service", "lua", "LAUNCH", global, ...))
	end
end

--�����û�д�����Ŀ�������һֱ����ȥ��ֱ��Ŀ�����(�������񴥷���)����
function skynet.queryservice(global, ...)
	if global == true then
		return assert(skynet.call(".service", "lua", "GQUERY", ...))
	else
		return assert(skynet.call(".service", "lua", "QUERY", global, ...))
	end
end


--return "addr(ctx��handleID����name)��Ӧ��name(string,:%x�����Զ�����)" 
function skynet.address(addr)
	if type(addr) == "number" then
		return string.format(":%08x",addr)
	else
		return tostring(addr)
	end
end

--return ��addr(ctx��handleID)��Ӧ��harborID",boolean(�Ƿ�Զ�˽ڵ�)
function skynet.harbor(addr)
	return c.harbor(addr)
end

skynet.error = c.error

----- register protocol
do
	local REG = skynet.register_protocol

	REG {
		name = "lua",
		id = skynet.PTYPE_LUA,
		pack = skynet.pack,
		unpack = skynet.unpack,
	}

	REG {
		name = "response",
		id = skynet.PTYPE_RESPONSE,
	}

	REG {
		name = "error",
		id = skynet.PTYPE_ERROR,
		unpack = function(...) return ... end,
		dispatch = _error_dispatch,
	}
end

local init_func = {}

function skynet.init(f, name)
	assert(type(f) == "function")
	if init_func == nil then
		f()
	else
		table.insert(init_func, f)
		if name then
			assert(type(name) == "string")
			assert(init_func[name] == nil)
			init_func[name] = f
		end
	end
end

local function init_all()
	local funcs = init_func
	init_func = nil
	if funcs then
		for _,f in ipairs(funcs) do
			f()
		end
	end
end

local function ret(f, ...)
	f()
	return ...
end

local function init_template(start, ...)
	init_all()
	init_func = {}
	return ret(init_all, start(...))
end

function skynet.pcall(start, ...)
	return xpcall(init_template, debug.traceback, start, ...)
end

function skynet.init_service(start)
	local ok, err = skynet.pcall(start)
	if not ok then
		skynet.error("init service failed: " .. tostring(err))
		skynet.send(".launcher","lua", "ERROR")
		skynet.exit()
	else
		skynet.send(".launcher","lua", "LAUNCHOK")
	end
end
--[[
ÿ�� skynet ���񶼱�����һ��������������һ�����ͨ Lua �ű���ͬ��
��ͳ�� Lua �ű���û��ר�ŵ����������ű���������������
�� skynet ����������������� skynet.start(function() ... end) ��

skynet.start ע��һ������Ϊ������������������
��Ȼ�㻹�ǿ����ڽű�������дһ�� Lua ���룬���ǻ����� start ����ִ�С�
���ǣ���Ҫ��������� skynet ������ API ����Ϊ��ܽ��޷��������ǡ�

��������� skynet.start ע��ĺ���֮ǰ����ʲô�����Ե��� skynet.init(function() ... end) ��
��ͨ������ lua ��ı�д��
����Ҫ��д�ķ���������Ŀ��ʱ�����ȵ���һЩ skynet ���� API ��
�Ϳ����� skynet.init ����Щ����ע���� start ֮ǰ��
]]--
function skynet.start(start_func)
	c.callback(skynet.dispatch_message)
	skynet.timeout(0, function()
		skynet.init_service(start_func)
	end)
end

function skynet.endless()
	return c.command("ENDLESS")~=nil
end

function skynet.mqlen()
	return c.intcommand "MQLEN"
end

function skynet.task(ret)
	local t = 0
	for session,co in pairs(session_id_coroutine) do
		if ret then
			ret[session] = debug.traceback(co)
		end
		t = t + 1
	end
	return t
end

function skynet.term(service)
	return _error_dispatch(0, service)
end

function skynet.memlimit(bytes)
	debug.getregistry().memlimit = bytes
	skynet.memlimit = nil	-- set only once
end

-- Inject internal debug framework
local debug = require "skynet.debug"
debug.init(skynet, {
	dispatch = skynet.dispatch_message,
	suspend = suspend,
})

return skynet
