#!/bin/bash

#skynet目录
SKYNET_PATH="./3rd/skynet/"


echo "  >>---------- 处理protocbuf ----------"

#mv ./3rd/pbc/Makefile ./3rd/pbc/Makefile.bak
#mv ./3rd/pbc/binding/lua/Makefile ./3rd/pbc/binding/lua/Makefile.bak
#cp ./3rd/pbcMakefile ./3rd/pbc/Makefile
#cp ./3rd/pbcluaMakefile ./3rd/pbc/binding/lua/Makefile
echo "---------------------当前目录------------------"
echo */
echo ">>----------------make binding pbc-----------------------"
echo "---------------------当前目录------------------"
echo */
echo "-----------------------------------------------"
cd ./3rd/pbc/ && make 
echo ">>----------------make binding lua-----------------------"
echo "---------------------当前目录------------------"
echo */
echo "-----------------------------------------------"
cd ./binding/lua/ && make && cd ../../../p/

# 生成协议
#protoc -o ./res/talkbox.pb ./res/talkbox.proto
#protoc -o ./res/login.pb ./res/login.proto
echo "---------------------当前目录------------------"
echo */
echo "-----------------------------------------------"
echo "  >>---------- 处理协议 ----------"
gcc -g -O2 -Wall -I../skynet/3rd/lua   -fPIC --shared ./lua-p.c -o ./p.so && cd ../../


echo "  >>---------- 拷贝协议so模块 ----------"
cp -f ./3rd/pbc/binding/lua/protobuf.lua ./server/lualib/ && cp -f ./3rd/pbc/binding/lua/protobuf.so ./server/luaclib/
cp -f ./3rd/p/p.so ./server/luaclib/



