local logstat = {}

function logstat.concat(arg,k)
  local data = ""
  for _, v in ipairs(arg) do
    local t = type(v)
    if t == 'number' or t == 'string' or t == 'boolean' or t == 'nil' or t == 'boolean' then
      data = data..v..k
    elseif t == 'table' then
      data = data .. "\n {"..logstat.concat(v).."}\n"
    else
		data = data.." " .. t..":"..""
	end
  end
  return data
end

function logstat.log_file2(file,...)
    local str = logstat.concat({...}, ", ")
--    print("str:"..str)
    local player_data = io.open("./log_me/"..file,"a")
    player_data:write(str.."\n")
    player_data:close()
end
--type(o) == "table"
function logstat.log_file_r(file,table,str,r,k,n)
	local str =  str or ' '--分割符号
	local n =  n or 0--分割符号数量
	local k =  k or ''--KEY值
	local r =  r or false--是否返回，否则为打印	
	local tab = ''	
	local val_str = ''
	if type(str) == 'string' then 
		tab = string.rep(str,n)
	end
	
	if type(table) == "table" then
		n=n+1
		val_str = val_str..tab..k.."={"	
		for k,v in pairs(table) do
			if type(v) == "table" then
				val_str = val_str.."\n"..logstat.log_file_r(v,str,true,k,n)
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
		logstat.log_file(file,val_str)
	end
end

function logstat.log_file (file, str)
        --print(file)
        local player_data = io.open(file,"a")
        player_data:write(str)
        player_data:close()
end

function logstat.create()
    os.execute("mkdir log_me")
    os.execute("mkdir log_me/day")
    os.execute("mkdir log_me/hour")
    os.execute("mkdir log_me/min")
    os.execute("mkdir log_me/event")
    os.execute("mkdir log_me/url")
end

function logstat.log_file_time(file, str)
    local player_data = io.open(file,"a")
    local str = os.date("%Y-%m-%d %H:%M:%S", os.time()).."\t"..str        
    player_data:write(str)
    player_data:close()
end

function logstat.log_month(cFile,buf)
    buf = os.date("%Y-%m-%d %H:%M:%S", os.time()).."\t"..buf
    local file = "./log_me/month/"..cFile.."-"..os.date("%Y-%m", os.time())..".txt"
    logstat.log_file(file,buf);
end

--每天的log
function logstat.log_day(cFile,buf)
    buf = os.date("%Y-%m-%d %H:%M:%S", os.time()).."\t"..buf.."\n"
    local file = "./log_me/day/"..cFile.."-"..os.date("%Y-%m-%d", os.time())..".txt"
    logstat.log_file(file,buf);
end

--每小时的LOG
function logstat.log_hour(cFile,buf)
    buf = os.date("%Y-%m-%d %H:%M:%S", os.time()).."\t"..buf
    local file = "./log_me/day/"..cFile.."-"..os.date("%Y-%m-%d %H", os.time())..".txt"
    log_file(file,buf);
end



--每分钟的log没有校验码的
function logstat.log_min(cFile,buf)
    buf = os.date("%Y-%m-%d %H:%M:%S", os.time()).."\t"..buf
    local file = "./log_me/day/"..cFile.."-"..os.date("%Y-%m-%d %H:%M", os.time())..".txt"
    logstat.log_file(file,buf);
end


--event的log
function logstat.log_event(cFile,buf)
    buf = os.date("%Y-%m-%d %H:%M:%S", os.time()).."\t"..buf
    local file = "./log_me/event/"..cFile.."-"..os.date("%Y-%m-%d %H", os.time())..".txt"
    logstat.log_file(file,buf);
end

--每小时URL的LOG
function logstat.log_url(cFile,buf)
    local buf = os.date("%Y-%m-%d %H:%M:%S", os.time()).."\t"..buf
    local file = "./log_me/url/"..cFile.."-"..os.date("%Y-%m-%d %H", os.time())..".txt"
    logstat.log_file(file,buf);
end

return logstat
