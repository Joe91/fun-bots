import sqlite3
import sys


def clearSettings(pathToFiles):
    removeList = ["FB_Config_Trace", "FB_Settings"]  # "FB_Permissions"

    connection = sqlite3.connect(pathToFiles + "mod.db")
    cursor = connection.cursor()

    for removeTable in removeList:
        tablename = removeTable
        print("remove " + tablename)
        cursor.execute("DROP TABLE IF EXISTS " + tablename)

    connection.commit()
    connection.close()


if __name__ == "__main__":
    pathToFiles = "./"
    if len(sys.argv) > 1:
        pathToFiles = sys.argv[1]
    clearSettings(pathToFiles)
