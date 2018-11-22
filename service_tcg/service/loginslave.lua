local skynet = require "skynet"
local socket = require "socket"
local p=require "p.core"
local syslog = require "syslog"
local protoloader = require "protoloader"
local srp = require "srp"
local aes = require "aes"
local uuid = require "uuid"
local netpack = require "netpack"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
require("struct.globle")
local traceback = debug.traceback
local master
local database
local host
local auth_timeout
local session_expire_time
local session_expire_time_in_second
local connection = {}
local saved_session = {}
local slaved = {}
local CMD = {}
local SOCKET = {}
--
function CMD.init (m, id, conf)
	--syslog.noticef ("loginslave CMD.init m:%s, id:%s, conf:%s",m, id, conf)
	master = m
	--database = skynet.uniqueservice ("database")
	host = protoloader.load (protoloader.LOGIN)
	auth_timeout = conf.auth_timeout * 100
	session_expire_time = conf.session_expire_time * 100
	session_expire_time_in_second = conf.session_expire_time
end

local function close (fd)
	if connection[fd] then
		connection[fd] = nil	
		socket.close (fd)
	end
end

local function read (fd, size)
	return socket.read (fd, size) or nil
end

function unpackMessage(message,size)
    local version,messageId,msg  = string.unpack(">hiz",message)
    print("[LOG]","receive ok",version,messageId,msg)
    return size,version,messageId,msg

end

local function read_msg (fd)
    if socket.invalid(fd) then
        return nil
    end        
	local s = read (fd, 2)
	if s == nil then
	    return nil
	end	
	local size = s:byte(1) * 256 + s:byte(2)
		local msg = read (fd, size)
		if msg~=nil then
    		maxLen,version,messageId,msg = unpackMessage(msg)
    		return maxLen,version,messageId,msg
		else
		    return nil
		end	
end



local function send_msg (fd, msg)
	local package = string.pack (">s2", msg)
	socket.write (fd, package)
end

local function analyse(fd)
    local mysqlserver = skynet.localname(".mysqlserver")
	while true do
        if connection[fd]==nil then
            return nil
        end  
        local maxLen,version,messageId,msg = read_msg (fd)
        if messageId == 1003 then
            local pload = protobufload.inst()   
            local login_create = pload.decode("login.login_create",msg)		
    		print_r(login_create)
        	local sql = "select * from name_list where player_name=\""..login_create.name.."\""
        	logstat.log_day("sql","sql:"..sql.."\n")
        	local ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
        	print_r(ret)
    		if ret[1]== nil then 
    			sql = "INSERT INTO name_list (player_name, player_account,) VALUES ('"..login_create.account.."', '"..login_create.account.."')"
    			local ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
    		else
    			print("role"..ret[1]["role_id"]..ret[1]["player_name"]..ret[1]["player_account"])
    			
    		end
    		break
        elseif messageId == 1004 then
            local pload = protobufload.inst() 
            local login_create = pload.decode("login.login_enter",msg)		
    		print("[LOG]","receive ok",version,messageId,msg)
    		print_r(login_create)
        	local sql = "select * from name_list where player_name=\""..login_create.account.."\""
        	logstat.log_day("sql","sql:"..sql.."\n")
        	local ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
        	print_r(ret)
    		if ret[1]== nil then 
    			 print("not role")
    			 sql = "INSERT INTO name_list (player_name, player_account,) VALUES ('"..login_create.account.."', '"..login_create.account.."')"
    			 local ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
    		else
    			 print("role"..ret[1]["role_id"]..ret[1]["player_name"]..ret[1]["player_account"])
    		end	
    		local pload = protobufload.inst() 
    		local login_server = pload.encode("login.login_server",{
    							  ip = "192.168.1.182",
    							  port = 9555,
    							  account = msg.account;
    							  password = msg.password;
    							})
    		socket.write(fd, netpack.pack(p.pack(1,1006,login_server)))
    	end   
	end --while true do
end

function CMD.auth (fd, addr)
	syslog.noticef ("loginslave CMD.auth fd:%s, addr:%s",fd, addr)
	connection[fd] = addr
	skynet.timeout (auth_timeout, function ()
		if connection[fd] == addr then
			syslog.warningf ("connection %d from %s auth timeout!", fd, addr)
			close (fd)
		end
	end)

--socket.start(id , accept) accept 是一个函数。
--每当一个监听的 id 对应的 socket 上有连接接入的时候，
--都会调用 accept 函数。这个函数会得到接入连接的 id 以及 ip 地址。
--你可以做后续操作。
	socket.start (fd)
	socket.limit (fd, 8192)
--REQUEST:第一个返回值为"REQUEST"时,表示这是一个远程请求,
--如果请求包中没有session字段,表示该请求不需要回应,
--这时,第2和第3个返回值分别为消息类型名(即在sproto定义中提到的某个以.开头的类型名),
--以及消息内容(通常是一个table);
    table.insert (SOCKET, fd)
    analyse(fd)
    close(fd)
    syslog.warningf ("auth end!")
end


skynet.start (function ()
	skynet.dispatch ("lua", function (_, _, command, ...)
		local function pret (ok, ...)
			if not ok then 
				syslog.warningf (...)
				skynet.ret ()
			else
				skynet.retpack (...)
			end
		end
		local f = assert (CMD[command])
		pret (xpcall (f, traceback, ...))
	end)  

end)

