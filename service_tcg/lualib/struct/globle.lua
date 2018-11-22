require "struct.functions"
table.getn = function(tmp)
    for i=1,math.huge do
        --if tmp[i] == nil then return i-1 end
        if rawget(tmp,i) == nil  then return i-1 end
    end
    return 0;
end

-- 读文件的函数，把整个文件内容读取并返回的函数
function read_file(fileName)
    local f = assert(io.open(fileName,'r'))
    local content = f:read("*all")
    f:close()
    return content
end 

--分割字符串的函数，类似PHP中的explode函数，使用特定的分隔符分割后返回”数组（lua中的 table）“
function explode(str,split)
    local lcSubStrTab = {}
    while true do
        local lcPos = string.find(str,split)
        if not lcPos then
            lcSubStrTab[#lcSubStrTab+1] =  str    
            break
        end
        local lcSubStr  = string.sub(str,1,lcPos-1)
        lcSubStrTab[#lcSubStrTab+1] = lcSubStr
        str = string.sub(str,lcPos+1,#str)
    end
    return lcSubStrTab
end


-- 类似PHP中的Trim函数，用来去掉字符串两端多余的空白符（white Space）
function trim(s)
 return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

--表转成json
function table2json(t)  
    local function serialize(tbl)  
            local tmp = {}  
            for k, v in pairs(tbl) do  
                    local k_type = type(k)  
                    local v_type = type(v)  
                    local key = (k_type == "string" and "\"" .. k .. "\":")  
                        or (k_type == "number" and "")  
                    local value = (v_type == "table" and serialize(v))  
                        or (v_type == "boolean" and tostring(v))  
                        or (v_type == "string" and "\"" .. v .. "\"")  
                        or (v_type == "number" and v)  
                    tmp[#tmp + 1] = key and value and tostring(key) .. tostring(value) or nil  
            end  
            if table.getn(tbl) == 0 then  
                    return "{" .. table.concat(tmp, ",") .. "}"  
            else  
                    return "[" .. table.concat(tmp, ",") .. "]"  
            end  
    end  
    assert(type(t) == "table")  
    return serialize(t)  
end  

--[[
-- 深度克隆一个值
-- example:
-- 1. t2是t1应用,修改t2时，t1会跟着改变
    local t1 = { a = 1, b = 2, }
    local t2 = t1
    t2.b = 3    -- t1 = { a = 1, b = 3, } == t1.b跟着改变
   
-- 2. clone() 返回t1副本，修改t2,t1不会跟踪改变
    local t1 = { a = 1, b = 2 }
    local t2 = clone( t1 )
    t2.b = 3    -- t1 = { a = 1, b = 3, } == t1.b不跟着改变
   
-- @param object 要克隆的值
-- @return objectCopy 返回值的副本
--]]
function clone( object )
    local lookup_table = {}
    local function copyObj( object )
        if type( object ) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
       
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs( object ) do
            new_table[copyObj( key )] = copyObj( value )
        end
        return setmetatable( new_table, getmetatable( object ) )
    end
    return copyObj( object )
end

function print_r(table,str,r,k,n)
	local str =  str or ' '--分割符号
	local n =  n or 0--分割符号数量
	local k =  k or ''--KEY值
	local r =  r or false--是否返回，否则为打印
	
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

--获取服务器时间
function get_party_time()
    --print("get_party_time:"..os.time())
    return os.time()
end

function table_copy( obj )      
    local InTable = {};  
    local function Func(obj)  
        if type(obj) ~= "table" then   --判断表中是否有表  
            return obj;  
        end  
        local NewTable = {};  --定义一个新表  
        InTable[obj] = NewTable;  --若表中有表，则先把表给InTable，再用NewTable去接收内嵌的表  
        for k,v in pairs(obj) do  --把旧表的key和Value赋给新表  
            NewTable[Func(k)] = Func(v);  
        end  
        return setmetatable(NewTable, getmetatable(obj))--赋值元表  
    end
    return Func(obj) --若表中有表，则把内嵌的表也复制了  
end

function table.merge_card(arr1,arr2)
	local i,j,size1,size2
	size1 = #arr1
	size2 = #arr2
	for i=1,size1 do
		for j=1,size2 do
			if arr1[i]==arr2[j] then
				break
			end
		end
		table.insert(arr1,arr2[j])
	end
end

function table.join(arr1,arr2)
	if arr2==nil then return end
	if arr1 ==nil then return end
	 for k,v in pairs(arr2) do
		arr1[k] = v
	end
end
