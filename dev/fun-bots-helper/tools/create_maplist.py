from loguru import logger

from addons.gets import get_map_lines, get_to_root


def create_map_list() -> None:
    get_to_root()
    out_file = "MapList.txt"

    map_items = get_map_lines(create=True)
    with open(out_file, "w") as output:
        for item in map_items:
            output.write(" ".join(item) + "\n")
        logger.info("MapList.txt has been built")


if __name__ == "__main__":
    create_map_list()
