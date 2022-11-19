import sys

from loguru import logger

from tools.addons.gets import get_maps_merged


def merge_two_mapfiles(merge_file_1: str, merge_file_2: str) -> None:

    merged_file = f"mapfiles/merge_{merge_file_1[:-4]}_{merge_file_2[:-4]}.map"

    out_file_lines = get_maps_merged(merge_file_1, merge_file_2)
    if merge_file_1 and merge_file_2 not in [""]:
        with open(merged_file, "w", encoding="utf-8") as out_file:
            for line in out_file_lines:
                out_file.write(line)

        logger.info(f"{merge_file_1} and {merge_file_2} have been merged")


if __name__ == "__main__":
    try:
        merge_file_1 = sys.argv[1]
        merge_file_2 = sys.argv[2]
        merge_two_mapfiles(merge_file_1, merge_file_2)
    except KeyboardInterrupt:
        logger.warning("Crtl+C detected! Exiting Script...")
    except IndexError:
        logger.error("No map files were passed as arguments!")
