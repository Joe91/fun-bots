"""For now, en_EN.lua and en_EN.js are created out of DEFAULTs with:

python3 auto_translate.py en 

Python 3.xx required!
"""
import sys

sys.path.insert(1, "../")

from addons.go_back_to_root import go_back_to_root
from addons.retrieves import (retrieve_lines_js, retrieve_lines_lua,
                              retrieve_settings)


def createDefaults() -> None:
    go_back_to_root()
    language_file = "ext/Shared/Languages/DEFAULT.lua"
    language_file_js = "WebUI/languages/DEFAULT.js"

    allSettings = retrieve_settings(first_key="Text")

    # Creating DEFAULT.lua
    with open(language_file, "w") as outFile:
        # Header
        outFile.write(
            "local code = 'xx_XX' -- Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)!\n\n"
        )

        # Lines
        outFileLines = retrieve_lines_lua(allSettings)
        for line in outFileLines:
            outFile.write(line + "\n")
        print("Write DEFAULT.lua Done")

    # Creating DEFAULT.js
    with open(language_file_js, "w") as outFileHtml:
        # Header
        outFileHtml.write(
            """Language['xx_XX'] /* Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)! */ = {
	"__LANGUAGE_INFO": {
		"name": "English",
		"author": "Unknown",
		"version": "1.0.0"
	},
"""
        )

        # Lines
        outFileLines = retrieve_lines_js()
        for translation in outFileLines:
            outFileHtml.write('	"' + translation + '": "",\n')
        outFileHtml.write("};")
        print("Write DEFAULT.js Done")


if __name__ == "__main__":
    createDefaults()
