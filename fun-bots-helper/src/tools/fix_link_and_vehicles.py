import os

from tools.addons.gets import get_it_running, get_links_and_vehicles_fixed


def fix_link_and_vehicles() -> None:

    file_names = os.listdir("mapfiles")
    for file_name in file_names:
        file_path = "mapfiles/" + file_name
        with open(file_path, "r", encoding="utf-8") as in_file:
            out_file_lines = get_links_and_vehicles_fixed(in_file)
        with open(file_path, "w", encoding="utf-8") as out_file:
            for line in out_file_lines:
                out_file.write(line)


if __name__ == "__main__":
    get_it_running(fix_link_and_vehicles)
