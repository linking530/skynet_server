rem 切换到.proto协议所在的目录
cd E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo


XCOPY E:\kebie\skynet_server\server-master\res\*.proto E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\	/s/y/i



rem 将当前文件夹中的所有协议文件转换为lua文件
for %%i in (*.proto) do (  
echo %%i
"..\protoc.exe" --plugin=protoc-gen-lua="..\plugin\protoc-gen-lua.bat" --lua_out=. %%i

)

XCOPY E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\*.*	F:\phone\QuickGame\res\pb\ /s/y/i

XCOPY E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\*.*	F:\phone\QuickGame\src\netpbc\pb\ /s/y/i

XCOPY E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\*.*	E:\kebie\skynet_server\server-master\res\ /s/y/i


echo end
pause