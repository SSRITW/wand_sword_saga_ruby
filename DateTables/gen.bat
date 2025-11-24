set WORKSPACE=..
set LUBAN_DLL=%WORKSPACE%\Tools\Luban\Luban.dll
set CONF_ROOT=.

dotnet %LUBAN_DLL% ^
    -t all ^
	-c protobuf3 ^
    -d protobuf3-json ^
    -d protobuf3-bin ^
    --conf %CONF_ROOT%\luban.conf ^
    -x protobuf3-json.outputDataDir=output\json ^
    -x protobuf3-bin.outputDataDir=%WORKSPACE%\game_server\config\pb_datas\data ^
	-x outputCodeDir=output\proto 

cd ..\game_server && bundle exec grpc_tools_ruby_protoc --ruby_out=config/pb_datas/cfg --proto_path=../DateTables/output/proto ../DateTables/output/proto/schema.proto && cd ..\DateTables
pause