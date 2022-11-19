import os
import sys

from loguru import logger

from tools.addons.gets import get_it_running, get_maps_merged


def merge_two_mapfiles(merge_file_1: str, merge_file_2: str) -> None:

    for file in [merge_file_1, merge_file_2]:
        if not os.path.exists(f"mapfiles/{file}"):
            logger.warning(f"{file} does not exist!")
            return

    merged_file = f"mapfiles/merge_{merge_file_1[:-4]}_{merge_file_2[:-4]}.map"

    out_file_lines = get_maps_merged(merge_file_1, merge_file_2)
    with open(merged_file, "w", encoding="utf-8") as out_file:
        for line in out_file_lines:
            out_file.write(line)

    logger.info(f"{merge_file_1} and {merge_file_2} have been merged")


if __name__ == "__main__":
    try:
        get_it_running(merge_two_mapfiles, sys.argv[1], sys.argv[2])
    except IndexError:
        logger.error("One or both map files were not passed as arguments!")
