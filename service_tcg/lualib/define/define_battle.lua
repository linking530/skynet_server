local define_battle = {}

define_battle.WAR_READY = 1     -- 随机先手,双方选择卡牌 30S, 或等待客户端进入下一阶段 WAR_START TURN_START
define_battle.WAR_START =  2    -- 开始回合战斗
define_battle.WAR_END   =  3    -- 战斗结束

-- 回合战斗状态
define_battle.TURN_WAIT      = 0       --准备战斗
define_battle.TURN_START     = 1       --回合开始
define_battle.TURN_ATT_ACT   = 2       --A部署 服务器计时,
define_battle.TURN_DEF_ACT   = 3       --B针对A部署的反应 服务器计时,
define_battle.TURN_END       = 4       --回合结束,双方明牌,清算触发技能 不计时 等待客户端进入下一阶段 TURN_START

--回合拆分为若干大阶段
define_battle.JIEDUAN_CHUSHIHUA              = 0--对战初始化        开局，双方都没操作过的状态,客户端从等待界面切入战场界面
define_battle.JIEDUAN_HUIHE_KAISHI           = 1--回合开始阶段      己方布置出牌的状态。
define_battle.JIEDUAN_GONGJI_BUSHU           = 2--攻击玩家部署阶段  对方布置状态
define_battle.JIEDUAN_FANGSHOU_BUSHU         = 3--防御玩家部署阶段  开打表现
define_battle.JIEDUAN_KAIPAI_JIESUAN         = 4--卡牌结算阶段 war next
define_battle.JIEDUAN_SHENGWU_ZHANDOU        = 5--生物战斗阶段 war next
define_battle.JIEDUAN_HUIHE_JIESHU           = 6--回合结束阶段
--回合开始      --  前进，力截恢复到正常状态，恢复所有状态。
--战斗结算阶段状态
define_battle.BATTLE_GUANGHUAN      = 7     --结算光环效果
define_battle.BATTLE_DEPLOY		    =1       --结算部署技能效果
define_battle.BATTLE_DEF_STACK	    =2       --结算防御方堆叠区技能效果
define_battle.BATTLE_ATK_STACK 	    =3       --结算进攻方堆叠区技能效果
define_battle.BATTLE_COUNT		    =4       --结算战斗伤害
define_battle.BATTLE_END 			=5      --结算战斗伤害后，回合结束前检查和技能触发
define_battle.BATTLE_TURN_END		=6      --告知客户战斗结算阶段结束

--卡牌的状态
define_battle.CARD_HAND =1         --手中的卡牌
define_battle.CARD_DIE =2          --死亡的卡牌
define_battle.CARD_WAR =3          --场中的卡牌
define_battle.CARD_WAIT=4          --带抽取的卡牌

--troop 场中卡牌的状态
define_battle.TROOP_FIGHT =3               --可以攻击
define_battle.TROOP_REST  =2               --力竭
define_battle.TROOP_INVISIBLE  =1          --对方不可见

--技能分类

--目标区域辨识
define_battle.AREA_ZHANSHU          = 0  --战术区
define_battle.AREA_SHOUPAI		    = 1  --手牌
define_battle.AREA_PAIKU            = 2  --牌库
define_battle.AREA_MUDI             = 3  --墓地
define_battle.AREA_JIANGJUN         = 4  --将军
define_battle.AREA_DUIFANG_ZHIHUIBU	= 5  --对方指挥部
define_battle.AREA_ZIJI_ZHIHUIBU	= 6  --自己指挥部
define_battle.AREA_ZHANCHANG		= 7  --战场
define_battle.AREA_XIAOSHI		    = 8  --消失

--ORDER源CTYPE
define_battle.COMMAND_ORDER      = 4--1圣物-从command牌上发出的技能
define_battle.SHOUPAI_ORDER      = 1--2手牌 
define_battle.ZHANCHANG_ORDER    = 7--3战场一个部队牌生成一张牌飞到战术牌堆叠区,结算后消失
define_battle.JIEJIE_ORDER      =  9--结界



-- 游戏规则相关
define_battle.TROOP_NUM =7      --场上牌数
define_battle.HAND_NUM =10      --场上牌数
define_battle.COMMANDER_NUM =3  --指挥官牌数
define_battle.INIT_NUM =3      --初始牌数
define_battle.INIT_RSC =3      --初始
define_battle.READY_GO =10      --准备时间
define_battle.TURN_TIME =6000000      --回合部署时间
define_battle.MAX_WAIT_TIME =10      --默认等待时间,防止客户端丢包

define_battle.DECK_SIZE =8      --最大牌组数
define_battle.FIGHT_CARDS =60      --最大牌库

define_battle.TRIGGER_1	=	1	--  1：被动（技能一直存在，无触发条件）
define_battle.TRIGGER_2	=	2	--  2：部署（当xxx进场时触发）
define_battle.TRIGGER_3	=	3	--  3：亡语（当xxx死去时触发）
define_battle.TRIGGER_4	=	4	--  4：激怒：（xxx生命值不是满时触发）
define_battle.TRIGGER_5	=	5	--  5：受到伤害：（当xxx受到伤害的时候，每受到一次伤害触发一次效果）
define_battle.TRIGGER_6	=	6	--  6：每个回合结束时
define_battle.TRIGGER_7	=	7	--  7：另一个随从死亡时
define_battle.TRIGGER_8	=	8	--  8：每当一个随从或英雄获得治疗时
define_battle.TRIGGER_9	=	9	--  9：每当你施放一个法术时
define_battle.TRIGGER_10	=	10	--  10：每当对手施放一个法术时
define_battle.TRIGGER_11	=	11	--  11：自己攻击时
define_battle.TRIGGER_12	=	12	--  12：对英雄造成伤害时
define_battle.TRIGGER_13	=	13	--  13：每当你使用一张牌时
define_battle.TRIGGER_14	=	14	--  14：成为法术目标时
define_battle.TRIGGER_15	=	15	--  15：对随从造成伤害时
define_battle.TRIGGER_16	=	16	--  16：自己防御时
define_battle.TRIGGER_17	=	17	--  17：每当使用一张牌
define_battle.TRIGGER_18	=	18	--  18：每个回合开始时
define_battle.TRIGGER_19	=	19	--  19：专门表示这是一张法术卡
define_battle.TRIGGER_20	=	20	--  20：受到战斗伤害时
define_battle.TRIGGER_21	=	21	--  21：受到法术伤害时
define_battle.TRIGGER_22	=	22	--  22：每当有一个随从进场
define_battle.TRIGGER_23	=	23	--  23：每当一个随从受到伤害时
define_battle.TRIGGER_24	=	24	--  24：每次在战斗消灭一个随从时
define_battle.TRIGGER_25	=	25	--  25：你的回合结束时
define_battle.TRIGGER_26	=	26	--  26：每当你的英雄获得生命时
define_battle.TRIGGER_27	=	27	--  27：你的回合开始时
define_battle.TRIGGER_28	=	28	--  28：对手回合结束时
define_battle.TRIGGER_29	=	29	--  29：对手回合开始时
define_battle.TRIGGER_30	=	30	--  30：使用主动技能力竭
define_battle.TRIGGER_31	=	31	--  31：使用主动技能不力竭
define_battle.TRIGGER_32	=	32	--  32：前进时
define_battle.TRIGGER_33	=	33	--  33：对指挥部造成战斗伤害时
define_battle.TRIGGER_34	=	34	--  34：对部队造成战斗伤害时
define_battle.TRIGGER_35	=	35	--  35：每当结算一张非部队牌时，
define_battle.TRIGGER_36	=	36	--  36：每当使用一张瞬间牌时，
define_battle.TRIGGER_37	=	37	--  37：每当使用非瞬间一张法术牌时，
define_battle.TRIGGER_38	=	38	--  38：每当使用一张工事牌时，
define_battle.TRIGGER_39	=	39	--  39：每当使用一张部队牌时，
define_battle.TRIGGER_40	=	40	--  40：暂无
define_battle.TRIGGER_41	=	41	--  41：对手的回合开始时，
define_battle.TRIGGER_42	=	42	--  42：每当己方生物攻击时
define_battle.TRIGGER_43	=	43
define_battle.TRIGGER_44	=	44	
define_battle.TRIGGER_45  =    45	
define_battle.TRIGGER_46   =   46
define_battle.TRIGGER_47  =    47
define_battle.TRIGGER_48  =    48
define_battle.TRIGGER_49  =    49
define_battle.TRIGGER_50  =    50
define_battle.TRIGGER_51  =    51
define_battle.TRIGGER_52  =    52
define_battle.TRIGGER_53 =     53
define_battle.TRIGGER_54  =    54
define_battle.TRIGGER_55  =    55
define_battle.TRIGGER_56  =    56
define_battle.TRIGGER_57   =   57
define_battle.TRIGGER_90	=	90	--	90：反击咒语
define_battle.TRIGGER_98	=	98	--	98：传奇
define_battle.TRIGGER_99	=	99	--	99：特殊

define_battle.SHENGWU_KA   =      1        --  生物卡
define_battle.JIEJIE_KA  =        2        --  结界卡
define_battle.FASHU_KA    =       3        --  法术卡
define_battle.SHUNJIAN_KA  =      4        --  瞬间卡
define_battle.DIXING_KA    =      5        --  地形卡
define_battle.YANSHENG_KA   =     9        --  衍生物
define_battle.ZHUDONGJINENG_KA =   10      --  主动技能

--  属性
define_battle.GONGJI   =      1--  攻击	加或减的数值
define_battle.GONGJISHANGXIAN =   2--  生命上限	加或减的数值
define_battle.SHENGMING   =   3--  生命	加或减的数值
define_battle.WEIZHI   =      4--  位置	"0战术区 1拥有者手牌 2拥有者牌库 3拥有者墓地 5对方英雄 6自己英雄 7战场 8消失 
                     --  10自己手牌 11对手手牌 12自己牌库 13对手牌库 14自己牌库顶 15自己牌库底 16对手牌库顶 
                     --  17对手牌库底 18拥有者牌库顶 19拥有者牌库底"
define_battle.JINENG   =      5--  技能	技能的编号
define_battle.ZHUANGJIA =     6--  装甲X（只能防止战斗伤害）	装甲加成的数值
define_battle.QIANXING =      7--  潜行	
define_battle.FEIXING  =      8--  飞行	无（默认填1）
define_battle.ZHUFU  =        9--  祝福	无（默认填1）
define_battle.CHONGFENG =     10--  冲锋	无（默认填1）
define_battle.BAOJI    =      11--  暴击
define_battle.XIANGONG  =     12--  先攻	无（默认填1）
define_battle.LIANJI    =     13--  连击	无（默认填1）
define_battle.JIANTA  =       14--  践踏 	无（默认填1）
define_battle.SHIBUKEDAGN=    15--  势不可挡	无（默认填1）
define_battle.LAOHUA =       16--  老化
define_battle.CUIHUI  =       17--  摧毁	加成的伤害数值
define_battle.ZHIMING  =      18--  致命	无（默认填1）
define_battle.CHONGSHENG =    19--  重生X	重生的次数
define_battle.ZHIKONG   =     20--  制空	无（默认填1）
define_battle.ZHAOHUAN  =     21--  召唤随从	指定的随从id
define_battle.FASHUSHAGNHAI =     22--  法术伤害	增加的伤害数值
define_battle.HENGSHAO   =    23--  穿透	
define_battle.WEIZHUANG  =    24--  伪装（不能成为目标）	无（默认填1）
define_battle.JINGJIE   =     25--  警戒	无（默认填1）
define_battle.CHIHUAN  =      26--  迟缓	无（默认填1）
define_battle.SHANXIAN  =     27--  闪现	无（默认填1）
define_battle.JIDONG   =      28--  机动X	可移动的距离
define_battle.FANGZHISHANGHAI =   29--  防止所有伤害	防止的伤害数值
define_battle.XIEXUE   =      30--  吸血	无（默认填1）
define_battle.MOFAMIANYI = 31--  魔法免疫（任何玩家不能将其指定为目标）	无（默认填1）
define_battle.FALIHUAFEI = 32--  法力花费	
define_battle.FALI     =   33--  英雄法术力	变化的法术力值
define_battle.FALISHANGXIAN = 34--  英雄法力上限	变化的法术力上限值
define_battle.SHOUHU =     35--  不能攻击（守护）	无（默认填1）
define_battle.QUSAN   =    39--  被驱散（移除buff）	无（默认填1）
define_battle.CHOUPAI  =   40--  抽牌种类	1 抽牌  2 弃牌
define_battle.XIAOMIE   =  41--  消灭效果	无（默认填1）
define_battle.FANGZHIZHANDOUSHANGHAI =42--  防止战斗伤害
define_battle.FZSH   =     43--  消灭效果	无（默认填1）
define_battle.FANGJI  =    44--  
define_battle.QUSAN_DEPLOY =49 --  不能触发显现技能
define_battle.CHUANQI  =   98--  传奇	无（默认填1）
define_battle.TESHU    =   99--  特殊	无（默认填1）
define_battle.MINGYUE     =  101--  特殊	无（默认填1）
return define_battle
