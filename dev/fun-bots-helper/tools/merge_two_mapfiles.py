from sys import argv

from addons.gets import get_maps_merged, get_to_root
from loguru import logger


def merge_two_mapfiles(merge_file_1: str, merge_file_2: str) -> None:
    get_to_root()
    merged_file = f"mapfiles/merge-{merge_file_1[:-4]}-{merge_file_2[:-4]}.map"

    out_file_lines = get_maps_merged(merge_file_1, merge_file_2)
    with open(merged_file, "w", encoding="utf-8") as out_file:
        for line in out_file_lines:
            out_file.write(line)

    logger.info(f"{merge_file_1} and {merge_file_2} have been merged")


if __name__ == "__main__":
    try:
        merge_file_1 = argv[1]
        merge_file_2 = argv[2]
        merge_two_mapfiles(merge_file_1, merge_file_2)
    except KeyboardInterrupt:
        logger.warning("Crtl+C detected! Exiting Script...")
    except IndexError:
        logger.error("No map files were passed as arguments!")
