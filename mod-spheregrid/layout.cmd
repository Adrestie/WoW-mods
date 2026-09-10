@echo off
rem ===========================================================================
rem  layout.cmd - the layout editor, out of the game.
rem
rem  It draws a grid from the bank of cluster shapes, paints what its cells
rem  grant, and writes the SQL the module ships. The in-game editor
rem  (.spheregrid editor) writes the same XML in the same folder, and this
rem  window follows what the game saves while it is open.
rem
rem    layout.cmd                       an empty window
rem    layout.cmd <layout.xml>          that layout, opened
rem
rem  It needs Python 3 with Pillow and numpy; tkinter comes with Python on
rem  Windows.
rem ===========================================================================
setlocal
set "TOOL=%~dp0tools\layout_editor.py"

if not exist "%TOOL%" (
    echo Not found: "%TOOL%"
    exit /b 1
)

where py >nul 2>&1
if %errorlevel%==0 (
    py -3 "%TOOL%" %*
) else (
    python "%TOOL%" %*
)

rem A window that closes on an error would take the reason with it.
if errorlevel 1 pause
endlocal
