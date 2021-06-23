import re
import operator
# All GameModes
# 				  "TDM", "TDM CQ", "Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large" "GM", "CQ Dom", "Scavanger", "CTF"
GameModesToUse = ["TDM", "SDM", "TDM CQ", "Rush", "SQ Rush", "CQ Small", "CQ Large", "Assault", "Assault 2", "Assault Large" "GM", "CQ Dom", "Scavanger", "CTF"]
RoundsToUse = 1
AddComment = True # True or False

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

inFile = "readme.md"
outFile = "MapList.txt"
triggerString = "|---	|---	|---	|---	|"

mapItems = []

def createEnty(data):
	# extract MapName
	mapname = data[2].split("`")[1]
	#print(mapname)

	# extract gamemodes
	gameModes = []
	tempGamemodes = data[4].split(",")
	for item in tempGamemodes:
		if len(item) > 0:
			gameModes.append(item.split("`")[1])
	#print(gameModes)

	for mode in gameModes:
		tempTable = [mapname, GameModeTranslations[mode], str(RoundsToUse)]
		if AddComment:
			comment = "#" + data[3].split("**")[1] + " - " + mode
			tempTable.append(comment)
		
		mapItems.append(tempTable)
		#print(tempTable)

with open(inFile, 'r') as inputFile:
	extractData = False
	for line in inputFile.readlines():
		if extractData:
			data = line.split("|")
			if len(data) >= 5:
				createEnty(data)
			else:
				print("import done")
				break
		if triggerString in line:
			extractData = True
	
	#sort the list by gamemode
	mapItems = sorted(mapItems, key=operator.itemgetter(2, 1))
	#print(mapItems)

with open(outFile, 'w') as output:
	for item in mapItems:
		tempLine = " ".join(item) + "\n"
		output.write(tempLine)
	print("write done")