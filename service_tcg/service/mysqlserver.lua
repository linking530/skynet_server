local skynet = require "skynet.manager"
local mysql = require "mysql"
local config = require "config.mysql"
local logstat = require "base.logstat"

local db
local CMD = {}
local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

function CMD.sql(str)
    logstat.log_day("sql","CMD.sql:"..str.."\n")
    res = db:query(str)
    logstat.log_day("sql","CMD.sql:"..dump( res ).."\n")	
    return res
end


skynet.start(function()
	db=mysql.connect{
		host=config.host,
		port=config.port,
		database=config.db,
		user=config.user,
		password=config.password,
		max_packet_size = 1024 * 1024
	}
	if not db then
		print("failed to connect")
	end
	print("testmysql success to connect to mysql server")
	db:query("set names utf8")
	
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		if f then
			print("mysql.cmd:")
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("[.mysqlserver] can not find command %s", cmd))
		end
	end)
	skynet.name(".mysqlserver", skynet.self())
end)

