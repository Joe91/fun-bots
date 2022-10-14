import operator
from os import walk
from typing import List


def retrieve_settings(first_key: str) -> List:
    settings_definition = "ext/Shared/Settings/SettingsDefinition.lua"

    with open(settings_definition, "r") as inFile:
        readoutActive = False
        allSettings = []
        setting = {}
        numberOfSettings = 0
        for line in inFile.read().splitlines():
            if "Elements = {" in line:
                readoutActive = True
            if readoutActive:
                if f"{first_key} = " in line:
                    setting[first_key] = line.split('"')[-2]
                if "Default =" in line:
                    setting["Default"] = (
                        line.split("=")[-1].replace(",", "").replace(" ", "")
                    )
                if "Description =" in line:
                    setting["Description"] = line.split('"')[-2]
                if "Category =" in line:
                    setting["Category"] = line.split('"')[-2]
                if "}," in line or (len(setting) != 0 and "}" in line):
                    allSettings.append(setting)
                    numberOfSettings += 1
                    setting = {}

    print("Settings Retrieved")
    return allSettings


def retrieve_lines_settings(allSettings: List) -> List:
    outFileLines, lastCategory = [], ""

    for setting in allSettings:
        if setting["Category"] != lastCategory:
            outFileLines.append("\n	--" + setting["Category"])
            lastCategory = setting["Category"]
        tempString = "	" + setting["Name"] + " = " + setting["Default"] + ","

        width = len(tempString) + 3
        numberOfTabs = (44 - width) // 4
        if ((44 - width) % 4) == 0:
            numberOfTabs = numberOfTabs - 1
        if numberOfTabs <= 0:
            numberOfTabs = 1
        outFileLines.append(
            tempString + "	" * numberOfTabs + "-- " + setting["Description"]
        )
    outFileLines.append("}")

    print("Settings Lines Retrieved")
    return outFileLines


def retrieve_lines_lua(allSettings: List) -> List:
    outFileLines = []

    lastCategory = None
    for setting in allSettings:
        if setting["Category"] != lastCategory:
            if lastCategory != None:
                outFileLines.append("")
            outFileLines.append("--" + setting["Category"])
            lastCategory = setting["Category"]
        outFileLines.append('Language:add(code, "' + setting["Text"] + '", "")')
        outFileLines.append('Language:add(code, "' + setting["Description"] + '", "")')

    print("Lua Lines Retrieved")
    outFileLines.extend(__scan_other_files())
    print("All Lua Lines Retrieved")
    return outFileLines


def __scan_other_files() -> List:
    listOfTranslationFiles = [
        "ext/Client/ClientNodeEditor.lua",
        "ext/Server/BotSpawner.lua",
        "ext/Server/UIServer.lua",
        "ext/Server/NodeCollection.lua",
    ]
    outFileLinesOthers = []
    for fileName in listOfTranslationFiles:
        outFileLinesOthers.append("\n-- Strings of " + fileName)
        with open(fileName, "r") as fileWithTranslation:
            for line in fileWithTranslation.read().splitlines():
                if "Language:I18N(" in line:
                    translation = line.split("Language:I18N(")[1]
                    translation = translation.split(translation[0])[1]
                    if translation != "":
                        newLine = 'Language:add(code, "' + translation + '", "")'
                        if newLine not in outFileLinesOthers:
                            outFileLinesOthers.append(newLine)

    print("Lua Lines Retrieved from Other Files")
    return outFileLinesOthers


def retrieve_lines_js() -> List:
    index_html = "WebUI/index.html"
    listOfJsTranslationFiles = [
        "WebUI/classes/EntryElement.js",
        "WebUI/classes/BotEditor.js",
    ]

    outFileLines = []

    with open(index_html, "r") as inFileHtml:
        for line in inFileHtml.read().splitlines():
            if 'data-lang="' in line:
                translationHtml = line.split('data-lang="')[1].split('"')[0]
                if translationHtml not in outFileLines:
                    outFileLines.append(translationHtml)
        for fileName in listOfJsTranslationFiles:
            with open(fileName, "r") as fileWithTranslation:
                for line in fileWithTranslation.read().splitlines():
                    if "I18N('" in line:
                        translation = line.split("I18N('")[1]
                        translation = translation.split("'")[0]
                        if translation not in outFileLines:
                            outFileLines.append(translation)

    print("JS Lines Retrieved")
    return outFileLines


def retrieve_lines_maps(create: bool = False, update_supported: bool = False) -> List:

    AllGameModes = [
        "TDM",
        "SDM",
        "TDM CQ",
        "Rush",
        "SQ Rush",
        "CQ Small",
        "CQ Large",
        "Assault",
        "Assault 2",
        "Assault Large",
        "GM",
        "CQ Dom",
        "Scavanger",
        "CTF",
        "Tank Superiority",
    ]
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
        "Tank Superiority": "TankSuperiority0",
    }

    if create:
        RoundsToUse = "1"
        MapsWithGunmaster = ["XP2", "XP4"]
        MapsWithoutTdmCq = ["XP2"]

    if update_supported:
        MapsWithGunmaster = ["XP2", "XP4", "sp_", "coop_"]
        MapsWithoutTdmCq = ["XP2", "sp_", "coop_"]

    mapItems = []

    filenames = next(walk("mapfiles"), (None, None, []))[2]
    for filename in filenames:
        combinedName = filename.split(".")[0]
        nameParts = combinedName.rsplit("_", 1)
        mapname = nameParts[0]
        translatedGamemode = nameParts[1]
        gameMode = ""

        if update_supported:
            vehicleSupport = False
            with open("mapfiles" + "/" + filename, "r") as tempMapFile:
                for line in tempMapFile.readlines():
                    if '"Vehicles":[' in line:
                        vehicleSupport = True
                        break

        for mode in AllGameModes:
            if GameModeTranslations[mode] == translatedGamemode:
                gameMode = mode
                break

        if gameMode in AllGameModes:
            if gameMode == "TDM":
                if create:
                    if mapname.split("_")[0] in MapsWithGunmaster:
                        mapItems.append([mapname, "GunMaster0", RoundsToUse])
                    if mapname.split("_")[0] not in MapsWithoutTdmCq:
                        mapItems.append([mapname, translatedGamemode, RoundsToUse])
                    mapItems.append([mapname, "TeamDeathMatchC0", RoundsToUse])
                if update_supported:
                    if mapname.split("_")[0] in MapsWithGunmaster:
                        mapItems.append([mapname, "GM", "GunMaster0", vehicleSupport])
                    if mapname.split("_")[0] not in MapsWithoutTdmCq:
                        mapItems.append(
                            [mapname, gameMode, translatedGamemode, vehicleSupport]
                        )
                    mapItems.append(
                        [mapname, "TDM CQ", "TeamDeathMatchC0", vehicleSupport]
                    )
            else:
                if create:
                    mapItems.append([mapname, translatedGamemode, RoundsToUse])
                if update_supported:
                    mapItems.append(
                        [mapname, gameMode, translatedGamemode, vehicleSupport]
                    )

    mapItems = sorted(mapItems, key=operator.itemgetter(2, 1))

    return mapItems
