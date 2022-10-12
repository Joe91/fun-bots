import sys
from os import walk

DISTANCE_MAX = 80
# use "auto-py-to-exe" to convert to exe files
def scanForInvalidNodes(pathToFiles):
    sourceFolder = pathToFiles + "mapfiles"

    filenames = next(walk(sourceFolder), (None, None, []))[2]  # [] if no file

    for filename in filenames:
        fileLines = []
        with open(sourceFolder + "/" + filename, "r") as infile:
            fileLines = infile.readlines()
            lastPath = 0
            currentPath = 0
            for i in range(2, len(fileLines) - 2):  # in fileLines[1:]:
                line = fileLines[i]
                currentitems = line.split(";")
                currentPath = int(currentitems[0])
                posX = float(currentitems[2])
                posY = float(currentitems[3])
                posZ = float(currentitems[4])

                line = fileLines[i - 1]
                items = line.split(";")
                lastPath = int(items[0])
                lastPosX = float(items[2])
                lastPosY = float(items[3])
                lastPosZ = float(items[4])

                line = fileLines[i + 1]
                items = line.split(";")
                nextPath = int(items[0])
                nextPosX = float(items[2])
                nextPosY = float(items[3])
                nextPosZ = float(items[4])

                if (
                    lastPath == currentPath and nextPath == currentPath
                ):  # Wrong in the middle
                    if (
                        abs(lastPosX - posX) > DISTANCE_MAX
                        or abs(lastPosY - posY) > DISTANCE_MAX
                        or abs(lastPosZ - posZ) > DISTANCE_MAX
                    ) and (
                        abs(nextPosX - posX) > DISTANCE_MAX
                        or abs(nextPosY - posY) > DISTANCE_MAX
                        or abs(nextPosZ - posZ) > DISTANCE_MAX
                    ):
                        print(filename)
                        print(items)
                        newPosX = lastPosX + (nextPosX - lastPosX) / 2
                        newPosY = lastPosY + (nextPosY - lastPosY) / 2
                        newPosZ = lastPosZ + (nextPosZ - lastPosZ) / 2
                        currentitems[2] = format(newPosX, ".6f")
                        currentitems[3] = format(newPosY, ".6f")
                        currentitems[4] = format(newPosZ, ".6f")
                        newLineContent = ";".join(currentitems)
                        print(newLineContent)
                        fileLines[i] = newLineContent
                if (
                    lastPath == currentPath and nextPath != currentPath
                ):  # Wrong at the end
                    if (
                        abs(lastPosX - posX) > DISTANCE_MAX
                        or abs(lastPosY - posY) > DISTANCE_MAX
                        or abs(lastPosZ - posZ) > DISTANCE_MAX
                    ):
                        currentitems[2] = format(lastPosX + 0.2, ".6f")
                        currentitems[3] = format(lastPosY, ".6f")
                        currentitems[4] = format(lastPosY + 0.2, ".6f")
                        newLineContent = ";".join(currentitems)
                        print(newLineContent)
                        fileLines[i] = newLineContent
                if (
                    lastPath != currentPath and nextPath == currentPath
                ):  # Wrong at the start
                    if (
                        abs(nextPosX - posX) > DISTANCE_MAX
                        or abs(nextPosY - posY) > DISTANCE_MAX
                        or abs(nextPosZ - posZ) > DISTANCE_MAX
                    ):
                        currentitems[2] = format(nextPosX + 0.2, ".6f")
                        currentitems[3] = format(nextPosY, ".6f")
                        currentitems[4] = format(nextPosZ + 0.2, ".6f")
                        newLineContent = ";".join(currentitems)
                        print(newLineContent)
                        fileLines[i] = newLineContent

        # if len(nodesToModify) > 0:
        with open(sourceFolder + "/" + filename, "w") as outfile:
            for line in fileLines:
                outfile.write(line)


if __name__ == "__main__":
    pathToFiles = "./"
    if len(sys.argv) > 1:
        pathToFiles = sys.argv[1]
    scanForInvalidNodes(pathToFiles)
