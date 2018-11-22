local skynet = require "skynet"

local config = require "config.system"

local logfile = {
	prefix = {
		"D|",
		"I|",
		"N|",
		"W|",
		"E|",
	},
}

local level
function logfile.level (lv)
	level = lv
end

local function write (file,priority, str)
	if priority >= level then
        local player_data = io.open(file,"a")
        player_data:write(str)
        player_data:close()
	end
end

local function writef (file,priority, ...)
	if priority >= level then
        local player_data = io.open(file,"a")
        local buffer = player_data:write(syslog.prefix[priority] .. string.format (...))
        player_data:close()
	end
end

function logfile.debug (file,str)
	write (file,1, str)
end

function logfile.debugf (file,...)
	writef (file,1, ...)
end

function logfile.info (file,str)
	write (file,2,str)
end

function logfile.infof (file,...)
	writef (file,2, ...)
end

function logfile.notice (file,str)
	write (file,3, str)
end

function logfile.noticef (...)
	writef (file,3, ...)
end

function logfile.warning (file,str)
	write (file,4,str)
end

function logfile.warningf (file,...)
	writef (file,4, ...)
end

function logfile.err (file,str)
	write (file,5,str)
end

function logfile.errf (...)
	writef (5, ...)
end

function logfile.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    syslog.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      syslog.insert( result,
        syslog.key_to_str( k ) .. "=" .. syslog.val_to_str( v ) )
    end
  end
  return "{" .. syslog.concat( result, "," ) .. "}"
end

function logfile.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end


function logfile.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. syslog.val_to_str( k ) .. "]"
  end
end

logfile.level (tonumber (config.log_level) or 3)

return logfile
