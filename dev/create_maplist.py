import sqlite3
import os
from os import walk
import re
import operator
# All GameModes
# 				  "TDM", "TDM CQ", "Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large" "GM", "CQ Dom", "Scavanger", "CTF"
GameModesToUse = ["TDM", "SDM", "TDM CQ", "Rush", "SQ Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large", "GM", "CQ Dom", "Scavanger", "CTF"]
RoundsToUse = 1
#AddComment = True # True or False


AllGameModes = ["TDM", "SDM", "TDM CQ", "Rush", "SQ Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large", "GM", "CQ Dom", "Scavanger", "CTF"]
GameModeTranslations = {
	"TDM": "TeamDeathMatch0",
	"SDM": "SquadDeathMatch0",
	"TDM CQ": "TeamDeathMatchC0",
	"Rush": "RushLarge0",
	"SQ Rush": "SquadRush0",
	"CQ Small": "ConquestSmall0",
	"CQ Large": "ConquestLarge0",
	"Assault": "ConquestAssaultSmall0",
	"Assault 2": "ConquestAssaultSmall1",
	"Assault Large": "ConquestAssaultLarge0",
	"GM": "GunMaster0",
	"CQ Dom": "Domination0",
	"Scavanger": "Scavenger0",
	"CTF": "CaptureTheFlag0"
}

outFile = "./../MapList.txt"

mapItems = []


filenames = next(walk("./../mapfiles"), (None, None, []))[2]  # [] if no file
for filename in filenames:
    combinedName = filename.split(".")[0]
    nameParts = combinedName.rsplit('_', 1)
    mapname = nameParts[0]
    translatedGamemode = nameParts[1]
    gameMode = ""
    for mode in AllGameModes:
        if GameModeTranslations[mode] == translatedGamemode:
            gameMode = mode
            break
    if gameMode != "" and gameMode in GameModesToUse:
        tempTable = [mapname, translatedGamemode, str(RoundsToUse)]
        mapItems.append(tempTable)
    

#sort the list by gamemode
mapItems = sorted(mapItems, key=operator.itemgetter(2, 1))

with open(outFile, 'w') as output:
	for item in mapItems:
		tempLine = " ".join(item) + "\n"
		output.write(tempLine)
	print("write done")


 