import sqlite3
import sys


def clearAllPaths(pathToFiles: str) -> None:
    ignoreList = ["sqlite_sequence", "FB_Permissions", "FB_Config_Trace", "FB_Settings"]

    connection = sqlite3.connect(pathToFiles + "mod.db")
    cursor = connection.cursor()

    sql_instruction = """
		SELECT * FROM sqlite_master WHERE type='table'
	"""
    cursor.execute(sql_instruction)
    content = cursor.fetchall()

    for item in content:
        skip = False
        for ignoreItem in ignoreList:
            if item[1] == ignoreItem:
                skip = True
                break
        if skip:
            continue

        print("clear " + item[1])
        cursor.execute("DROP TABLE IF EXISTS " + item[1])

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    pathToFiles = "./"
    if len(sys.argv) > 1:
        pathToFiles = sys.argv[1]
    clearAllPaths(pathToFiles)
