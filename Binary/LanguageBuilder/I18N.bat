@echo OFF
set CUR_DIR="%CD%"
set NAME_SOURCE="../../WebUI"

SETLOCAL EnableDelayedExpansion
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
	set "DEL=%%a"
)

call :ColorText 0C "I18N - Localization"
echo.
call :ColorText 0C "---"
echo.
echo.

node %CUR_DIR%\GetLanguages.js "%CUR_DIR:"=%\%NAME_SOURCE:"=%"

goto :eof

:ColorText
echo off
<nul set /p ".=%DEL%" > "%~2"
findstr /v /a:%1 /R "^$" "%~2" nul
del "%~2" > nul 2>&1
goto :eof

pause
