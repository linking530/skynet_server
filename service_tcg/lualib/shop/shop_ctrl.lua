local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local protobufload = require "protobufload"
local logstat = require "base.logstat"
local p_core=require "p.core"
local shopinfo = require "data.shopinfo"
local pload = protobufload.inst()

require "struct.globle"

local shop_ctrl = {}

function shop_ctrl.get_shop_info(id)
	local data_market = shopinfo.get_data_market()
	return data_market[id]
end

--�����ճ������б�
function shop_ctrl.send_shop_info(agent,userId)
	local data_market = shopinfo.get_data_market()
-- message shop_cards
-- {
	-- message shop_cards
	-- {
		-- required int32 cardid = 1;	//�̳ǿ���ID
		-- required int32 number = 2;	//�̳ǿ�������
		-- required int32 buy_price = 3;	//����۸�
		-- required int32 sell_price = 4;	//���ۼ۸�;
	-- }
	-- repeated shop_cards cards = 1;	//�̳ǿ��б�
-- }

	local mList = {}
	local mCard
	for k,v in pairs(data_market) do
	--print_r(v)
		mCard={cardid = v.id,
		number = v.exist,
		buy_price = v.buy,
		sell_price = v.sell}	
		table.insert(mList,mCard)
	end
	msg = pload.encode("game.shop_cards",{
	cards=mList;})
	skynet.call(agent, "lua", "send",2008,msg)
end

return shop_ctrl