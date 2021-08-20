settings_definition = "../ext/shared/Settings/SettingsDefinition.lua"
config_template = "../ext/shared/Settings/ConfigTemplate.lua"
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
		with open(config_template, "r") as templateFile:
			for line in templateFile.read().splitlines():
				if "[[SETTINGS GET INSERTED HERE]]" in line:
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
				else:
					outFile.write(line + "\n")
		print("write done")