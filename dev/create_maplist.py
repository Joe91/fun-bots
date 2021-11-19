import sqlite3
import os
from os import walk
import re
import operator
# All GameModes
# 				  "TDM", "TDM CQ", "Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large" "GM", "CQ Dom", "Scavanger", "CTF"
GameModesToUse = ["TDM", "SDM", "TDM CQ", "Rush", "SQ Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large", "GM", "CQ Dom", "Scavanger", "CTF", "Tank Superiority"]
RoundsToUse = 1
#AddComment = True # True or False
MapsWithGunmaster = ["XP2", "XP4"]
MapsWithoutTdmCq = ["XP2"]

AllGameModes = ["TDM", "SDM", "TDM CQ", "Rush", "SQ Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large", "GM", "CQ Dom", "Scavanger", "CTF", "Tank Superiority"]
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
	"CTF": "CaptureTheFlag0",
	"Tank Superiority": "TankSuperiority0"
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
		#find special modes for TDM-Paths
		addTdm = True
		if gameMode == "TDM":
			for token in MapsWithGunmaster:
				if token in mapname:
					tempTable = [mapname, "GunMaster0", str(RoundsToUse)]
					mapItems.append(tempTable)
			for token in MapsWithoutTdmCq:
				if token in mapname:
					addTdm = False
			if addTdm:
				tempTable = [mapname, translatedGamemode, str(RoundsToUse)]
				mapItems.append(tempTable)
			tempTable = [mapname, "TeamDeathMatchC0", str(RoundsToUse)]
			mapItems.append(tempTable)
		else:
			tempTable = [mapname, translatedGamemode, str(RoundsToUse)]
			mapItems.append(tempTable)
	

#sort the list by gamemode
mapItems = sorted(mapItems, key=operator.itemgetter(2, 1))

with open(outFile, 'w') as output:
	for item in mapItems:
		tempLine = " ".join(item) + "\n"
		output.write(tempLine)
	print("write done")


 