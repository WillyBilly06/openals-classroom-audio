@echo off
setlocal
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1
call "%~dp0..\..\third_party\esp-idf\export.bat" >NUL 2>&1
if errorlevel 1 exit /b 1
idf.py -C "%~dp0..\..\receiver\c6_sdio_ota" build
if errorlevel 1 exit /b 1
echo === BUILD SUCCESSFUL ===
endlocal
