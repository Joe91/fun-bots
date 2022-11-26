import os

from loguru import logger

from tools.addons.gets import get_it_running, get_objectives_fixed


def fix_objectives() -> None:

    file_names = os.listdir("mapfiles")
    for file_name in file_names:
        with open("mapfiles/" + file_name, "r", encoding="utf-8") as in_file:
            objectives_to_rename, file_lines = get_objectives_fixed(in_file)
            if len(objectives_to_rename) > 0:
                with open("mapfiles/" + file_name, "w", encoding="utf-8") as out_file:
                    logger.info(f"Objective Fixed in: {file_name}")
                    for line in file_lines:
                        for rename_item in objectives_to_rename:
                            line = line.replace(rename_item, rename_item.lower())
                        out_file.write(line)


if __name__ == "__main__":
    get_it_running(fix_objectives)
