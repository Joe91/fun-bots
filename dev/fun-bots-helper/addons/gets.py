""" 
This module provides all intermediary functions for the scripts in /tools. All functions here 
(except get_to_root and get_all_tables) return a list that will be used to write the lines of 
external files.
"""

import operator
import os
import sqlite3
from io import TextIOWrapper
from typing import Any, Dict, List, Tuple

from deep_translator import GoogleTranslator


def get_settings(first_key: str) -> List[Dict]:
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
                for key in [f"{first_key} =", "Description =", "Category ="]:
                    if key in line:
                        setting[key[:-2]] = line.split('"')[-2]
                if "Default =" in line:
                    setting["Default"] = (
                        line.split("=")[-1].replace(",", "").replace(" ", "")
                    )
                if "}," in line or (len(setting) != 0 and "}" in line):
                    allSettings.append(setting)
                    numberOfSettings += 1
                    setting = {}

    print("Settings Retrieved")
    return allSettings


def get_settings_lines(allSettings: List[Dict]) -> List[str]:
    outFileLines, lastCategory = [], None

    for setting in allSettings:
        if setting["Category"] != lastCategory:
            outFileLines.append("\n	--" + setting["Category"])
            lastCategory = setting["Category"]
        tempString = "	" + setting["Name"] + " = " + setting["Default"] + ","

        width = len(tempString)
        numberOfTabs = (41 - width) // 4
        if ((41 - width) % 4) == 0:
            numberOfTabs -= 1
        if numberOfTabs <= 0:
            numberOfTabs = 1
        outFileLines.append(
            tempString + "	" * numberOfTabs + "-- " + setting["Description"]
        )
    outFileLines.append("}")

    print("Settings Lines Retrieved")
    return outFileLines


def get_lua_lines(allSettings: List[Dict]) -> List[str]:
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


def __scan_other_files() -> List[str]:
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


def get_js_lines() -> List[str]:
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


def get_map_lines(create: bool = False, update_supported: bool = False) -> List[List]:

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

    filenames = os.listdir("mapfiles")
    for filename in filenames:
        combinedName = filename.split(".")[0]
        nameParts = combinedName.rsplit("_", 1)
        mapname = nameParts[0]
        mapname_splitted = mapname.split("_")[0]
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
                    if mapname_splitted in MapsWithGunmaster:
                        mapItems.append([mapname, "GunMaster0", RoundsToUse])
                    if mapname_splitted not in MapsWithoutTdmCq:
                        mapItems.append([mapname, translatedGamemode, RoundsToUse])
                    mapItems.append([mapname, "TeamDeathMatchC0", RoundsToUse])
                if update_supported:
                    if mapname_splitted in MapsWithGunmaster:
                        mapItems.append([mapname, "GM", "GunMaster0", vehicleSupport])
                    if mapname_splitted not in MapsWithoutTdmCq:
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


def get_all_tables() -> Tuple[sqlite3.Connection, sqlite3.Cursor]:
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()

    sql_instruction = """
		SELECT * FROM sqlite_master WHERE type='table'
	"""
    cursor.execute(sql_instruction)

    return connection, cursor


def get_invalid_node_lines(infile: TextIOWrapper) -> List[str]:
    DISTANCE_MAX = 80

    outFileLines = infile.readlines()
    lastPath, currentPath = 0, 0
    for i in range(2, len(outFileLines) - 2):
        line = outFileLines[i]
        currentitems = line.split(";")
        currentPath = int(currentitems[0])
        posX = float(currentitems[2])
        posY = float(currentitems[3])
        posZ = float(currentitems[4])

        line = outFileLines[i - 1]
        items = line.split(";")
        lastPath = int(items[0])
        lastPosX = float(items[2])
        lastPosY = float(items[3])
        lastPosZ = float(items[4])

        line = outFileLines[i + 1]
        items = line.split(";")
        nextPath = int(items[0])
        nextPosX = float(items[2])
        nextPosY = float(items[3])
        nextPosZ = float(items[4])

        if lastPath == currentPath and nextPath == currentPath:  # Wrong in the middle
            if (
                abs(lastPosX - posX) > DISTANCE_MAX
                or abs(lastPosY - posY) > DISTANCE_MAX
                or abs(lastPosZ - posZ) > DISTANCE_MAX
            ) and (
                abs(nextPosX - posX) > DISTANCE_MAX
                or abs(nextPosY - posY) > DISTANCE_MAX
                or abs(nextPosZ - posZ) > DISTANCE_MAX
            ):
                newPosX = lastPosX + (nextPosX - lastPosX) / 2
                newPosY = lastPosY + (nextPosY - lastPosY) / 2
                newPosZ = lastPosZ + (nextPosZ - lastPosZ) / 2
                currentitems[2] = format(newPosX, ".6f")
                currentitems[3] = format(newPosY, ".6f")
                currentitems[4] = format(newPosZ, ".6f")
                newLineContent = ";".join(currentitems)
                outFileLines[i] = newLineContent
        if lastPath == currentPath and nextPath != currentPath:  # Wrong at the end
            if (
                abs(lastPosX - posX) > DISTANCE_MAX
                or abs(lastPosY - posY) > DISTANCE_MAX
                or abs(lastPosZ - posZ) > DISTANCE_MAX
            ):
                currentitems[2] = format(lastPosX + 0.2, ".6f")
                currentitems[3] = format(lastPosY, ".6f")
                currentitems[4] = format(lastPosY + 0.2, ".6f")
                newLineContent = ";".join(currentitems)
                outFileLines[i] = newLineContent
        if lastPath != currentPath and nextPath == currentPath:  # Wrong at the start
            if (
                abs(nextPosX - posX) > DISTANCE_MAX
                or abs(nextPosY - posY) > DISTANCE_MAX
                or abs(nextPosZ - posZ) > DISTANCE_MAX
            ):
                currentitems[2] = format(nextPosX + 0.2, ".6f")
                currentitems[3] = format(nextPosY, ".6f")
                currentitems[4] = format(nextPosZ + 0.2, ".6f")
                newLineContent = ";".join(currentitems)
                outFileLines[i] = newLineContent

    return outFileLines


def get_objectives_to_rename(infile: TextIOWrapper) -> Tuple[List[str], List[str]]:
    allObjectives = []
    fileLines = infile.readlines()
    for line in fileLines[1:]:
        if '"Objectives":[' in line:
            objectives = line.split('"Objectives":[')[1].split("]")[0].split(",")
            for objective in objectives:
                if objective not in allObjectives:
                    allObjectives.append(objective)
    allObjectives.sort()
    objectivesToRename = [
        objectiveName
        for objectiveName in allObjectives
        if objectiveName.lower() != objectiveName
    ]

    return objectivesToRename, fileLines


def get_translation(translator: Any, line: str) -> str:
    splitted_line = line.split('"')
    splitted_line.remove("")
    splitted_line.insert(3, translator.translate(splitted_line[1]))
    return '"'.join(splitted_line)


def get_updated_lines_lua(compFile: TextIOWrapper) -> List[str]:
    language_file = "ext/Shared/Languages/DEFAULT.lua"
    with open(language_file, "r", encoding="utf8") as inFile:
        lua_lines = inFile.read().splitlines()

    compLines = compFile.read().splitlines()

    LANG = compLines[0].split("'")[1].split("_")[0]
    if LANG == "cn":
        LANG = "zh-CN"

    translator = GoogleTranslator(source="en", target=LANG)

    lines_to_remove = [
        comp_line for comp_line in compLines if "Language:add" in comp_line
    ]
    lines_to_add = []

    for line in lua_lines:
        if "Language:add" in line:
            line_found = False
            comp_part = line.split('",')[0]
            for comp_line in compLines:
                if "Language:add" in comp_line:
                    comp_part_2 = comp_line.split('",')[0]
                    if comp_part == comp_part_2:
                        line_found = True
                        if comp_line in lines_to_remove:
                            lines_to_remove.remove(comp_line)
                        break
            if line_found == False:
                lines_to_add.append(get_translation(translator, line))
    for remove_line in lines_to_remove:
        compLines.remove(remove_line)
    for add_line in lines_to_add:
        compLines.append(add_line)

    return compLines


def get_updated_lines_js(compFile: TextIOWrapper) -> List[str]:
    language_file_js = "WebUI/languages/DEFAULT.js"

    with open(language_file_js, "r", encoding="utf8") as inFile:
        js_lines = inFile.read().splitlines()

    compLines = compFile.read().splitlines()

    LANG = compLines[0].split("'")[1].split("_")[0]
    if LANG == "cn":
        LANG = "zh-CN"
    translator = GoogleTranslator(source="en", target=LANG)

    lines_to_remove = [comp_line for comp_line in compLines[6:] if ":" in comp_line]
    lines_to_add = []

    for line in js_lines[6:]:
        if ":" in line:
            line_found = False
            comp_part = line.split('": ')[0].replace(" ", "").replace("	", "")
            for comp_line in compLines[6:]:
                if ":" in line:
                    comp_part_2 = (
                        comp_line.split('": ')[0].replace(" ", "").replace("	", "")
                    )
                    if comp_part == comp_part_2:
                        line_found = True
                        if comp_line in lines_to_remove:
                            lines_to_remove.remove(comp_line)
                        break
            if line_found == False:
                if line.startswith('\t"') and not line.split(":")[0].startswith('\t""'):
                    lines_to_add.append(get_translation(translator, line))
    for remove_line in lines_to_remove:
        compLines.remove(remove_line)
    for add_line in lines_to_add:
        compLines.insert(-1, add_line)

    return compLines


def get_to_root() -> None:
    cwd_splitted = os.getcwd().replace("\\", "/").split("/")
    new_cwd = "/".join(cwd_splitted[: cwd_splitted.index("fun-bots") + 1])
    os.chdir(new_cwd)
