from loguru import logger

from tools.addons.gets import get_it_running, get_map_lines_created


def create_map_list() -> None:

    out_file = "MapList.txt"

    map_items = get_map_lines_created()
    with open(out_file, "w", encoding="utf-8") as output:
        for item in map_items:
            output.write(" ".join(item) + "\n")
        logger.info("MapList.txt has been built")


if __name__ == "__main__":
    get_it_running(create_map_list)
