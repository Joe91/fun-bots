import sqlite3
import sys

sys.path.insert(1, "../")

from addons.root import go_back_to_root


def clearSettings() -> None:
    go_back_to_root()
    removeList = ["FB_Config_Trace", "FB_Settings"]  # "FB_Permissions"
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()

    for tablename in removeList:
        print("Remove " + tablename)
        cursor.execute("DROP TABLE IF EXISTS " + tablename)

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    clearSettings()
