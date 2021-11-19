import sqlite3
import os
import os


# use "auto-py-to-exe" to convert to exe files
exportList = ["FB_Permissions", "FB_Config_Trace", "FB_Settings"]

destFolder = ""
connection = None
if os.path.isfile("mod.db"):
    destFolder = "permission_and_config"
    connection = sqlite3.connect("mod.db")
else:
    destFolder = "./../permission_and_config"
    connection = sqlite3.connect("./../mod.db")
cursor = connection.cursor()

sql_instruction = """
    SELECT * FROM sqlite_master WHERE type='table'
"""
cursor.execute(sql_instruction)

if not os.path.exists(destFolder):
    os.makedirs(destFolder)
for item in exportList:
    print("export " + item)
    structure = cursor.execute("PRAGMA table_info('"+ item + "')").fetchall()
    if len(structure) > 1:
        filename = item + ".cfg"
        with open(destFolder + "/" + filename, "w") as outfile:
            header = []
            for collum in structure:
                header.append(collum[1])
            outfile.write(";".join(header) + "\n")
            sql_anweistung = "SELECT * FROM " + item + " ORDER BY "+structure[-3][1]+" ASC"
            cursor.execute(sql_anweistung)
            table_content = cursor.fetchall()
            for line in table_content:
                outList = []
                for item in line:
                    if type(item) is float:
                        outList.append(format(item, '.6f'))
                    else:
                        outList.append(str(item))
                outfile.write(";".join(outList) + "\n")
connection.close()