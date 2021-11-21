import os
from os import walk
import sys

pathToFiles = "./"
if len(sys.argv) > 1:
	pathToFiles = sys.argv[1]

# use "auto-py-to-exe" to convert to exe files

sourceFolder = pathToFiles + "mapfiles"

filenames = next(walk(sourceFolder), (None, None, []))[2]  # [] if no file

for filename in filenames:
	fileLines = []
	with open(sourceFolder + "/" + filename, "r") as infile:
		nodesToModify = []
		fileLines = infile.readlines()
		lastPath = 0
		currentPath = 0
		for i in range(2, len(fileLines)-2): # in fileLines[1:]:
			line = fileLines[i]
			currentitems = line.split(";")
			currentPath = int(currentitems[0])
			currentNode = int(currentitems[1])
			posX = float(currentitems[2])
			posY = float(currentitems[3])
			posZ = float(currentitems[4])

			line = fileLines[i-1]
			items = line.split(";")
			lastPath = int(items[0])
			lastNode = int(items[1])
			lastPosX = float(items[2])
			lastPosY = float(items[3])
			lastPosZ = float(items[4])

			line = fileLines[i+1]
			items = line.split(";")
			nextPath = int(items[0])
			nextNode = int(items[1])
			nextPosX = float(items[2])
			nextPosY = float(items[3])
			nextPosZ = float(items[4])

			if lastPath == currentPath and nextPath == currentPath: # TODO scan for end and start as well
				if (abs(lastPosX - posX)	> 100 or abs(lastPosY - posY) > 100 or abs(lastPosZ - posZ) > 100) and (abs(nextPosX - posX)	> 100 or abs(nextPosY - posY) > 100 or abs(nextPosZ - posZ) > 100):
					print(filename)
					print(items)
					newPosX = lastPosX + (nextPosX - lastPosX)/2
					newPosY = lastPosY + (nextPosY - lastPosY)/2
					newPosZ = lastPosZ + (nextPosZ - lastPosZ)/2
					currentitems[2] = format(newPosX, '.6f')
					currentitems[3] = format(newPosY, '.6f')
					currentitems[4] = format(newPosZ, '.6f')
					newLineContent = ";".join(currentitems)
					print(newLineContent)
					fileLines[i] = newLineContent
					
	# if len(nodesToModify) > 0:
	with open(sourceFolder + "/" + filename, "w") as outfile:
		for line in fileLines:
			outfile.write(line)