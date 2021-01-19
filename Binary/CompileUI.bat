@echo off

# Compile for Source
vuicc.exe "..\WebUI" "..\ui.vuic"

# Compile for Client
vuicc.exe "..\WebUI" "%localappdata%\VeniceUnleashed\mods\fun-bots\ui.vuic"

pause