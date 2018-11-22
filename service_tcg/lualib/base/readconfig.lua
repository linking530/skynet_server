local logstat = require "base.logstat"
require "struct.globle"
local function read_config_line(nLine,fLine,tLine,count,i)
    local size,j,m,iType,id, id0, flag
    local nTmp,cTmp,tag,mtype, file
    local mpConfigTmp, mpTmp
    mpTmp = {};
	for j=1,count,1 do
	   --去掉为0项
	    if nLine[j] ~= "0" then
		   tag = string.format("%s", fLine[j])
		   --去掉标签名中的空格
		   tag = trim(tag)
		   mtype = string.format("%s", tLine[j])
		   --去掉类型名中的空格
		   mtype = trim(mtype)
		   --字符串
		   if mtype == "string" then
			   mpTmp[tag] = nLine[j]
		   --浮点型
		   elseif mtype == "float" then
			   mpTmp[tag] = tonumber(nLine[j])
		   --int型
		   elseif mtype == "int" then
			   mpTmp[tag] = tonumber(nLine[j])
		   else
			   logstat.log_day("read_config.txt",string.format("read_config_line j[%d] type:%s |\n",j,mtype))
		   end
		end
		
	 end --for j=0,count,1
	 
	return mpTmp
end

--读取配置文件
--函数：读取配置文件，适用于配置表中 一对一 或 一对多 的读取
--注意：多对一方式读取出来的数据，同一编号对应一个mapping，此mapping为每条数据为一个数组的集合
--传参格式：config : ({ file, flag(0 一对一/ 1 一对多/ 2 两层mapping) })
--返回值格式：
--      0.一对一：([ key : ([ value ]) ])
--      1.一对多：([ key : ({ ([value1]), ([value2]),  }) ])
--      2.两层mapping：([ key1 : ([key11 : ([value11]), ]),
--                           ([key12: ([value12]), ]) ])

function read_config(name,flag)
    local i,size,j,count,m,iType,id, id0
    local nTmp,cTmp,nLine,cLine,fLine,tLine, tag, mtype, file
    local mpTmp
    cTmp = read_file(name)  
    --logstat.log_day("read_config.txt",string.format("%s \n",cTmp))        
    if  cTmp==nil then
        logstat.log_day("read_config.txt",string.format("配置文件 %s 中无内容\n",name))        
        return {};
	end
    mpConfigTmp ={}
    nTmp = explode(cTmp, "\n")
    --logstat.log_day("read_config.txt",string.format("nTmp \n%s \n",table2json(nTmp)))   
    size=table.getn(nTmp)
    logstat.log_day("read_config.txt",string.format("read size %d \n",size))   
    for i=1,#nTmp do
        cLine = nTmp[i]
        logstat.log_day("read_config.txt",string.format("cLine[%d] %s \n",i,cLine))          
        if cLine~=nil then 
            nLine = explode(cLine,"\t")
        end
        if i == 1 then--首行标签行不能变       
            count = table.getn(nLine)
            logstat.log_day("read_config.txt",string.format("para count %d \n",count))   
            fLine = clone(nLine)
            logstat.log_day("read_config.txt",string.format("fLine %s \n",table2json(fLine))) 
        elseif i == 2 then--字段数据类型行
            count = table.getn(nLine)
            tLine = clone(nLine)
            --logstat.log_day("read_config.txt",string.format("fLine \n%O",table2json(fLine))) 
        else 
            --用首行的标签行属性列数来确定数据项是否正确
            if  table.getn(nLine) ~= count then
                logstat.log_day("read_config.txt",string.format("read item file error. file:%s i:%d gen:%d count:%d\n",name,i,table.getn(nLine),count))
            elseif  cLine~=nil then          
                mpTmp = read_config_line(nLine,fLine,tLine,count,i)
				--nLine[0] ID列不能变
				id = tonumber(nLine[1])
                logstat.log_day("read_config.txt",string.format("flag:%d id:%d\n",flag,id))   				
				if flag==1 then --一对多		   
					if mpConfigTmp[id]==nil then
						mpConfigTmp[id] = {};
					end
					table.insert(mpConfigTmp[id],clone(mpTmp))
				elseif flag==2 then --两层mapping
					id0 = tonumber(nLine[1]); --默认第二列为mapping的第二层key
					if mpConfigTmp[id]==nil then
						mpConfigTmp[id] = {};
					end
					mpConfigTmp[id][id0] = {};
					mpConfigTmp[id][id0] = clone(mpTmp);				
				else --一对一
					mpConfigTmp[id] = {};
					mpConfigTmp[id] = clone(mpTmp);
				end
				
              end

		end

    end--for i=0,size,1
    return clone(mpConfigTmp)  
end