local define_public = {}

--1卡包  2卡背  3单卡市场 
define_public.KABAO = 1
define_public.KABEI = 2
define_public.DANKA = 3

--   消耗类型：1金币 2钻石
define_public.GOLD = 1
define_public.GEM = 2

-- 11组成卡牌成功保存数据，10不成功
-- 21 修改卡组名称成功保存数据，20不成功
-- 31 删除卡组成功保存数据，30不成功 
define_public.SAVE_DECK_SUCCESS = 11
define_public.SAVE_DECK_FAIL = 10
define_public.MODIF_DECK_SUCCESS = 21
define_public.MODIF_DECK_FAIL = 20
define_public.DEL_DECK_SUCCESS = 31
define_public.DEL_DECK_FAIL = 30

return define_public
