import os

from addons.gets import get_comments_fixed, get_to_root


def scanForInvalidComments() -> None:
    get_to_root()
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
        # Shared/Languages/ ignored.
    ]
    for folder in folders:
        filenames = [filename for filename in os.listdir(folder) if ".lua" in filename]
        for filename in filenames:
            if filename in [
                "Config.lua",
                "SettingsDefinition.lua",
            ]:  # Ignore these files.
                continue
            with open(folder + filename, "r", encoding="utf-8") as infile:
                outFileLines = get_comments_fixed(infile)
            with open(folder + filename, "w", encoding="utf-8") as outFile:
                for line in outFileLines:
                    outFile.write(line)


if __name__ == "__main__":
    scanForInvalidComments()
