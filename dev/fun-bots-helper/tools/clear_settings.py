import sqlite3
from go_back_to_root import go_back_to_root


def clearSettings() -> None:
    removeList = ["FB_Config_Trace", "FB_Settings"]  # "FB_Permissions"

    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()

    for tablename in removeList:
        print("remove " + tablename)
        cursor.execute("DROP TABLE IF EXISTS " + tablename)

    connection.commit()
    connection.close()


if __name__ == "__main__":
    go_back_to_root()
    clearSettings()
