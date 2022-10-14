import sqlite3
import sys

sys.path.insert(1, "../")

from addons.go_back_to_root import go_back_to_root


def clearAllPaths() -> None:

    ignoreList = ["sqlite_sequence", "FB_Permissions", "FB_Config_Trace", "FB_Settings"]

    go_back_to_root()

    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()

    sql_instruction = """
		SELECT * FROM sqlite_master WHERE type='table'
	"""
    cursor.execute(sql_instruction)
    content = cursor.fetchall()

    for item in content:
        if item[1] in ignoreList:
            continue

        print("clear " + item[1])
        cursor.execute("DROP TABLE IF EXISTS " + item[1])

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    clearAllPaths()
