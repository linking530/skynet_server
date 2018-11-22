local skynet = require "skynet.manager"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local p_core=require "p.core"
local logstat = require "base.logstat"
local cjson = require "cjson"
local json_safe = require "cjson.safe"
local util = require "cjson.util"
--Cjson库只支持一维表
------------------------------------------------------------------------------
local DEBUG = function (...) logstat.log_file2("sql.txt",...) end
local DEBUG_TABLE = function (table) logstat.log_file_r("sql.txt",table) end
--------------------------------------------------------------------------------


---------------------------------------------------------------------
local usersql = {}
local mt = { __index = usersql }
local mysqlserver = skynet.localname(".mysqlserver")
-- -- 普通卡
-- local common_cards = nil
-- -- 装备卡
-- local equip_cards = nil
-- -- 战斗普通卡
-- local battle_card
-- -- 战斗装备卡
-- local battle_cmd
-- -- 卡组
-- local deck
function usersql.new(o)
    o = o or {}   -- create object if user does not provide one
	setmetatable (o, mt)
	return o
end

--保存玩家数据
function usersql.saveuser(u)
	usersql.update_player_base_info(u)
end

--[[
-- Table "player_base_info" DDL

CREATE TABLE `player_base_info` (
  `uid` bigint(20) NOT NULL,
  `name` varchar(30) NOT NULL COMMENT '字名',
  `sex` int(11) DEFAULT NULL COMMENT '性别',
  `level` int(11) DEFAULT NULL COMMENT '等级',
  `account` varchar(100) DEFAULT NULL COMMENT '号账',
  `vip` int(11) DEFAULT '0' COMMENT '是否VIP',
  `reg_time` int(11) DEFAULT NULL COMMENT '注册时间',
  `reg_ip` varchar(16) DEFAULT NULL COMMENT '注册IP',
  `ontime` int(11) DEFAULT NULL COMMENT '录登时间',
  `onip` varchar(16) DEFAULT NULL COMMENT '登录IP',
  `online` tinyint(1) DEFAULT '0' COMMENT '线在标记',
  `outline` tinyint(1) DEFAULT '0' COMMENT '离线标记',
  PRIMARY KEY (`uid`),
  KEY `Index_1` (`account`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
]]--
function usersql.insert_player_base_info(u)
    local ret,sql,me
    --local mysqlserver = skynet.localname(".mysqlserver")	

	sql = "INSERT INTO player_base_info (uid,name,sex,level,account,vip) VALUES ('"
	..u.userid.."', '"..u.name.."', '"..u.sex
	.."', '"..u.level.."', '"..u.name.."', '"..u.vip.."')"
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call(mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]~= nil then 
		--print("role"..ret[1]["role_id"]..ret[1]["player_name"]..ret[1]["player_account"])
		DEBUG_TABLE(ret)
	end
	return ret
end

--更新角色基础信息
function usersql.update_player_base_info(u)
    local ret,sql,me
    --local mysqlserver = skynet.localname(".mysqlserver")			
	sql = "UPDATE player_base_info SET name='"..u.name.."',sex="..u.sex..",level="..u.level..",vip="..u.vip.." WHERE uid='"..u.userid.."'"
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]~= nil then 
		DEBUG_TABLE(ret)
	end
	return ret
end

--查询角色基础信息
function usersql.select_player_base_info(u)
    local ret,sql,me
    --local mysqlserver = skynet.localname(".mysqlserver")
	sql = "SELECT * FROM player_base_info".." WHERE uid='"..u.userid.."'"
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]~= nil then 
		DEBUG_TABLE(ret)
		u.sex = ret[1].sex
		u.level = ret[1].level
		u.vip = ret[1].vip
	end
	return ret
end

function usersql.insert_player_data(u)
    local ret,sql,me,userbase
    --local mysqlserver = skynet.localname(".mysqlserver")	
	local save_data = ""
	sql = "INSERT INTO player_data (uid,save_data) VALUES ("
	..u.userid..", '"..save_data.."')"
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call(mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]~= nil then 
		DEBUG_TABLE(ret)
	end
	return ret
end

--更新角色基础信息
function usersql.update_player_data(u)
    local ret,sql,me,save_data
	
	local save_table = {}
	local usebase = {}

	usebase.money = u.money
	usebase.exp = u.exp
	usebase.level = u.level
	usebase.ranksocre = u.ranksocre
	usebase.gem = u.gem
	usebase.head = u.head

	usebase.awardkey = u.awardkey
	usebase.sex = u.sex
	usebase.school = u.school
	usebase.vip = u.vip
	
	save_data = cjson.encode(usebase)
	 
	
	sql = "UPDATE player_data SET save_data='"..save_data.."' WHERE uid="..u.userid
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	
	if ret[1]~= nil then 
		DEBUG_TABLE(ret)
	end
	return ret
end

--查询角色基础信息
function usersql.select_player_data(u)
    local ret,sql,me,userbase = {}
    --local mysqlserver = skynet.localname(".mysqlserver")
	sql = "SELECT * FROM player_data".." WHERE uid='"..u.userid.."'"
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)

	if ret[1]~= nil then 
		DEBUG_TABLE(ret)
		local userbase = cjson.decode(ret[1].save_data)
		
		u.money = userbase.money
		u.exp = userbase.exp
		u.level = userbase.level
		u.ranksocre = userbase.ranksocre
		u.gem = userbase.gem
		u.head = userbase.head

		u.awardkey = userbase.awardkey
		u.sex = userbase.sex
		u.school = userbase.school
		u.vip = userbase.vip
		-- print("=======================================")
		-- print_r(userbase)
		-- print("=======================================")
	end
	return ret
end

function usersql.insert_player_card_deck(u)
    local ret,sql,me
    --local mysqlserver = skynet.localname(".mysqlserver")	
	local save_data = ""
	sql = "INSERT INTO player_card_deck (uid,deck) VALUES ("
	..u.userid..", '"..save_data.."')"
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call(mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]~= nil then
		DEBUG_TABLE(ret)
	end
	return ret
end

--更新角色基础信息
--存储内容 
function usersql.update_player_card_deck(u)
    local ret,sql,me,save_data
	local save_table = {}
	cjson.encode_sparse_array(true)  	

	print_r(u.equip_cards)
	print_r(u.common_cards)	
	
	local deck = cjson.encode(u.deck)
	local equip_cards = cjson.encode(u.equip_cards)
	local common_cards = cjson.encode(u.common_cards)		
	
	sql = "UPDATE player_card_deck SET deck='"..deck.."', equip_cards='"..equip_cards.."', common_cards='"..common_cards.."' WHERE uid="..u.userid
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]~= nil then 
		DEBUG_TABLE(ret)
	end
	return ret
end

--查询角色基础信息
function usersql.select_player_card_deck(u)
    local ret,sql,me,save_table
    --local mysqlserver = skynet.localname(".mysqlserver")
	sql = "SELECT * FROM player_card_deck".." WHERE uid='"..u.userid.."'"
	logstat.log_day("sql","sql:"..sql.."\n")
	ret = skynet.call (mysqlserver, "lua", "sql", sql) or error (string.format ("create account %s/%d failed", ret))		
	print_r(ret)
	if ret[1]~= nil then 
		DEBUG_TABLE(ret)
	cjson.encode_sparse_array(true)  		
	u.deck = cjson.decode(ret[1].deck)
	u.equip_cards = cjson.decode(ret[1].equip_cards)
	u.common_cards = cjson.decode(ret[1].common_cards)		
	end
	return ret
end


--离线处理
function usersql.quit(u)

end

--数据库读盘
function usersql.load_data(u)

end

--数据库存盘
function usersql.save_data(u)

end

return usersql
