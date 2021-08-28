@echo off

rem Compile for Source
"..\.funbots\workflow\ui_generator\vuicc.exe" "..\WebUI" "..\ui.vuic"

rem Compile for Client
"..\.funbots\workflow\ui_generator\vuicc.exe" "..\WebUI" "%localappdata%\VeniceUnleashed\mods\fun-bots\ui.vuic"

pause