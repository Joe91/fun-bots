import os

from loguru import logger

from addons.gets import get_objectives_to_rename, get_to_root


def scan_for_invalid_objectives() -> None:
    get_to_root()
    source_folder = "mapfiles"

    file_names = os.listdir(source_folder)

    for file_name in file_names:
        with open(source_folder + "/" + file_name, "r") as in_file:
            objectives_to_rename, file_lines = get_objectives_to_rename(in_file)
        if len(objectives_to_rename) > 0:
            with open(source_folder + "/" + file_name, "w") as out_file:
                logger.info("Objective Fixed in: ", file_name)
                for line in file_lines:
                    for rename_item in objectives_to_rename:
                        line = line.replace(rename_item, rename_item.lower())
                    out_file.write(line)


if __name__ == "__main__":
    scan_for_invalid_objectives()
