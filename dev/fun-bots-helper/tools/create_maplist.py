from addons.gets import get_map_lines, get_to_root


def createMaplist() -> None:
    get_to_root()
    outFile = "MapList.txt"

    mapItems = get_map_lines(create=True)
    with open(outFile, "w") as output:
        for item in mapItems:
            output.write(" ".join(item) + "\n")
        print("Write MapList.txt Done")


if __name__ == "__main__":
    createMaplist()
