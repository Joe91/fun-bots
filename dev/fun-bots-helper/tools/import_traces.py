import sqlite3
import sys
from os import walk


def importTraces(pathToFiles):
    sourceFolder = pathToFiles + "mapfiles"
    connection = sqlite3.connect(pathToFiles + "mod.db")
    cursor = connection.cursor()

    filenames = next(walk(sourceFolder), (None, None, []))[2]  # [] if no file

    for filename in filenames:
        tablename = filename.split(".")[0] + "_table"
        print("import " + tablename)
        cursor.execute("DROP TABLE IF EXISTS " + tablename)
        sql_instruction = (
            """
			CREATE TABLE IF NOT EXISTS """
            + tablename
            + """ (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			pathIndex INTEGER,
			pointIndex INTEGER,
			transX FLOAT,
			transY FLOAT,
			transZ FLOAT,
			inputVar INTEGER,
			data TEXT
			)
		"""
        )
        cursor.execute(sql_instruction)
        with open(sourceFolder + "/" + filename, "r") as infile:
            allNodeData = []
            for line in infile.readlines()[1:]:
                if len(line) > 1:  # skip newlines
                    lineData = line.split(";")
                    dataString = ""
                    if len(lineData) >= 7:
                        dataString = lineData[6]
                        dataString = dataString.replace("\n", "")
                    node = (
                        int(lineData[0]),
                        int(lineData[1]),
                        float(lineData[2]),
                        float(lineData[3]),
                        float(lineData[4]),
                        int(lineData[5]),
                        dataString,
                    )
                    allNodeData.append(node)
            cursor.executemany(
                "INSERT INTO "
                + tablename
                + " (pathIndex, pointIndex, transX, transY, transZ, inputVar, data) VALUES (?,?,?,?,?,?,?)",
                allNodeData,
            )

    connection.commit()
    connection.close()


if __name__ == "__main__":
    pathToFiles = "./"
    if len(sys.argv) > 1:
        pathToFiles = sys.argv[1]
    importTraces(pathToFiles)
