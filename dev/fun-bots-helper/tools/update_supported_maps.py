from addons.gets import get_map_lines, get_to_root


def update_supported_maps() -> None:
    get_to_root()
    template_path = "dev/templates/Supported-maps.md"
    out_file = "Supported-maps.md"

    map_items = get_map_lines(update_supported=True)
    with open(out_file, "w") as output:
        with open(template_path, "r") as template:
            for line in template.readlines():
                all_supported_game_modes = []
                vehicle_supported_game_modes = []
                if "!ALL-GAMEMODES!" in line:
                    line_parts = line.split("|")
                    if len(line_parts) >= 5:
                        mapname = line_parts[2].split("`")[1]
                        for item in map_items:
                            if item[0] == mapname:
                                all_supported_game_modes.append("`" + item[1] + "`")
                                if item[3]:
                                    vehicle_supported_game_modes.append(
                                        "`" + item[1] + "`"
                                    )
                    line = line.replace(
                        "!ALL-GAMEMODES!", " ,".join(all_supported_game_modes)
                    )
                    line = line.replace(
                        "!VEHICLE-GAMEMODES!", " ,".join(vehicle_supported_game_modes)
                    )
                output.write(line)
        print("Update Supported-maps.md Done")


if __name__ == "__main__":
    update_supported_maps()
