@echo off
rem Started by the self-extracting Setup.exe; the files are in the same temporary folder. "quiet" = no questions (Setup.exe /Q).
set "LOG=%TEMP%\askerp2-setup.log"
set "EXTRA="
if /I "%~1"=="quiet" set "EXTRA=-Quiet"
echo Setup started in %~dp0 %EXTRA% > "%LOG%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0install.ps1" %EXTRA% >> "%LOG%" 2>&1
echo exit code %errorlevel% >> "%LOG%"
exit /b %errorlevel%
