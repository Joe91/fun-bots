
mergeFile1 = "merge_1.map"
mergeFile2 = "merge_2.map"


mergedFile = "merged.map"


with open(mergeFile1, "r") as baseFile:
    lines = baseFile.readlines()
    lastBasePath = lines[-1].split(";")[0]
    print("last path of Base-File is " + lastBasePath)
    
    with open(mergeFile2, "r") as additionFile:
        linesToAdd = additionFile.readlines()
        pathDict = {}
        currentPath = 0
        lastPath = 0
        # fill path-dictionary
        for line in linesToAdd[1:-1]: # ignore first line
            linePartsAddition = line.split(";")
            currentPath = linePartsAddition[0]
            if currentPath != lastPath:
                pathDict[currentPath] = str(int(lastBasePath) + 1 + len(pathDict))
                lastPath = currentPath
        # replace all paths
        print(pathDict)
        for line in linesToAdd[1:-1]: # ignore first line
            linePartsAddition = line.split(";")
            linePartsAddition[0] = pathDict[linePartsAddition[0]]    
            dataPart = linePartsAddition[-1]
            if "links" in dataPart.lower():
                pos1 = dataPart.find("[[") + 2
                pos2 = dataPart.find("]]") + 0
                linkPart = dataPart[pos1:pos2]
                allLinks = linkPart.split("],[")
                #for link in allLinks:
                #print("Old Links: " + linkPart)    
                newLinkParts = []
                for link in allLinks:
                    partsOfLink = link.split(",")
                    partsOfLink[0] = pathDict[partsOfLink[0]]
                    newLinkParts.append(",".join(partsOfLink))
                newLinks = "],[".join(newLinkParts)
                #print("New Links: " + newLinks)
                linePartsAddition[-1] = dataPart[:pos1] + newLinks + dataPart[pos2:]
            newLine = ";".join(linePartsAddition)
            lines.append(newLine)
    with open(mergedFile, "w") as outFile:
        for line in lines:
            outFile.write(line)

            
