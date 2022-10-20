import sqlite3

from addons.gets import get_to_root


def clearSettings() -> None:
    get_to_root()
    removeList = ["FB_Config_Trace", "FB_Settings"]
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()

    for tablename in removeList:
        print("Remove " + tablename)
        cursor.execute("DROP TABLE IF EXISTS " + tablename)

    connection.commit()
    connection.close()


if __name__ == "__main__":
    clearSettings()
