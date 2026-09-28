@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0..\..\receiver\p4_7inch"
call "%~dp0..\..\third_party\esp-idf\export.bat" >nul 2>&1
echo === Flashing P4 firmware on COM7 ===
idf.py -p COM7 flash
if errorlevel 1 (
    echo === FLASH FAILED ===
    exit /b 1
)
echo === FLASH SUCCESSFUL ===
