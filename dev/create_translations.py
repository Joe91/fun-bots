settings_definition = "../ext/shared/Settings/SettingsDefinition.lua"
language_file = "../ext/shared/Languages/DEFAULT.lua"

# other files with Language content : Language:I18N(

listOfTranslationFiles = [
	"../ext/Client/ClientNodeEditor.lua",
	"../ext/Server/BotSpawner.lua",
	"../ext/Server/UIServer.lua",
	"../ext/Shared/NodeCollection.lua"]

with open(settings_definition, "r") as inFile:
	readoutActive = False
	allSettings = []
	setting = {}
	numberOfSettings = 0
	for line in inFile.read().splitlines():
		if "Elements = {" in line:
			readoutActive = True
		if readoutActive:
			if "Text = " in line:
				setting["Text"] = line.split('"')[-2]
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

	with open(language_file, "w") as outFile:
		outFile.write("local code = 'xx_XX' -- Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)!\n\n")
		lastCategory = None
		for setting in allSettings:
			if setting["Category"] != lastCategory:
				if lastCategory != None:
					outFile.write("\n")
				outFile.write("--"+setting["Category"]+"\n")
				lastCategory = setting["Category"]
			outFile.write("Language:add(code, \""+setting["Text"] + "\", \"\")\n")
			outFile.write("Language:add(code, \""+setting["Description"] + "\", \"\")\n")
		
		# scan the other files
		allOtherTranslations = []
		for fileName in listOfTranslationFiles:
			outFile.write("\n-- Strings of "+ fileName + "\n")
			with open(fileName, "r") as fileWithTranslation:
				for line in fileWithTranslation.read().splitlines():
					if "Language:I18N(" in line:
						translation = line.split("Language:I18N(")[1]
						translation = translation.split(translation[0])[1]
						if translation != "":
							outFile.write("Language:add(code, \""+ translation + "\", \"\")\n")
		print("write done")