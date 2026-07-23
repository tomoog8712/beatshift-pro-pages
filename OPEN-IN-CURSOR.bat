@echo off
set "ROOT=%~dp0"
start "" "cursor://file/%ROOT:\=/%"
echo Opened: %ROOT%
pause
