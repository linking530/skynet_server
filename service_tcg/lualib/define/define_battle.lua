local define_battle = {}

define_battle.WAR_READY = 1     -- �������,˫��ѡ���� 30S, ��ȴ��ͻ��˽�����һ�׶� WAR_START TURN_START
define_battle.WAR_START =  2    -- ��ʼ�غ�ս��
define_battle.WAR_END   =  3    -- ս������

-- �غ�ս��״̬
define_battle.TURN_WAIT      = 0       --׼��ս��
define_battle.TURN_START     = 1       --�غϿ�ʼ
define_battle.TURN_ATT_ACT   = 2       --A���� ��������ʱ,
define_battle.TURN_DEF_ACT   = 3       --B���A����ķ�Ӧ ��������ʱ,
define_battle.TURN_END       = 4       --�غϽ���,˫������,���㴥������ ����ʱ �ȴ��ͻ��˽�����һ�׶� TURN_START

--�غϲ��Ϊ���ɴ�׶�
define_battle.JIEDUAN_CHUSHIHUA              = 0--��ս��ʼ��        ���֣�˫����û��������״̬,�ͻ��˴ӵȴ���������ս������
define_battle.JIEDUAN_HUIHE_KAISHI           = 1--�غϿ�ʼ�׶�      �������ó��Ƶ�״̬��
define_battle.JIEDUAN_GONGJI_BUSHU           = 2--������Ҳ���׶�  �Է�����״̬
define_battle.JIEDUAN_FANGSHOU_BUSHU         = 3--������Ҳ���׶�  �������
define_battle.JIEDUAN_KAIPAI_JIESUAN         = 4--���ƽ���׶� war next
define_battle.JIEDUAN_SHENGWU_ZHANDOU        = 5--����ս���׶� war next
define_battle.JIEDUAN_HUIHE_JIESHU           = 6--�غϽ����׶�
--�غϿ�ʼ      --  ǰ�������ػָ�������״̬���ָ�����״̬��
--ս������׶�״̬
define_battle.BATTLE_GUANGHUAN      = 7     --����⻷Ч��
define_battle.BATTLE_DEPLOY		    =1       --���㲿����Ч��
define_battle.BATTLE_DEF_STACK	    =2       --����������ѵ�������Ч��
define_battle.BATTLE_ATK_STACK 	    =3       --����������ѵ�������Ч��
define_battle.BATTLE_COUNT		    =4       --����ս���˺�
define_battle.BATTLE_END 			=5      --����ս���˺��󣬻غϽ���ǰ���ͼ��ܴ���
define_battle.BATTLE_TURN_END		=6      --��֪�ͻ�ս������׶ν���

--���Ƶ�״̬
define_battle.CARD_HAND =1         --���еĿ���
define_battle.CARD_DIE =2          --�����Ŀ���
define_battle.CARD_WAR =3          --���еĿ���
define_battle.CARD_WAIT=4          --����ȡ�Ŀ���

--troop ���п��Ƶ�״̬
define_battle.TROOP_FIGHT =3               --���Թ���
define_battle.TROOP_REST  =2               --����
define_battle.TROOP_INVISIBLE  =1          --�Է����ɼ�

--���ܷ���

--Ŀ�������ʶ
define_battle.AREA_ZHANSHU          = 0  --ս����
define_battle.AREA_SHOUPAI		    = 1  --����
define_battle.AREA_PAIKU            = 2  --�ƿ�
define_battle.AREA_MUDI             = 3  --Ĺ��
define_battle.AREA_JIANGJUN         = 4  --����
define_battle.AREA_DUIFANG_ZHIHUIBU	= 5  --�Է�ָ�Ӳ�
define_battle.AREA_ZIJI_ZHIHUIBU	= 6  --�Լ�ָ�Ӳ�
define_battle.AREA_ZHANCHANG		= 7  --ս��
define_battle.AREA_XIAOSHI		    = 8  --��ʧ

--ORDERԴCTYPE
define_battle.COMMAND_ORDER      = 4--1ʥ��-��command���Ϸ����ļ���
define_battle.SHOUPAI_ORDER      = 1--2���� 
define_battle.ZHANCHANG_ORDER    = 7--3ս��һ������������һ���Ʒɵ�ս���ƶѵ���,�������ʧ
define_battle.JIEJIE_ORDER      =  9--���



-- ��Ϸ�������
define_battle.TROOP_NUM =7      --��������
define_battle.HAND_NUM =10      --��������
define_battle.COMMANDER_NUM =3  --ָ�ӹ�����
define_battle.INIT_NUM =3      --��ʼ����
define_battle.INIT_RSC =3      --��ʼ
define_battle.READY_GO =10      --׼��ʱ��
define_battle.TURN_TIME =6000000      --�غϲ���ʱ��
define_battle.MAX_WAIT_TIME =10      --Ĭ�ϵȴ�ʱ��,��ֹ�ͻ��˶���

define_battle.DECK_SIZE =8      --���������
define_battle.FIGHT_CARDS =60      --����ƿ�

define_battle.TRIGGER_1	=	1	--  1������������һֱ���ڣ��޴���������
define_battle.TRIGGER_2	=	2	--  2�����𣨵�xxx����ʱ������
define_battle.TRIGGER_3	=	3	--  3�������xxx��ȥʱ������
define_battle.TRIGGER_4	=	4	--  4����ŭ����xxx����ֵ������ʱ������
define_battle.TRIGGER_5	=	5	--  5���ܵ��˺�������xxx�ܵ��˺���ʱ��ÿ�ܵ�һ���˺�����һ��Ч����
define_battle.TRIGGER_6	=	6	--  6��ÿ���غϽ���ʱ
define_battle.TRIGGER_7	=	7	--  7����һ���������ʱ
define_battle.TRIGGER_8	=	8	--  8��ÿ��һ����ӻ�Ӣ�ۻ������ʱ
define_battle.TRIGGER_9	=	9	--  9��ÿ����ʩ��һ������ʱ
define_battle.TRIGGER_10	=	10	--  10��ÿ������ʩ��һ������ʱ
define_battle.TRIGGER_11	=	11	--  11���Լ�����ʱ
define_battle.TRIGGER_12	=	12	--  12����Ӣ������˺�ʱ
define_battle.TRIGGER_13	=	13	--  13��ÿ����ʹ��һ����ʱ
define_battle.TRIGGER_14	=	14	--  14����Ϊ����Ŀ��ʱ
define_battle.TRIGGER_15	=	15	--  15�����������˺�ʱ
define_battle.TRIGGER_16	=	16	--  16���Լ�����ʱ
define_battle.TRIGGER_17	=	17	--  17��ÿ��ʹ��һ����
define_battle.TRIGGER_18	=	18	--  18��ÿ���غϿ�ʼʱ
define_battle.TRIGGER_19	=	19	--  19��ר�ű�ʾ����һ�ŷ�����
define_battle.TRIGGER_20	=	20	--  20���ܵ�ս���˺�ʱ
define_battle.TRIGGER_21	=	21	--  21���ܵ������˺�ʱ
define_battle.TRIGGER_22	=	22	--  22��ÿ����һ����ӽ���
define_battle.TRIGGER_23	=	23	--  23��ÿ��һ������ܵ��˺�ʱ
define_battle.TRIGGER_24	=	24	--  24��ÿ����ս������һ�����ʱ
define_battle.TRIGGER_25	=	25	--  25����ĻغϽ���ʱ
define_battle.TRIGGER_26	=	26	--  26��ÿ�����Ӣ�ۻ������ʱ
define_battle.TRIGGER_27	=	27	--  27����ĻغϿ�ʼʱ
define_battle.TRIGGER_28	=	28	--  28�����ֻغϽ���ʱ
define_battle.TRIGGER_29	=	29	--  29�����ֻغϿ�ʼʱ
define_battle.TRIGGER_30	=	30	--  30��ʹ��������������
define_battle.TRIGGER_31	=	31	--  31��ʹ���������ܲ�����
define_battle.TRIGGER_32	=	32	--  32��ǰ��ʱ
define_battle.TRIGGER_33	=	33	--  33����ָ�Ӳ����ս���˺�ʱ
define_battle.TRIGGER_34	=	34	--  34���Բ������ս���˺�ʱ
define_battle.TRIGGER_35	=	35	--  35��ÿ������һ�ŷǲ�����ʱ��
define_battle.TRIGGER_36	=	36	--  36��ÿ��ʹ��һ��˲����ʱ��
define_battle.TRIGGER_37	=	37	--  37��ÿ��ʹ�÷�˲��һ�ŷ�����ʱ��
define_battle.TRIGGER_38	=	38	--  38��ÿ��ʹ��һ�Ź�����ʱ��
define_battle.TRIGGER_39	=	39	--  39��ÿ��ʹ��һ�Ų�����ʱ��
define_battle.TRIGGER_40	=	40	--  40������
define_battle.TRIGGER_41	=	41	--  41�����ֵĻغϿ�ʼʱ��
define_battle.TRIGGER_42	=	42	--  42��ÿ���������﹥��ʱ
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
define_battle.TRIGGER_90	=	90	--	90����������
define_battle.TRIGGER_98	=	98	--	98������
define_battle.TRIGGER_99	=	99	--	99������

define_battle.SHENGWU_KA   =      1        --  ���￨
define_battle.JIEJIE_KA  =        2        --  ��翨
define_battle.FASHU_KA    =       3        --  ������
define_battle.SHUNJIAN_KA  =      4        --  ˲�俨
define_battle.DIXING_KA    =      5        --  ���ο�
define_battle.YANSHENG_KA   =     9        --  ������
define_battle.ZHUDONGJINENG_KA =   10      --  ��������

--  ����
define_battle.GONGJI   =      1--  ����	�ӻ������ֵ
define_battle.GONGJISHANGXIAN =   2--  ��������	�ӻ������ֵ
define_battle.SHENGMING   =   3--  ����	�ӻ������ֵ
define_battle.WEIZHI   =      4--  λ��	"0ս���� 1ӵ�������� 2ӵ�����ƿ� 3ӵ����Ĺ�� 5�Է�Ӣ�� 6�Լ�Ӣ�� 7ս�� 8��ʧ 
                     --  10�Լ����� 11�������� 12�Լ��ƿ� 13�����ƿ� 14�Լ��ƿⶥ 15�Լ��ƿ�� 16�����ƿⶥ 
                     --  17�����ƿ�� 18ӵ�����ƿⶥ 19ӵ�����ƿ��"
define_battle.JINENG   =      5--  ����	���ܵı��
define_battle.ZHUANGJIA =     6--  װ��X��ֻ�ܷ�ֹս���˺���	װ�׼ӳɵ���ֵ
define_battle.QIANXING =      7--  Ǳ��	
define_battle.FEIXING  =      8--  ����	�ޣ�Ĭ����1��
define_battle.ZHUFU  =        9--  ף��	�ޣ�Ĭ����1��
define_battle.CHONGFENG =     10--  ���	�ޣ�Ĭ����1��
define_battle.BAOJI    =      11--  ����
define_battle.XIANGONG  =     12--  �ȹ�	�ޣ�Ĭ����1��
define_battle.LIANJI    =     13--  ����	�ޣ�Ĭ����1��
define_battle.JIANTA  =       14--  ��̤ 	�ޣ�Ĭ����1��
define_battle.SHIBUKEDAGN=    15--  �Ʋ��ɵ�	�ޣ�Ĭ����1��
define_battle.LAOHUA =       16--  �ϻ�
define_battle.CUIHUI  =       17--  �ݻ�	�ӳɵ��˺���ֵ
define_battle.ZHIMING  =      18--  ����	�ޣ�Ĭ����1��
define_battle.CHONGSHENG =    19--  ����X	�����Ĵ���
define_battle.ZHIKONG   =     20--  �ƿ�	�ޣ�Ĭ����1��
define_battle.ZHAOHUAN  =     21--  �ٻ����	ָ�������id
define_battle.FASHUSHAGNHAI =     22--  �����˺�	���ӵ��˺���ֵ
define_battle.HENGSHAO   =    23--  ��͸	
define_battle.WEIZHUANG  =    24--  αװ�����ܳ�ΪĿ�꣩	�ޣ�Ĭ����1��
define_battle.JINGJIE   =     25--  ����	�ޣ�Ĭ����1��
define_battle.CHIHUAN  =      26--  �ٻ�	�ޣ�Ĭ����1��
define_battle.SHANXIAN  =     27--  ����	�ޣ�Ĭ����1��
define_battle.JIDONG   =      28--  ����X	���ƶ��ľ���
define_battle.FANGZHISHANGHAI =   29--  ��ֹ�����˺�	��ֹ���˺���ֵ
define_battle.XIEXUE   =      30--  ��Ѫ	�ޣ�Ĭ����1��
define_battle.MOFAMIANYI = 31--  ħ�����ߣ��κ���Ҳ��ܽ���ָ��ΪĿ�꣩	�ޣ�Ĭ����1��
define_battle.FALIHUAFEI = 32--  ��������	
define_battle.FALI     =   33--  Ӣ�۷�����	�仯�ķ�����ֵ
define_battle.FALISHANGXIAN = 34--  Ӣ�۷�������	�仯�ķ���������ֵ
define_battle.SHOUHU =     35--  ���ܹ������ػ���	�ޣ�Ĭ����1��
define_battle.QUSAN   =    39--  ����ɢ���Ƴ�buff��	�ޣ�Ĭ����1��
define_battle.CHOUPAI  =   40--  ��������	1 ����  2 ����
define_battle.XIAOMIE   =  41--  ����Ч��	�ޣ�Ĭ����1��
define_battle.FANGZHIZHANDOUSHANGHAI =42--  ��ֹս���˺�
define_battle.FZSH   =     43--  ����Ч��	�ޣ�Ĭ����1��
define_battle.FANGJI  =    44--  
define_battle.QUSAN_DEPLOY =49 --  ���ܴ������ּ���
define_battle.CHUANQI  =   98--  ����	�ޣ�Ĭ����1��
define_battle.TESHU    =   99--  ����	�ޣ�Ĭ����1��
define_battle.MINGYUE     =  101--  ����	�ޣ�Ĭ����1��
return define_battle
