import sqlite3
import os
from os import walk
import sys

pathToFiles = "./"
if len(sys.argv) > 1:
	pathToFiles = sys.argv[1]

# use "auto-py-to-exe" to convert to exe files
allStructures = {
    "FB_Permissions": ["GUID","PlayerName","Value","Time"], 
    "FB_Config_Trace": ["Key","Value","Time"], 
    "FB_Settings": ["Key","Value","Time"], 
}

sourceFolder = pathToFiles + "permission_and_config"
connection = sqlite3.connect(pathToFiles + "mod.db")
cursor = connection.cursor()

filenames = next(walk(sourceFolder), (None, None, []))[2]  # [] if no file

for filename in filenames:
    tablename = filename.split(".")[0]
    print("import " + tablename)
    cursor.execute('DROP TABLE IF EXISTS '+ tablename)
    structure = allStructures[tablename]
    
    sql_instruction = "CREATE TABLE IF NOT EXISTS "+ tablename +" ("
    for key, value in allStructures.items():
        if key == tablename:
            for item in value:
                if item == "Time":
                    sql_instruction = sql_instruction + item + " DATETIME,"
                else:
                    sql_instruction = sql_instruction + item + " TEXT,"
            break
    sql_instruction = sql_instruction[:-1]
    sql_instruction = sql_instruction + ")"
    
    cursor.execute(sql_instruction)
    with open(sourceFolder + "/" + filename, "r") as infile:
        AllData = []
        for line in infile.readlines()[1:]:
            line = line.replace("\n","")
            lineData = line.split(";")
            AllData.append(lineData)
        items = allStructures[tablename]
        cursor.executemany("INSERT INTO " + tablename + " (" + ",".join(items) + ") VALUES (" + (len(items)*"?,")[:-1] + ")", AllData)
        
connection.commit()
connection.close()
