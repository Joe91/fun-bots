import os
import sys

sys.path.insert(1, "../")

from addons.gets import get_to_root, get_updated_lines_js, get_updated_lines_lua


def updateLanguages() -> None:
    get_to_root()
    lua_path = "ext/Shared/Languages"
    js_path = "WebUI/languages"

    for file in os.listdir(lua_path):
        if file.endswith(".lua"):
            filename = os.path.join(lua_path, file)
            if not "DEFAULT" in filename and not "Languages.lua" in filename:
                with open(filename, "r", encoding="utf8") as compFile:
                    compLines = get_updated_lines_lua(compFile)
                    with open(filename, "w", encoding="utf8") as outFile:
                        for line in compLines:
                            outFile.write(line + "\n")
                print(filename + " Done")

    for file in os.listdir(js_path):
        if file.endswith(".js"):
            filename = os.path.join(js_path, file)
            if not "DEFAULT" in filename:
                with open(filename, "r", encoding="utf8") as compFile:
                    compLines = get_updated_lines_js(compFile)
                    with open(filename, "w", encoding="utf8") as outFile:
                        for line in compLines:
                            outFile.write(line + "\n")
                print(filename + " Done")


if __name__ == "__main__":
    updateLanguages()
