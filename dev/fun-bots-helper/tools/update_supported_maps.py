import sys

sys.path.insert(1, "../")
from addons.root import go_back_to_root
from addons.retrieves import retrieve_lines_maps


# Updating Supported-maps.md
def updateSupportedMaps() -> None:
    go_back_to_root()
    Template = "dev/templates/Supported-maps.md"
    OutFile = "Supported-maps.md"

    # Lines
    mapItems = retrieve_lines_maps(update_supported=True)
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
