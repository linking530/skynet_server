local base_type =require "struct.base_type"
local protobufload = require "protobufload"
local p_core = require "p.core"
local skynet = require "skynet.manager"
local logstat = require "base.logstat"
local handler = require "agent.handler"
require "struct.class"
require "struct.globle"
local DEBUG = function (...) logstat.log_file2("battle.txt",...) end
local DEBUG_TABLE = function (table) logstat.log_file_r("battle.txt",table) end
handler = handler.new ()
local pload = protobufload.inst()
local user
--ս����ͨ��
local battle_card
--ս��װ����
local battle_cmd
--��ͨ��
local common_cards
--װ����
local equip_cards
--����
local group_cards

function handler.init(u)
    user = u
end

local function war_option(war_option_msg)

	--print_r(war_option_msg)
	--2	war apply type    // Ѱ�Ҷ���,��ʼս�� type��1ƥ���ս��2���ݶ�ս
	if war_option_msg.option == 2 then
	    local battleserver = skynet.localname(".battleserver")	
	    print("user.agent:"..user.agent.."user.userid:"..user.userid)	    
	    skynet.call( battleserver, "lua", "applyBattle",user.agent,user.userid)
	--3	war withdraw type // ȡ��ƥ���ս     type��1Ϊȡ��ƥ���ս��2Ϊȡ�����ݶ�ս
	elseif war_option_msg.option == 3 then
	
	--4	war exchange  // ��������
	elseif war_option_msg.option == 4 then
	
	--5	war giveup    // ����,����
	elseif war_option_msg.option == 5 then
	
	--6 war turnover //�غϽ���
	elseif war_option_msg.option == 6 then
	
	--7 war ok ��������,������һ�׶�
	elseif war_option_msg.option == 7 then
	    DEBUG("user.battleroom:",user.battleroom)
	    if user.battleroom~=nil then
	        skynet.call( user.battleroom, "lua", "war_ok",user.userid,war_option_msg.value)
	    end
    --npcս��	
	end if war_option_msg.option == 8 then
	    local battleserver = skynet.localname(".battleserver")	
	    skynet.call( battleserver, "lua", "applyBattle",user.agent,user.userid)
	    print("user.agent:"..user.agent.."user.number:"..user.userid)	
	end

end

local function war_mov(msg)
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_mov",user.userid,msg)
	end
end

local function war_sacrifice(msg)
	print("battle_handler.war_sacrifice")
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_sacrifice",user.userid,msg)
	end
end

local function war_order(msg)
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_order",user.userid,msg)
	end
end

local function war_deploy(msg)
	if user.battleroom~=nil then
		skynet.call( user.battleroom, "lua", "war_deploy",user.userid,msg)
	end
end

function handler.AnalyseMsg(messageId,msg)
	if messageId == 3000 then--��¼
        war_option(msg)
	elseif  messageId == 3001 then
		war_order(msg)
	elseif  messageId == 3002 then
		war_sacrifice(msg)
	elseif  messageId == 3003 then
		war_deploy(msg)
	elseif messageId == 3005 then
	    war_mov(msg)		
	end
end

function handler.load_card()
    user.battle_card = battle_card
    user.battle_cmd = battle_cmd
    battle_cmd = {10001,10002,10003,}
    battle_card = {
                {100001,100},
                }
    
end


return handler