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
        # calc tabs
        width = len(tempString) + 3  # tab in the beginning
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

    # other files with Language content : Language:I18N(
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

    allHtmlTranslations = []

    with open(index_html, "r") as inFileHtml:
        for line in inFileHtml.read().splitlines():
            if 'data-lang="' in line:
                translationHtml = line.split('data-lang="')[1].split('"')[0]
                if translationHtml not in allHtmlTranslations:
                    allHtmlTranslations.append(translationHtml)
        for fileName in listOfJsTranslationFiles:
            with open(fileName, "r") as fileWithTranslation:
                for line in fileWithTranslation.read().splitlines():
                    if "I18N('" in line:
                        translation = line.split("I18N('")[1]
                        translation = translation.split("'")[0]
                        if translation not in allHtmlTranslations:
                            allHtmlTranslations.append(translation)

    print("JS Lines Retrieved")

    return allHtmlTranslations
