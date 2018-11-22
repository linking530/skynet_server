#!/bin/bash
# echo "please input port:" 
# read PORT

#skynet目录
SKYNET_PATH="./3rd/skynet/"

#日志目录
LOG_PATH="../log/"

#tmp目录
TMP_PATH="../tmp/"

#rm -rf $LOG_PATH $TMP_PATH

pids=`ps aux | grep skynet | awk -F " " '{if($11 != "grep")print $2;}'`
for pid in $pids;do
	kill -9 $pid
done
