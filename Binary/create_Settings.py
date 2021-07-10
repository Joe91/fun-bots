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
		outFile.write("	-- Debugging will show extra output, both in-game using the VU console and in the server console.\n")
		outFile.write("	-- 0 = All messages. (All)\n")
		outFile.write("	-- 1 = Highly detailed tracing messages. Produces the most voluminous output. (High)\n")
		outFile.write("	-- 2 = Info - Informational messages that might make sense to end users and server administrators. (Info)\n")
		outFile.write("	-- 3 = Potentially harmful situations of interest to end users or system managers that indicate potential problems. (Warn)\n")
		outFile.write("	-- 4 = Error events of considerable importance that will prevent normal program execution, but might still allow the application to continue running. (Error)\n")
		outFile.write("	-- 5 = Only critical errors and general output (Fatal)\n")
		outFile.write("	DebugLevel = 4, -- default: 4 (recommended)\n")
		outFile.write("\n")
		outFile.write("	AutoUpdater = {\n")
		outFile.write("		-- Enabling the auto updater will show you a notification when a new update for fun-bots is available for download.\n")
		outFile.write("		-- Please note that we do not support outdated versions.\n")
		outFile.write("		Enabled = true, -- default: true (recommended)\n")
		outFile.write("\n")
		outFile.write("		-- Do you want notifications when newer development builds are available?\n")
		outFile.write("		DevBuilds = true,\n")
		outFile.write("	},\n\n")

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

		outFile.write("\n")
		outFile.write("	-- Version related (do not modify)\n")
		outFile.write("	Version = {\n")
		outFile.write("		Tag = 'V2.1.0', -- Do not modify this value!\n")
		outFile.write("	},\n")
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


