"""
This module provides functions that accept a cursor object. This cursor will somehow interact with 
the mod database, writing files out of specific sql instructions or inserting values in the 
database itself. All functions return None.
"""

import os
import sqlite3


def set_permission_config_files(cursor: sqlite3.Cursor) -> None:
    exportList = ["FB_Permissions", "FB_Config_Trace", "FB_Settings"]
    destFolder = "permission_and_config"

    if not os.path.exists(destFolder):
        os.makedirs(destFolder)
    for item in exportList:
        print("Export " + item)
        structure = cursor.execute("PRAGMA table_info('" + item + "')").fetchall()
        if len(structure) > 1:
            filename = item + ".cfg"
            with open(destFolder + "/" + filename, "w") as outfile:
                header = [collumn[1] for collumn in structure]
                outfile.write(";".join(header) + "\n")
                sql_instruction = (
                    "SELECT * FROM " + item + " ORDER BY " + structure[-3][1] + " ASC"
                )
                cursor.execute(sql_instruction)
                table_content = cursor.fetchall()
                for line in table_content:
                    outList = [
                        format(item, ".6f") if type(item) is float else str(item)
                        for item in line
                    ]
                    outfile.write(";".join(outList) + "\n")


def set_permission_config_db(cursor: sqlite3.Cursor) -> None:
    allStructures = {
        "FB_Permissions": ["GUID", "PlayerName", "Value", "Time"],
        "FB_Config_Trace": ["Key", "Value", "Time"],
        "FB_Settings": ["Key", "Value", "Time"],
    }
    sourceFolder = "permission_and_config"

    filenames = next(os.walk(sourceFolder), (None, None, []))[2]

    for filename in filenames:
        tablename = filename.split(".")[0]
        print("Import " + tablename)
        cursor.execute("DROP TABLE IF EXISTS " + tablename)

        sql_instruction = "CREATE TABLE IF NOT EXISTS " + tablename + " ("
        for key, value in allStructures.items():
            if key == tablename:
                for item in value:
                    if item == "Time":
                        sql_instruction = sql_instruction + item + " DATETIME,"
                    else:
                        sql_instruction = sql_instruction + item + " TEXT,"
                break
        sql_instruction = sql_instruction[:-1] + ")"

        cursor.execute(sql_instruction)
        with open(sourceFolder + "/" + filename, "r") as infile:
            AllData = [
                line.replace("\n", "").split(";") for line in infile.readlines()[1:]
            ]
            items = allStructures[tablename]
            cursor.executemany(
                "INSERT INTO "
                + tablename
                + " ("
                + ",".join(items)
                + ") VALUES ("
                + (len(items) * "?,")[:-1]
                + ")",
                AllData,
            )


def set_traces_files(cursor: sqlite3.Cursor) -> None:
    content = cursor.fetchall()
    ignoreList = ["sqlite_sequence", "FB_Permissions", "FB_Config_Trace", "FB_Settings"]
    destFolder = "mapfiles"

    if not os.path.exists(destFolder):
        os.makedirs(destFolder)
    for item in content:
        if item[1] in ignoreList:
            continue

        print("Export " + item[1])
        structure = cursor.execute("PRAGMA table_info('" + item[1] + "')").fetchall()

        filename = item[1].replace("_table", "") + ".map"
        with open(destFolder + "/" + filename, "w") as outfile:
            idsToRemove = False
            header = [collumn[1] for collumn in structure]
            if header[0] == "id":
                header.pop(0)
                idsToRemove = True
            outfile.write(";".join(header) + "\n")
            sql_instruction = (
                "SELECT * FROM " + item[1] + " ORDER BY pathIndex, pointIndex ASC"
            )
            cursor.execute(sql_instruction)
            table_content = cursor.fetchall()
            for line in table_content:
                outList = [
                    format(item, ".6f") if type(item) is float else str(item)
                    for item in line
                ]
                if len(outList) > 1 and idsToRemove:
                    outList.pop(0)
                outfile.write(";".join(outList) + "\n")


def set_traces_db(cursor: sqlite3.Cursor) -> None:
    sourceFolder = "mapfiles"
    filenames = next(os.walk(sourceFolder), (None, None, []))[2]

    for filename in filenames:
        tablename = filename.split(".")[0] + "_table"
        print("Import " + tablename)
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
                if len(line) > 1:
                    lineData = line.split(";")
                    dataString = (
                        lineData[6].replace("\n", "") if len(lineData) >= 7 else ""
                    )
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
