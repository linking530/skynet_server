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

local task_ctrl = {}
local task_send = {}

function task_ctrl.do_task_finish( me, taskArr, taskNum, id, i)

   if task_ctrl.task_finish(me, taskArr[i])~=nil then
        --[0x4103 %d][任务ID %d]                  删除任务
         --send_user(me,"%d%d",0x4103,id);  
   end
	
end

--quest_type 任务类型
--1：赢得x场对战胜利
--2：消灭x只怪物
--3：使用x张卡牌
--4：使用x次部队或英雄的主动技能
--5：进行x场对战（无论输赢）
--restrictions:对战限制
--0：没限制（好友对战除外）
--1：必须是PVP才有效
--camp就是完成该任务必须指定使用哪个派系的卡牌（只要套牌的装备牌中包含这个派系即可）
--0：就是没有限制
--1~5：对应5个派系
function task_ctrl.check_task( me, quest_type, restrictions, camp)
{
    local id,num,i;
    local info;
    local taskArr;
    local taskNum;

--    taskArr = me->get_save_2("daily.ids");
--    taskNum = me->get_save_2("daily.idnum");
                

--    for(i=0; i<sizeof(taskArr); i++)
--    {
--            id = taskArr[i];
--            num = taskNum[i];
--            if(undefinedp(mpDailyTask[id]))
--                    continue;
--            //info = me->get_daily_info(id);
--            log_file("dyh.txt", sprintf("mpDailyTask[%O]:%O\n",id,mpDailyTask[id]));
--            if(to_int(mpDailyTask[id]["quest_type"])==quest_type)
--            {
--                if(quest_type==DO_LEV)
--                {
--                    if(me->get_level()>=to_int(mpDailyTask[id]["amount"]))
--					{
--                        __FILE__->do_task_finish(me, taskArr, taskNum, id,i); 
--						taskNum[i] = -1;
--						taskArr[i] = -1;
--					}
--					else
--					{
--				        taskNum[i]=me->get_level();
--                        send_user(me,"%d%d%d",0x4101,taskArr[i],taskNum[i]); 
--					}	
--                    continue;
--                }
--				else if(quest_type==DO_SC)
--                {
--                    if(me->get_score()>=to_int(mpDailyTask[id]["amount"]))
--					{
--                        __FILE__->do_task_finish(me, taskArr, taskNum, id,i);
--						taskNum[i] = -1;
--						taskArr[i] = -1;
--					}
--					else
--					{
--				        taskNum[i]=me->get_score();
--                        send_user(me,"%d%d%d",0x4101,taskArr[i],taskNum[i]); 
--					}					
--                    continue;
--                }                
--				else if(restrictions==0||to_int(mpDailyTask[id]["restrictions"])==restrictions)
--                {
--                  
--                    if((camp==0)||(__FILE__->IsSameCamp(mpDailyTask[id]["camp"],camp)))
--                    {
--                      
--                        taskNum[i]=taskNum[i]+1;
--                        send_user(me,"%d%d%d",0x4101,taskArr[i],taskNum[i]); 
--                         
--                        if(taskNum[i]>=to_int(mpDailyTask[id]["amount"]))
--                        {
--                            __FILE__->do_task_finish(me, taskArr, taskNum, id,i); 
--							taskNum[i] = -1;
--							taskArr[i] = -1;
--						
--                        }
--
--                    }
--                }    
--            }
--   
--    }
--    if(taskNum)
--	    taskNum -= ({-1});
--	if(taskArr)
--	    taskArr -= ({-1});	
--    me->set_save_2("daily.ids",taskArr);
--    me->set_save_2("daily.idnum",taskNum);	
end



--完成任务
function task_ctrl.task_finish( me,  task)

--	int type,count, starCount,id,i;
--	int *task_list;
--	string arg, strTmp, reward, need, *strKey, *strKey_1;
--	
--	if (undefinedp(mpDailyTask[task])) return;	
--	    
--//    reward = mpDailyTask[task][strTmp];
--//    strKey = explode(reward,",");
--
--//============================给予奖励===============================
--    DEBUG(sprintf("finish task %d",task));
--    
--	if(mpDailyTask[task]["exp_reward"])
--		me->add_exp(mpDailyTask[task]["exp_reward"]); 
--	if(mpDailyTask[task]["gold_reward"])	
--		me->add_gold(mpDailyTask[task]["gold_reward"]); //增加游戏币  
--	if(mpDailyTask[task]["gem_reward"])	
--		me->add_gem(mpDailyTask[task]["gem_reward"]);
--	if(mpDailyTask[task]["fame_reward"])		
--		me->add_score(mpDailyTask[task]["fame_reward"]);
--    tell_user(me,sprintf("finish task %d",task));    
--    id = mpDailyTask[task]["card__reward"];
--	
--    if((id>0)&& (id < 100000) )//装备
--        me->add_all_equips(id,1);    
--    if( (id>0)&&(id >= 100000) )//卡牌
--        me->add_all_cards(id,1);
--    
--    if(mpDailyTask[task]["pack__reward"])
--    strKey = explode(mpDailyTask[task]["pack__reward"],"#");
--    for(i = 0; i<sizeof(strKey);i++)
--    {
--        if(strKey[i])
--            me->add_pack(to_int(strKey[i]),1);
--    }
--    if(mpDailyTask[task]["pack__reward"])
--        "sys/item/shop"->send_pack_info(me);
--    
--    
--    
--//===================================================================
--    return 1;
end



--刷新时间,
function task_ctrl.refresh_daily_list(object me)
--    mixed *time;
--    int day,size,i,task_id;
--    int* taskArr = ({});
--    int* taskNum = ({});
--    int*taskArr2;
--    //me->set_save_2("daily.date",0);
--    day = to_int(me->get_save_2("daily.date"));     //日期
--    time = localtime(get_party_time());
--    //log_file("dyh.txt", sprintf("time[7] = %d, day = %d",time[7],day));
--    
--    if(time[7] != day)      //和记录日期不同，刷新列表，次数清零
--    {
--            me->set_save_2("daily.date",time[7]);
--            for(i=0; i<5; i++)
--            {
--                task_id = get_rand_task(me);
--		taskArr = taskArr+({task_id}) ;	
--		taskNum = taskNum+({0});                
--                
--                //log_file("dyh.txt", sprintf("task_id=%O\n",task_id ));   
--            }
--            //log_file("dyh.txt", sprintf("taskArr=%O\n",taskArr ));              
--            me->set_save_2("daily.ids",taskArr);
--            me->set_save_2("daily.idnum",taskNum);
--            taskArr2 = me->get_save_2("daily.ids" );
--             //log_file("dyh.txt", sprintf("taskArr2=%O\n",taskArr2));               
--            
--            __FILE__->send_daily_list(me); 
--
--    }
end

function task_ctrl.refresh_task(object me, int id)
--
--    mixed *time;
--    int day,size,i,task_id;
--    int* taskArr,* taskNum = ({});
--    
--    taskArr = me->get_save_2("daily.ids");
--    taskNum = me->get_save_2("daily.idnum");
--    
--    size = sizeof(taskArr);
--    for(i=0; i<size; i++)
--    {
--        if(id == taskArr[i])
--        {    
--            taskArr[i] = get_rand_task(me);
--            taskNum[i] = 0;
--            __FILE__->send_daily_list(me);              
--            break;
--        }
--
--    }  

end


--根据权重probability随机返回一个任务
function task_ctrl.get_rand_task(object me)
--    int i,size,pro,pro0,num,randTotal,taskArr;
--
--    size = sizeof(mpDailyTask);
--   
--    pro0 = 0;
--    randTotal = 0;
--    for(i = 1; i <= size; i++)
--    {
--    //log_file("dyh.txt", sprintf("mpDailyTask[%O]=%O",i,mpDailyTask[i], ));   
--        if(undefinedp(mpDailyTask[i]))
--            break;  
--        if(me->get_level()>=mpDailyTask[i]["limit_lv"])
--            randTotal += to_int(mpDailyTask[i]["probability"]);
--    }
--    //log_file("dyh.txt", sprintf("randTotal=%O\n",randTotal ));   
--    
--    if(randTotal==0)
--        return 0;
--    
--    pro = random(randTotal) + 1;
--    //log_file("dyh.txt", sprintf("pro=%O\n",pro ));       
--    for(i = 1; i <= size; i++)
--    {
--        if(!undefinedp(mpDailyTask[i]))    
--            pro0 += to_int(mpDailyTask[i]["probability"]);
--        //随机到，跳出
--        if(pro >= pro0) break;
--        if(i == size) return 0; //最后一个还是没有随机到，需返回
--    }
--    if(HaveTask(me,mpDailyTask[pro]["quest_id"]))
--    {
--        return get_rand_task(me);
--    }        
--    return to_int(mpDailyTask[pro]["quest_id"]);
end

--玩家身上有这个任务返回1，否则返回0
function task_ctrl.HaveTask(object me,int id)
--    int* taskArr,size,i;
--    
--    taskArr = me->get_save_2("daily.ids");
--    size = sizeof(taskArr); 
--    for(i = 0; i < size; i++)
--    {
--        if(to_int(taskArr[i])==id)
--            return 1;
--    }
--    return 0;
end


--发送日常任务列表
function task_ctrl.send_daily_list(object me)
--    int i, id,num;
--    mixed *info;
--    int* taskArr;
--    int* taskNum;
--    taskArr = me->get_save_2("daily.ids");
--    taskNum = me->get_save_2("daily.idnum");
--                
--    send_user(me,"%d%c",0x4102,0);
--    DEBUG_MSG("list start");
--    
--    for(i=0; i<sizeof(taskArr); i++)
--    {
--            id = taskArr[i];
--            num = taskNum[i];
--            if(undefinedp(mpDailyTask[id]))
--				continue;
--            //info = me->get_daily_info(id);
--            if(id>0)
--				send_user(me,"%d%d%d",0x4101,id,num);  
--            //tell_user(me,sprintf("%d%d%d",0x4101,id,num));      
--    }
--    send_user(me,"%d%c",0x4102,1);

end

return task_ctrl