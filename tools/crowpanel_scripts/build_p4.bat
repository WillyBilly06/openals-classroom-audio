@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8

echo === Building P4 Firmware ===
cd /d "%~dp0..\..\third_party\esp-idf"
call export.bat

cd /d "%~dp0..\..\receiver\p4_7inch"
idf.py build

if %ERRORLEVEL% EQU 0 (
    echo === BUILD SUCCESSFUL ===
) else (
    echo === BUILD FAILED ===
)
