@echo off

rem Compile for Source
vuicc.exe "..\WebUI" "..\ui.vuic"

rem Compile for Client
vuicc.exe "..\WebUI" "%localappdata%\VeniceUnleashed\mods\fun-bots\ui.vuic"

pause