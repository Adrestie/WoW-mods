@echo off
setlocal
rem mod-papota-spherier - adds the module's rows to the server's DBC files.
rem Usage: patch_server_dbc.cmd [server Data\dbc folder]
rem Stop the worldserver first. Python 3.8+ (64-bit) must be on the PATH.
set "DBC=%~1"
if "%DBC%"=="" set /p DBC=Server Data\dbc folder: 
python "%~dp0build_client_patch.py" --serveur "%DBC%"
if errorlevel 1 (
    echo.
    echo The DBC files were NOT patched. Read the message above.
)
pause
