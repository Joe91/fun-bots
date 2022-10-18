import sys
from os import walk

sys.path.insert(1, "../")

from addons.gets import get_objectives_to_rename, get_to_root


def scanForInvalidObjectives() -> None:
    get_to_root()
    sourceFolder = "mapfiles"

    filenames = next(walk(sourceFolder), (None, None, []))[2]

    for filename in filenames:
        with open(sourceFolder + "/" + filename, "r") as infile:
            objectivesToRename, fileLines = get_objectives_to_rename(infile)
        if len(objectivesToRename) > 0:
            with open(sourceFolder + "/" + filename, "w") as outfile:
                print(filename)
                print("Replace Content")
                for line in fileLines:
                    for renameItem in objectivesToRename:
                        line = line.replace(renameItem, renameItem.lower())
                    outfile.write(line)


if __name__ == "__main__":
    scanForInvalidObjectives()
