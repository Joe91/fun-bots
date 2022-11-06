import os

from addons.gets import get_invalid_node_lines, get_to_root


def scan_for_invalid_nodes() -> None:
    get_to_root()
    source_folder = "mapfiles"

    file_names = os.listdir(source_folder)
    for file_name in file_names:
        out_file_lines = []
        with open(source_folder + "/" + file_name, "r") as in_file:
            out_file_lines = get_invalid_node_lines(in_file)
        with open(source_folder + "/" + file_name, "w") as out_file:
            for line in out_file_lines:
                out_file.write(line)


if __name__ == "__main__":
    scan_for_invalid_nodes()
