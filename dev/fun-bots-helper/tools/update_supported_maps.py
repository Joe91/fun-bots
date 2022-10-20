from addons.gets import get_map_lines, get_to_root


def updateSupportedMaps() -> None:
    get_to_root()
    Template = "dev/templates/Supported-maps.md"
    OutFile = "Supported-maps.md"

    mapItems = get_map_lines(update_supported=True)
    with open(OutFile, "w") as output:
        with open(Template, "r") as template:
            for line in template.readlines():
                allSupportedGameModes = []
                vehicleSupportedGameModes = []
                if "!ALL-GAMEMODES!" in line:
                    lineParts = line.split("|")
                    if len(lineParts) >= 5:
                        mapname = lineParts[2].split("`")[1]
                        for item in mapItems:
                            if item[0] == mapname:
                                allSupportedGameModes.append("`" + item[1] + "`")
                                if item[3]:
                                    vehicleSupportedGameModes.append(
                                        "`" + item[1] + "`"
                                    )
                    line = line.replace(
                        "!ALL-GAMEMODES!", " ,".join(allSupportedGameModes)
                    )
                    line = line.replace(
                        "!VEHICLE-GAMEMODES!", " ,".join(vehicleSupportedGameModes)
                    )
                output.write(line)
        print("Update Supported-maps.md Done")


if __name__ == "__main__":
    updateSupportedMaps()
