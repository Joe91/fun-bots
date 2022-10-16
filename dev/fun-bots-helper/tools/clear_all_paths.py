import sys

sys.path.insert(1, "../")

from addons.root import go_back_to_root, select_all_tables


def clearAllPaths() -> None:
    go_back_to_root()
    connection, cursor = select_all_tables()
    content = cursor.fetchall()
    ignoreList = ["sqlite_sequence", "FB_Permissions", "FB_Config_Trace", "FB_Settings"]

    for item in content:
        if item[1] in ignoreList:
            continue

        print("Clear " + item[1])
        cursor.execute("DROP TABLE IF EXISTS " + item[1])

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    clearAllPaths()
