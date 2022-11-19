import os

from tools.addons.gets import get_invalid_node_lines, get_it_running


def fix_nodes() -> None:

    source_folder = "mapfiles"

    file_names = os.listdir(source_folder)
    for file_name in file_names:
        with open(source_folder + "/" + file_name, "r", encoding="utf-8") as in_file:
            out_file_lines = get_invalid_node_lines(in_file)
        with open(source_folder + "/" + file_name, "w", encoding="utf-8") as out_file:
            for line in out_file_lines:
                out_file.write(line)


if __name__ == "__main__":
    get_it_running(fix_nodes)
