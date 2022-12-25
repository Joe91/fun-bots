import os

from tools.addons.gets import get_it_running, get_nodes_fixed


def fix_nodes() -> None:

    file_names = os.listdir("mapfiles")
    for file_name in file_names:
        with open("mapfiles/" + file_name, "r", encoding="utf-8") as in_file:
            out_file_lines = get_nodes_fixed(in_file)
        with open("mapfiles/" + file_name, "w", encoding="utf-8") as out_file:
            for line in out_file_lines:
                out_file.write(line)


if __name__ == "__main__":
    get_it_running(fix_nodes)
