from addons.gets import get_js_lines, get_lua_lines, get_settings, get_to_root


def createDefaults() -> None:
    get_to_root()
    language_file_lua = "ext/Shared/Languages/DEFAULT.lua"
    language_file_js = "WebUI/languages/DEFAULT.js"

    allSettings = get_settings(first_key="Text")

    with open(language_file_lua, "w") as outFile:
        outFile.write(
            "local code = 'xx_XX' -- Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)!\n\n"
        )

        outFileLines = get_lua_lines(allSettings)
        for line in outFileLines:
            outFile.write(line + "\n")
        print("Write DEFAULT.lua Done")

    with open(language_file_js, "w") as outFileHtml:
        outFileHtml.write(
            """Language['xx_XX'] /* Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)! */ = {
	"__LANGUAGE_INFO": {
		"name": "English",
		"author": "Unknown",
		"version": "1.0.0"
	},
"""
        )

        outFileLines = get_js_lines()
        for translation in outFileLines:
            outFileHtml.write('	"' + translation + '": "",\n')
        outFileHtml.write("};")
        print("Write DEFAULT.js Done")


if __name__ == "__main__":
    createDefaults()
