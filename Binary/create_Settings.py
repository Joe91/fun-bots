settings_definition = "../ext/Server/UI/SettingsDefinition.lua"
config_file = "../ext/shared/Config.lua"


with open(settings_definition, "r") as inFile:
	readoutActive = False
	allSettings = []
	setting = {}
	numberOfSettings = 0
	for line in inFile.read().splitlines():
		if "Elements = {" in line:
			readoutActive = True
		if readoutActive:
			if "Name = " in line:
				setting["Name"] = line.split('"')[-2]
			if "Default =" in line:
				setting["Default"] = line.split('=')[-1].replace(",", "").replace(" ", "")
			if "Description =" in line:
				setting["Description"] = line.split('"')[-2]
			if "Category =" in line:
				setting["Category"] = line.split('"')[-2]
			if "}," in line:
				allSettings.append(setting)
				numberOfSettings = numberOfSettings + 1
				setting = {}
	# add last setting
	allSettings.append(setting)
	numberOfSettings = numberOfSettings + 1
	print("import done")
	setting = {}
	
	with open(config_file, "w") as outFile:
		lastCategory = None
		outFile.write("USE_REAL_DAMAGE = true					-- with real damage, the hitboxes are a bit buggy\n")
		outFile.write("BOT_TOKEN = \"BOT_\"						-- token Bots are marked with\n")
		outFile.write("\n")
		outFile.write("Config = {\n")

		for setting in allSettings:
			if setting["Category"] != lastCategory:
				if lastCategory != None:
					outFile.write("\n")
				outFile.write("	--"+setting["Category"]+"\n")
				lastCategory = setting["Category"]
			tempString = "	"+setting["Name"] + " = " + setting["Default"] + ","
			# calc tabs
			width = len(tempString) + 3 #tab in the beginning
			numberOfTabs = (44 - width) // 4
			if ((44 - width) % 4) == 0:
				numberOfTabs = numberOfTabs -1
			if numberOfTabs <= 0:
				numberOfTabs = 1
			outFile.write(tempString + "	" * numberOfTabs +"-- " + setting["Description"] + "\n")
	
		outFile.write("}\n\n")
		outFile.write("-- don't change these values unless you know what you do\n")
		outFile.write("StaticConfig = {\n")
		outFile.write("	TraceDeltaShooting = 0.4,			-- update intervall of trace back to path the bots left for shooting\n")
		outFile.write("	RaycastInterval = 0.05,				-- update intervall of client raycasts\n")
		outFile.write("	BotAttackBotCheckInterval = 0.05,	-- update intervall of client raycasts\n")
		outFile.write("	BotUpdateCycle = 0.1,				-- update-intervall of bots\n")
		outFile.write("	BotAimUpdateCycle = 0.05,			-- = 3 frames at 60 Hz\n")
		outFile.write("	TargetHeightDistanceWayPoint = 1.5	-- distance the bots have to reach in height to continue with next Waypoint\n")
		outFile.write("}\n")
		print("write done")


