local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local p_core=require("p.core")
require("struct.globle")
local CMD = {}
local protobuf = {}
local auto_id=0
local talk_users={}
local client_fds={}

function CMD.login(client_fd,talk_create)

end

function CMD.sentMsg(talk_message)
	local message = protobuf.decode("talkbox.talk_message",talk_message)
	
	if message==false then
		return protobuf.encode("talkbox.talk_result",{id=3})--解析protocbuf错误
	end
	
	if message.touserid==-1 then
		for userid in pairs(client_fds) do
			socket.write(client_fds[userid], netpack.pack(p_core.pack(1,1010,talk_message)))
		end
	else
		socket.write(client_fds[message.touserid], netpack.pack(p_core.pack(1,1010,talk_message)))
	end
	
	return protobuf.encode("talkbox.talk_result",{id=4})
end

function CMD.getUsers(msg)
	local users={}
	for userid in pairs(talk_users) do
		table.insert(users,talk_users[userid])
	end
	
	return protobuf.encode("talkbox.talk_users",{['users']=users})
end

function CMD.rmUser(client_fd)
	for userid in pairs(client_fds) do
		
		if client_fds[userid]==client_fd then
			for userid2 in pairs(client_fds) do
				socket.write(client_fds[userid2], netpack.pack(p_core.pack(1,1011,protobuf.encode("talkbox.talk_result",{id=userid}))))
			end
			
			talk_users[userid]=nil
			client_fds[userid]=nil
			
		end
	end
end

function isUser(name)
	for userid in pairs(talk_users) do
		if talk_users[userid].name==name then
			return true
		end
	end

	return false
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		
		skynet.ret(skynet.pack(f(...)))
	end)
	
end)
