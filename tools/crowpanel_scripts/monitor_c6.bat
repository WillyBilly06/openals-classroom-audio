@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
call "%~dp0..\..\third_party\esp-idf\export.bat" >nul 2>&1
cd /d "%~dp0..\..\receiver\c6_bridge"
idf.py -p COM13 monitor
