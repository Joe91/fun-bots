import os

from loguru import logger

from addons.gets import (get_to_root, get_updated_lines_js,
                         get_updated_lines_lua)


def update_languages() -> None:
    get_to_root()
    lua_path = "ext/Shared/Languages"
    js_path = "WebUI/languages"

    for file in os.listdir(lua_path):
        if file.endswith(".lua"):
            file_name = os.path.join(lua_path, file)
            if not "DEFAULT" in file_name and not "Languages.lua" in file_name:
                with open(file_name, "r", encoding="utf8") as in_file:
                    out_file_lines = get_updated_lines_lua(in_file)
                    with open(file_name, "w", encoding="utf8") as out_file:
                        for line in out_file_lines:
                            out_file.write(line + "\n")
                logger.info(file_name + " has been updated")

    for file in os.listdir(js_path):
        if file.endswith(".js"):
            file_name = os.path.join(js_path, file)
            if not "DEFAULT" in file_name:
                with open(file_name, "r", encoding="utf8") as in_file:
                    out_file_lines = get_updated_lines_js(in_file)
                    with open(file_name, "w", encoding="utf8") as out_file:
                        for line in out_file_lines:
                            out_file.write(line + "\n")
                logger.info(file_name + " has been updated")


if __name__ == "__main__":
    update_languages()
