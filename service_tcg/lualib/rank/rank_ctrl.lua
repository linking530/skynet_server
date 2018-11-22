local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local player = require "npc.player"
local define_battle = require "define.define_battle"
local battle_send = require "battle.battle_send"
local pload = protobufload.inst() 
require "struct.globle"

local rank_ctrl = {}





--发送日常任务列表
function rank_ctrl.send_rank_info( me)


end

return rank_ctrl