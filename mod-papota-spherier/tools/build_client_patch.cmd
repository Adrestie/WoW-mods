@echo off
setlocal
rem mod-papota-spherier - builds Data\patch-S.MPQ for a 3.3.5a client.
rem Usage: build_client_patch.cmd [game folder] [letter]
rem Close the game first. Python 3.8+ (64-bit) must be on the PATH.
set "JEU=%~1"
set "LETTRE=%~2"
if "%JEU%"=="" set /p JEU=Game folder (the one holding Wow.exe): 
if "%LETTRE%"=="" set "LETTRE=S"
python "%~dp0build_client_patch.py" "%JEU%" --lettre %LETTRE%
if errorlevel 1 (
    echo.
    echo The patch was NOT built. Read the message above.
)
pause
