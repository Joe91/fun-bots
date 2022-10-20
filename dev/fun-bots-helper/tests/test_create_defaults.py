"""Execute the inner functions of tools/create_defaults.py to create temporary files and 
compare them with the original default files already merged on dev branch. This test should 
be executed first after any refactoring in get_js_lines, get_lua_lines and get_settings, by 
doing this we will ensure that they are creating the same files."""


from filecmp import cmp

from addons.gets import get_js_lines, get_lua_lines, get_settings, get_to_root


def test_create_defaults(tmp_path) -> None:
    """Key arguments.

    tmp_path: built-in pytest fixture to create Pathlib temporary files"""
    get_to_root()
    original_language_file_lua = "ext/Shared/Languages/DEFAULT.lua"
    d = tmp_path / "sub"
    d.mkdir()
    temp_file_lua_path = d / "temp_file.lua"

    allSettings = get_settings(first_key="Text")
    with temp_file_lua_path.open("a") as temp_file_lua:
        temp_file_lua.write(
            "local code = 'xx_XX' -- Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)!\n\n"
        )
        outFileLines = get_lua_lines(allSettings)
        for line in outFileLines:
            temp_file_lua.write(line + "\n")

    original_language_file_js = "WebUI/languages/DEFAULT.js"
    temp_file_js_path = d / "temp_file.js"

    with temp_file_js_path.open("a") as temp_file_js:
        temp_file_js.write(
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
            temp_file_js.write('	"' + translation + '": "",\n')
        temp_file_js.write("};")

    assert cmp(f"{d}/temp_file.lua", original_language_file_lua)
    assert cmp(f"{d}/temp_file.js", original_language_file_js)
