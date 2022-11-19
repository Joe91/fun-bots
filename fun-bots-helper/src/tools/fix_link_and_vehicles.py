import os

from tools.addons.gets import get_it_running


def fix_link_and_nodes() -> None:

    file_names = os.listdir("mapfiles")
    for file_name in file_names:
        file_path = "mapfiles/" + file_name
        with open(file_path, "r", encoding="utf-8") as infile:
            paths_objectives_us = []
            paths_objectives_ru = []
            vehicles = {}
            vehicle_paths = []
            replace_dict = {}
            replace_paths = []
            read_data = infile.read().splitlines()
            for line in read_data[1:]:
                if '"Objectives":[' in line:
                    objectives = (
                        line.split('"Objectives":[')[1].split("]")[0].split(",")
                    )
                    pathindex = int(line.split(";")[0])
                    if len(objectives) == 1 and "base" in objectives[0]:
                        if "us" in objectives[0]:
                            paths_objectives_us.append(pathindex)
                        elif "ru" in objectives[0]:
                            paths_objectives_ru.append(pathindex)
                    if len(objectives) == 1 and "vehicle" in objectives[0]:
                        vehicles[pathindex] = objectives[0]
                        vehicle_paths.append(pathindex)

            # now find connections form base-paths
            for line in read_data[1:]:
                pathindex = int(line.split(";")[0])
                if pathindex in paths_objectives_us:
                    if "Links" in line and 'Links":{}' not in line:
                        if "[[" not in line or "]]" not in line:
                            print(str(pathindex) + " " + file_path)
                        links = line.split("[[")[1].split("]]")[0].split("],[")
                        for link in links:
                            linkedPath = int(link.split(",")[0])
                            if linkedPath in vehicle_paths:
                                if (
                                    "us" not in vehicles[linkedPath]
                                    or "ru" in vehicles[linkedPath]
                                ):
                                    vehicle_string = vehicles[linkedPath]
                                    replace_dict[vehicle_string] = (
                                        vehicle_string.replace("ru", "")[:-1]
                                        + " us"
                                        + '"'
                                    )
                                    replace_paths.append(linkedPath)
                elif pathindex in paths_objectives_ru:
                    if "Links" in line and 'Links":{}' not in line:
                        links = line.split("[[")[1].split("]]")[0].split("],[")
                        for link in links:
                            linkedPath = int(link.split(",")[0])
                            if linkedPath in vehicle_paths:
                                if (
                                    "ru" not in vehicles[linkedPath]
                                    or "us" in vehicles[linkedPath]
                                ):
                                    vehicle_string = vehicles[linkedPath]
                                    replace_dict[vehicle_string] = (
                                        vehicle_string.replace("us", "")[:-1]
                                        + " ru"
                                        + '"'
                                    )
                                    replace_paths.append(linkedPath)

            print(replace_paths)
            with open(file_path, "w", encoding="utf-8") as outFile:
                outFile.write(read_data[0] + "\n")
                for line in read_data[1:]:
                    pathIndex = int(line.split(";")[0])
                    if pathIndex in replace_paths and '"Objectives":[' in line:
                        for key, value in replace_dict.items():
                            line = line.replace(key, value)
                    if 'Links":{}' in line:
                        for link in [
                            ',"Links":{}',
                            '"Links":{},',
                            '"Links":{}',
                            ',"Links":{}',
                            '"LinkMode":0,',
                            ',"LinkMode":0',
                            '"LinkMode":0',
                            "{}",
                        ]:
                            line = line.replace(link, "")
                    if '"Objectives":{}' in line:
                        for objective in [
                            ',"Objectives":{}',
                            '"Objectives":{},',
                            '"Objectives":{}',
                        ]:
                            line = line.replace(objective, "")
                    if "{}" in line:
                        line = line.replace("{}", "")
                    outFile.write(line + "\n")


if __name__ == "__main__":
    get_it_running(fix_link_and_nodes)
