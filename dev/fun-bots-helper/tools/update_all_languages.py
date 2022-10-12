import os
import sys


def updateLanguages(pathToFiles: str) -> None:
    language_file = pathToFiles + "ext/shared/Languages/DEFAULT.lua"
    language_file_js = pathToFiles + "WebUI/languages/DEFAULT.js"

    lua_path = pathToFiles + "ext/shared/Languages"
    js_path = pathToFiles + "WebUI/languages"

    # lua -files
    lua_lines = []
    with open(language_file, "r", encoding="utf8") as inFile:
        lua_lines = inFile.read().splitlines()

    for file in os.listdir(lua_path):
        if file.endswith(".lua"):
            filename = os.path.join(lua_path, file)
            if not "DEFAULT" in filename and not "Languages.lua" in filename:
                # compare files line by line
                with open(filename, "r", encoding="utf8") as compFile:
                    compLines = compFile.read().splitlines()
                    lines_to_remove = []
                    lines_to_add = []
                    for comp_line in compLines:
                        if "Language:add(" in comp_line:
                            lines_to_remove.append(comp_line)

                    for line in lua_lines:
                        if "Language:add(" in line:
                            line_found = False
                            comp_part = line.split('",')[0]
                            # check if comp-part is in other file:
                            for comp_line in compLines:
                                if "Language:add(" in comp_line:
                                    comp_part_2 = comp_line.split('",')[0]
                                    if comp_part == comp_part_2:
                                        line_found = True
                                        if comp_line in lines_to_remove:
                                            lines_to_remove.remove(comp_line)
                                        break
                            if line_found == False:
                                lines_to_add.append(line)
                    for remove_line in lines_to_remove:
                        compLines.remove(remove_line)
                    for add_line in lines_to_add:
                        compLines.append(add_line)
                    with open(filename, "w", encoding="utf8") as outFile:
                        for line in compLines:
                            outFile.write(line + "\n")
                print(filename + " done.")

    # js -files
    js_lines = []
    with open(language_file_js, "r", encoding="utf8") as inFile:
        js_lines = inFile.read().splitlines()

    for file in os.listdir(js_path):
        if file.endswith(".js"):
            filename = os.path.join(js_path, file)
            if not "DEFAULT" in filename:
                # compare files line by line
                with open(filename, "r", encoding="utf8") as compFile:
                    compLines = compFile.read().splitlines()
                    lines_to_remove = []
                    lines_to_add = []
                    for comp_line in compLines[6:]:
                        if ":" in comp_line:
                            lines_to_remove.append(comp_line)

                    for line in js_lines[6:]:
                        if ":" in line:
                            line_found = False
                            comp_part = (
                                line.split('": ')[0].replace(" ", "").replace("	", "")
                            )
                            # check if comp-part is in other file:
                            for comp_line in compLines[6:]:
                                if ":" in line:
                                    comp_part_2 = (
                                        comp_line.split('": ')[0]
                                        .replace(" ", "")
                                        .replace("	", "")
                                    )
                                    if comp_part == comp_part_2:
                                        line_found = True
                                        if comp_line in lines_to_remove:
                                            lines_to_remove.remove(comp_line)
                                        break
                            if line_found == False:
                                lines_to_add.append(line)
                    for remove_line in lines_to_remove:
                        compLines.remove(remove_line)
                    for add_line in lines_to_add:
                        compLines.insert(-1, add_line)
                    with open(filename, "w", encoding="utf8") as outFile:
                        for line in compLines:
                            outFile.write(line + "\n")
                print(filename + " done.")


if __name__ == "__main__":
    pathToFiles = "./"
    if len(sys.argv) > 1:
        pathToFiles = sys.argv[1]
    updateLanguages(pathToFiles)
