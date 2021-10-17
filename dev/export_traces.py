import sqlite3
import os

ignoreList = ["sqlite_sequence","FB_Permissions", "FB_Config_Trace", "FB_Settings"]

connection = sqlite3.connect("./../mod.db")
cursor = connection.cursor()
sql_instruction = """
    SELECT * FROM sqlite_master WHERE type='table'
"""
cursor.execute(sql_instruction)
content = cursor.fetchall()

if not os.path.exists('./../maplist'):
    os.makedirs('./../maplist')
for item in content:
    skip = False
    for ignoreItem in ignoreList:
        if item[1] == ignoreItem:
            skip = True
            break
    if skip:
        continue
        
    print("export " + item[1])
    structure = cursor.execute("PRAGMA table_info('"+ item[1] + "')").fetchall()

    filename = item[1].replace("_table","")+".map"
    with open("./../maplist/" + filename, "w") as outfile:
        header = []
        idsToRemove = False
        for collum in structure:
            header.append(collum[1])
        if header[0] == "id":
            header.pop(0)
            idsToRemove = True
        outfile.write(";".join(header) + "\n")
        sql_anweistung = "SELECT * FROM " + item[1] + " ORDER BY 'pathIndex', 'pointIndex' ASC"
        cursor.execute(sql_anweistung)
        table_content = cursor.fetchall()
        for line in table_content:
            outList = []
            for item in line:
                outList.append(str(item))
            if len(outList) > 1 and idsToRemove:
                outList.pop(0)
            outfile.write(";".join(outList) + "\n")
connection.close()