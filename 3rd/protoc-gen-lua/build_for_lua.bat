rem �л���.protoЭ�����ڵ�Ŀ¼
cd E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo


XCOPY E:\kebie\skynet_server\server-master\res\*.proto E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\	/s/y/i



rem ����ǰ�ļ����е�����Э���ļ�ת��Ϊlua�ļ�
for %%i in (*.proto) do (  
echo %%i
"..\protoc.exe" --plugin=protoc-gen-lua="..\plugin\protoc-gen-lua.bat" --lua_out=. %%i

)

XCOPY E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\*.*	F:\phone\QuickGame\res\pb\ /s/y/i

XCOPY E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\*.*	F:\phone\QuickGame\src\netpbc\pb\ /s/y/i

XCOPY E:\kebie\skynet_server\server-master\3rd\protoc-gen-lua\proto_demo\*.*	E:\kebie\skynet_server\server-master\res\ /s/y/i


echo end
pause