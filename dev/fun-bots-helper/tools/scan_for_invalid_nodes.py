import os

from addons.gets import get_invalid_node_lines, get_to_root


def scanForInvalidNodes() -> None:
    get_to_root()
    sourceFolder = "mapfiles"

    filenames = os.listdir(sourceFolder)
    for filename in filenames:
        outFileLines = []
        with open(sourceFolder + "/" + filename, "r") as infile:
            outFileLines = get_invalid_node_lines(infile)
        with open(sourceFolder + "/" + filename, "w") as outfile:
            for line in outFileLines:
                outfile.write(line)


if __name__ == "__main__":
    scanForInvalidNodes()
