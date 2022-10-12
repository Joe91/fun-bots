import sys
from os import walk


# use "auto-py-to-exe" to convert to exe files
def scanForInvalidObjectives(pathToFiles: str) -> None:
    sourceFolder = pathToFiles + "mapfiles"

    filenames = next(walk(sourceFolder), (None, None, []))[2]  # [] if no file

    for filename in filenames:
        with open(sourceFolder + "/" + filename, "r") as infile:
            allObjectives = []
            objectivesToRename = []
            fileLines = infile.readlines()
            for line in fileLines[1:]:
                if '"Objectives":[' in line:
                    objectives = line.split('"Objectives":[')[1]
                    objectives = objectives.split("]")[0]
                    objectives = objectives.split(",")
                    for objective in objectives:
                        if objective not in allObjectives:
                            allObjectives.append(objective)
            allObjectives.sort()
            for objectiveName in allObjectives:
                if objectiveName.lower() != objectiveName:
                    objectivesToRename.append(objectiveName)
        if len(objectivesToRename) > 0:
            with open(sourceFolder + "/" + filename, "w") as outfile:
                print(filename)
                print("replace content")
                for line in fileLines:
                    for renameItem in objectivesToRename:
                        line = line.replace(renameItem, renameItem.lower())
                    outfile.write(line)


if __name__ == "__main__":
    pathToFiles = "./"
    if len(sys.argv) > 1:
        pathToFiles = sys.argv[1]
    scanForInvalidObjectives(pathToFiles)
