import os

from tools.addons.gets import get_comments_fixed, get_it_running


def fix_comments() -> None:

    folders = [
        "ext/Client/",
        "ext/Server/",
        "ext/Server/Bot/",
        "ext/Server/Commands/",
        "ext/Server/Constants/",
        "ext/Server/Debug/",
        "ext/Server/Model/",
        "ext/Shared/",
        "ext/Shared/Constants/",
        "ext/Shared/Registry/",
        "ext/Shared/Settings/",
        "ext/Shared/Utils/",
        "ext/Shared/WeaponLists/",
    ]
    for folder in folders:
        file_names = [
            file_name for file_name in os.listdir(folder) if ".lua" in file_name
        ]
        for file_name in file_names:
            if file_name in ["SettingsDefinition.lua", "Config.lua"]:
                continue
            with open(folder + file_name, "r", encoding="utf-8") as in_file:
                out_file_lines = get_comments_fixed(in_file)
            with open(folder + file_name, "w", encoding="utf-8") as out_file:
                for line in out_file_lines:
                    out_file.write(line)


if __name__ == "__main__":
    get_it_running(fix_comments)
