@echo off
rem This file is part of mod-spheregrid.
rem
rem This program is free software; you can redistribute it and/or modify
rem it under the terms of the GNU General Public License as published by
rem the Free Software Foundation; either version 2 of the License, or
rem (at your option) any later version.
rem
rem This program is distributed in the hope that it will be useful, but
rem WITHOUT ANY WARRANTY; without even the implied warranty of
rem MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
rem Public License for more details.
rem
rem You should have received a copy of the GNU General Public License along
rem with this program. If not, see <http://www.gnu.org/licenses/>.
rem
rem Written without parenthesised blocks and without quotes inside SET: both
rem are quiet traps in batch, and this file has to work on a machine nobody
rem here can look at.

setlocal EnableExtensions
title mod-spheregrid
cd /d "%~dp0"

echo.
echo   mod-spheregrid
echo   --------------
echo   A sphere grid for AzerothCore 3.3.5a.
echo.
echo   This looks at your server, keeps a copy of everything it is about to
echo   touch, then places the module and applies its SQL. Nothing is written
echo   before the copies exist.
echo.

rem --- Python ---------------------------------------------------------------
set PY=
where py >nul 2>&1
if not errorlevel 1 set PY=py -3
if not defined PY where python >nul 2>&1
if not defined PY if not errorlevel 1 set PY=python
if not defined PY goto :no_python

rem --- 1. the server --------------------------------------------------------
echo   1. The SERVER directory: the one holding worldserver.exe, with its
echo      configs\ and lua_scripts\ beside it.
set SERVER=
set /p SERVER=      path:
if not defined SERVER goto :nothing_entered
if not exist "%SERVER%\configs" goto :no_configs

rem --- 2. the core ----------------------------------------------------------
echo.
echo   2. The AZEROTHCORE SOURCE directory: the one with a modules\ folder.
echo      The module's sources go there, and you rebuild afterwards.
set CORE=
set /p CORE=      path:
if not defined CORE goto :nothing_entered
if not exist "%CORE%\modules" goto :no_modules

rem --- 3. the client --------------------------------------------------------
echo.
echo   3. The CLIENT's Data directory, the one holding the .MPQ archives.
echo      Leave blank to skip the client; the server half is installed anyway.
set CLIENT=
set /p CLIENT=      path (optional):
set LOCALE=enUS
if not defined CLIENT goto :backup_choice
echo.
echo      Which locale is that client? enUS, frFR, deDE...
set /p LOCALE=      locale [enUS]:
if not defined LOCALE set LOCALE=enUS

rem --- 4. where the copies go -----------------------------------------------
:backup_choice
echo.
echo   4. WHERE TO KEEP THE COPIES.
echo.
echo      [1] In a Backups\ folder inside this module, reproducing each file's
echo          own path underneath it. Everything in one place, kept or thrown
echo          away in one gesture.
echo.
echo      [2] Beside each original, same name with a suffix. Nothing to look
echo          for: the copy is where the file is.
echo.
set PICK=1
set /p PICK=      choice [1]:
set BACKUP=vault
if "%PICK%"=="2" set BACKUP=beside

rem --- 5. what to do --------------------------------------------------------
echo.
echo   5. WHAT TO DO NOW.
echo.
echo      [1] Look only. Reads the server and the client, says which
echo          identifiers are free, writes nothing at all.
echo      [2] Rehearse. Announces every step it would take, writes nothing.
echo      [3] Install.
echo.
set MODE=1
set /p MODE=      choice [1]:
set FLAGS=
if "%MODE%"=="1" set FLAGS=--survey
if "%MODE%"=="2" set FLAGS=--dry-run
echo.
echo   6. IF AN IDENTIFIER IS ALREADY TAKEN on this server or this client,
echo      the module can move its own out of the way -- every file of the
echo      module is rewritten to the new numbers, and you rebuild afterwards.
echo      Say no to be told instead, and decide yourself.
set SHIFT=n
set /p SHIFT=      move them if needed? [y/N]:
if /i "%SHIFT%"=="y" set FLAGS=%FLAGS% --shift
if "%MODE%"=="3" goto :confirm
goto :run

:confirm
echo.
echo   About to write to:
echo     %CORE%\modules\mod-spheregrid
echo     %SERVER%\lua_scripts\SphereGrid
echo     %SERVER%\configs\modules\mod-spheregrid.conf
echo     the world and characters databases
if defined CLIENT echo     %CLIENT%\patch-Z.MPQ
echo.
set GO=
set /p GO=  Type yes to go ahead:
if /i "%GO%"=="yes" goto :run
echo   Nothing was done.
goto :stop

rem --- run ------------------------------------------------------------------
:run
echo.
echo   ------------------------------------------------------------------
if defined CLIENT goto :run_with_client
%PY% "tools\install.py" --server "%SERVER%" --core "%CORE%" --backup %BACKUP% %FLAGS%
goto :ran

:run_with_client
%PY% "tools\install.py" --server "%SERVER%" --core "%CORE%" --client "%CLIENT%" --locale %LOCALE% --backup %BACKUP% %FLAGS%

:ran
set RESULT=%ERRORLEVEL%
echo   ------------------------------------------------------------------
echo.
if not "%RESULT%"=="0" goto :it_stopped
if not "%MODE%"=="3" goto :stop
echo   Done. Two things are left to you:
echo     - rebuild the core, so the module is compiled in;
echo     - AIO must be installed, server side and client side, or no window
echo       ever opens. See the README.
goto :stop

rem --- ways out -------------------------------------------------------------
:no_python
echo   Python 3 was not found on this machine.
echo   Install it from https://www.python.org/downloads/ and run this again.
goto :stop

:no_configs
echo.
echo   There is no configs\ folder under "%SERVER%".
echo   That is not a server directory. Start again with the right path.
goto :stop

:no_modules
echo.
echo   There is no modules\ folder under "%CORE%".
echo   That is not an AzerothCore source tree. Start again.
goto :stop

:nothing_entered
echo.
echo   Nothing entered. Start again when you have the path.
goto :stop

:it_stopped
echo   It stopped. Nothing beyond what is printed above was done.

:stop
echo.
pause
endlocal
