local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local pload = protobufload.inst() 
require "struct.globle"
local protobufload = require "protobufload"
local pload = protobufload.inst() 
------------------------------------------------------------------------------
local DEBUG_MOVE = function (...) logstat.log_file2("move.txt",...) end
local DEBUG_MOVE_TABLE = function (table) logstat.log_file_r("move.txt",table) end
--------------------------------------------------------------------------------

local battle_send = {}

function battle_send.cur_stutas( war,status,m_flag)
	local msg = pload.encode("game.cur_stutas",{
	value0 = 1;
    value = war:get_cur_stutas();   --角色名id
    flag = m_flag;
    })
  
    local d_msg = pload.decode("game.cur_stutas",msg)
    print_r(d_msg)
          
	war:send(war:get_send_users(),4001,msg)
end

--一回合内战斗阶段转换
function battle_send.front_begin(war,m_value)
	local msg = pload.encode("game.front_begin",{
	head = 1;
    value =m_value;
    })
    local d_msg = pload.decode("game.front_begin",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4002,msg)
end

function battle_send.change_fronts(war,m_user_id,m_cardid,m_pos)
	local msg = pload.encode("game.change_fronts",{
	cardid = m_cardid;
    pos =m_pos;
	user_id = m_user_id;
    })
    local d_msg = pload.decode("game.change_fronts",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4008,msg)
	DEBUG_MOVE("change_fronts",m_user_id,m_cardid,m_pos)
end

function battle_send.move_to_fronts(war,m_user_id,m_cardid,m_spos,m_dpos)
	local msg = pload.encode("game.move_to_fronts",{
	cardid = m_cardid;
    spos = m_spos;
	dpos = m_dpos;
	user_id = m_user_id;
    })
    local d_msg = pload.decode("game.move_to_fronts",msg)
    print_r(d_msg)  
    DEBUG_MOVE("send 4018")
	war:send(war:get_send_users(),4018,msg)
end

--部队移动
function battle_send.front_mov(war,m_spos,m_dpos)
	local msg = pload.encode("game.front_mov",{
	spos = m_spos;
    dpos =m_dpos;
    })
    local d_msg = pload.decode("game.front_mov",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4012,msg)
end

--
function battle_send.battle_states(war,m_status,m_flag)
	local msg = pload.encode("game.battle_states",{
	value0 = 1;
    status =m_status;
    flag =m_flag;
    })
    local d_msg = pload.decode("game.battle_states",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4013,msg)
end

--胜利方
function battle_send.win_user(war,m_win_user)
	local msg = pload.encode("game.win_user",{
	win_user = m_win_user;
    })
    local d_msg = pload.decode("game.win_user",msg)
    print_r(d_msg)
	war:send(war:get_send_users(),4014,msg)
end

--攻击方
function battle_send.set_turn(war,m_userid)
	local msg = pload.encode("game.set_turn",{
	userid = m_userid;
    })
    local d_msg = pload.decode("game.set_turn",msg)
    print_r(d_msg)

	war:send(war:get_send_users(),4015,msg)

end

--资源
function battle_send.res(war,m_user_id,m_max_hp,m_cur_hp,m_max_res,m_cur_res)
	local msg = pload.encode("game.res",{
        user_id = m_user_id;
        max_hp = m_max_hp;
        cur_hp = m_cur_hp;
        max_res = m_max_res;
        cur_res = m_cur_res;
    })
    local d_msg = pload.decode("game.res",msg)
    print_r(d_msg) 
	war:send(war:get_send_users(),4011,msg)
end


function battle_send.battle_card_attack(war,m_type,m_userid,m_cardid,m_spos,m_darea,m_dpos)
	local msg = pload.encode("game.card_attack",{
        mtype = m_type;
        userid = m_userid;
        cardid = m_cardid;
        spos = m_spos;
        darea = m_darea;
        dpos = m_dpos;
    })
    local d_msg = pload.decode("game.card_attack",msg)
    print_r(d_msg) 
	war:send(war:get_send_users(),4017,msg)
end

	-- required int32 pos = 1;
	-- optional int32 hp = 2;
	-- optional int32 mhp = 3;	
	-- optional int32 ap = 4;	
	-- optional int32 zz = 5;
function battle_send.cards_info(war,m_pos,m_hp,m_mhp,m_ap,m_zz)
	local msg = pload.encode("game.cards_info",{
        pos = m_pos;
        hp = m_hp;
        mhp = m_mhp;
		ap = m_ap;
		zz = m_zz;
	})
    local d_msg = pload.decode("game.cards_info",msg)
    --print_r(d_msg)
	war:send(war:get_send_users(),4016,msg)
end

function battle_send.card_dead(war,m_user_id,m_cardid,m_pos)
	local msg = pload.encode("game.card_dead",{
	cardid = m_cardid;
    pos =m_pos;
	user_id = m_user_id;
    })
    local d_msg = pload.decode("game.card_dead",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4019,msg)
	DEBUG_MOVE("card_dead",m_user_id,m_cardid,m_pos)
end

function battle_send.jiejie_mov(war,m_user_id,m_oid,m_cardid,m_pos,m_postype)
	local msg = pload.encode("game.jiejie_mov",{
	user_id = m_user_id;
	oid = m_oid;
    cid =m_cid;
	pos = m_pos;
	postype = m_postype
    })
    local d_msg = pload.decode("game.jiejie_mov",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4021,msg)
	DEBUG_MOVE("jiejie_mov",m_user_id,m_cardid,m_pos)
end

function battle_send.add_stack(war,m_user_id,m_oid,m_cid,m_sid,m_stype,m_spos,m_darea,m_dpos)
	local msg = pload.encode("game.add_stack",{
	user_id = m_user_id;
	oid = m_oid;
    cid =m_cid;
	sid = m_sid ;
	stype =m_stype ;
	spos = m_spos ;
	darea = m_darea ;
	dpos = m_dpos ;
    })
    local d_msg = pload.decode("game.add_stack",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4022,msg)
	DEBUG_MOVE("add_stack",m_user_id,m_cardid,m_pos)
end

-- message battle_card_effect
-- {
	-- required int32 user_id = 1 ;	//玩家ID
	-- required int32 cardid = 2 ;	//道具id
	-- required int32 cardpos = 3 ;	//数量
	-- required int32 skill_id = 4 ;	//技能编号
	-- required int32 flag=5;			//8显示开始，9显示结束
-- }
function battle_send.battle_card_effect(war,m_user_id,m_flag,m_cardid,m_cardpos,m_skill_id)
	local msg = pload.encode("game.battle_card_effect",{
	user_id = m_user_id;
	cardid = m_cardid;
    cardpos =m_cardpos;
	skill_id = m_skill_id;
	flag =m_flag;
    })
    local d_msg = pload.decode("game.battle_card_effect",msg)
    print_r(d_msg)    
	war:send(war:get_send_users(),4023,msg)
end

return battle_send