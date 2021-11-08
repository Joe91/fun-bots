import os
from os import walk
import re
import operator

Template = "Supported-maps-template.md"
OutFile = "./../Supported-maps.md"
PathToMapfiles = "./../mapfiles"
# All GameModes
# 				  "TDM", "TDM CQ", "Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large" "GM", "CQ Dom", "Scavanger", "CTF"
GameModesToUse = ["TDM", "SDM", "TDM CQ", "Rush", "SQ Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large", "GM", "CQ Dom", "Scavanger", "CTF"]
RoundsToUse = 1
#AddComment = True # True or False
MapsWithGunmaster = ["XP2", "XP4"]
MapsWithoutTdmCq = ["XP2"]

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



mapItems = []


filenames = next(walk(PathToMapfiles), (None, None, []))[2]  # [] if no file
for filename in filenames:
	combinedName = filename.split(".")[0]
	nameParts = combinedName.rsplit('_', 1)
	mapname = nameParts[0]
	translatedGamemode = nameParts[1]
	gameMode = ""
	vehicleSupport = False
	with open(PathToMapfiles + "/" + filename, "r") as tempMapFile:
		for line in tempMapFile.readlines():
			if '"Vehicles":[' in line:
				vehicleSupport = True
				break
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
					tempTable = [mapname, "GM", "GunMaster0", vehicleSupport]
					mapItems.append(tempTable)
			for token in MapsWithoutTdmCq:
				if token in mapname:
					addTdm = False
			if addTdm:
				tempTable = [mapname, gameMode, translatedGamemode, vehicleSupport]
				mapItems.append(tempTable)
			tempTable = [mapname, "TDM CQ", "TeamDeathMatchC0", vehicleSupport]
			mapItems.append(tempTable)
		else:
			tempTable = [mapname, gameMode, translatedGamemode, vehicleSupport]
			mapItems.append(tempTable)
	

#sort the list by gamemode
mapItems = sorted(mapItems, key=operator.itemgetter(2, 1))

with open(OutFile, 'w') as output:
	with open(Template, 'r') as template:
		for line in template.readlines():
			allSupportedGameModes = []
			vehicleSupportedGameModes = []
			if "!ALL-GAMEMODES!" in line:
				lineParts = line.split("|")
				if len(lineParts) >= 5:
					mapname = lineParts[2].split("`")[1]
					for item in mapItems:
						if item[0] == mapname:
							allSupportedGameModes.append("`" + item[1] + "`")
							if item[3] == True:
								vehicleSupportedGameModes.append("`" + item[1] + "`")
				line = line.replace("!ALL-GAMEMODES!", " ,".join(allSupportedGameModes))
				line = line.replace("!VEHICLE-GAMEMODES!", " ,".join(vehicleSupportedGameModes))

			output.write(line)
	print("write done")


 