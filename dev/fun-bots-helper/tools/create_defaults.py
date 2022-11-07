from loguru import logger

from addons.gets import get_js_lines, get_lua_lines, get_settings, get_to_root


def create_defaults() -> None:
    get_to_root()
    language_file_lua = "ext/Shared/Languages/DEFAULT.lua"
    language_file_js = "WebUI/languages/DEFAULT.js"

    all_settings = get_settings(first_key="Text")

    with open(language_file_lua, "w") as out_file:
        out_file.write(
            "local code = 'xx_XX' -- Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)! \n\n"
        )

        out_file_lines = get_lua_lines(all_settings)
        for line in out_file_lines:
            out_file.write(line + "\n")
        logger.info("DEFAULT.lua has been built")

    with open(language_file_js, "w") as out_file_html:
        out_file_html.write(
            """Language['xx_XX'] /* Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)! */ = {
	"__LANGUAGE_INFO": {
		"name": "English",
		"author": "Unknown",
		"version": "1.0.0"
	},
"""
        )

        out_file_lines = get_js_lines()
        for translation in out_file_lines:
            out_file_html.write('	"' + translation + '": "",\n')
        out_file_html.write("};")
        logger.info("DEFAULT.js has been built")


if __name__ == "__main__":
    create_defaults()
