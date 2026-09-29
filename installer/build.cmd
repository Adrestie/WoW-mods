@echo off
rem ---------------------------------------------------------------------------
rem  Builds installer.exe, in this folder, from installer.py
rem  (PyInstaller: python -m pip install pyinstaller).
rem
rem  Run again after any change to installer.py, core.py, manifest.py or
rem  mpq_archive.py. A module's manifest (installer.json) is read at run time:
rem  changing it needs no rebuild.
rem
rem  This file must stay pure ASCII with Windows line endings.
rem ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0"
python -m PyInstaller --version >nul 2>&1
if errorlevel 1 (
    echo PyInstaller not found: python -m pip install pyinstaller
    exit /b 1
)
rem Work folder on the same drive as the sources (PyInstaller requires it).
set WORK=%~dp0build
python -m PyInstaller --noconfirm --onefile --console --name installer --distpath . --workpath "%WORK%" --specpath "%WORK%" installer.py
set CODE=%ERRORLEVEL%
rmdir /s /q "%WORK%" 2>nul
rmdir /s /q __pycache__ 2>nul
exit /b %CODE%
