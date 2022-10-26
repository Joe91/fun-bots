from addons.gets import get_to_root, get_all_tables


def clearSettings() -> None:
    get_to_root()
    removeList = ["FB_Config_Trace", "FB_Settings"]
    connection, cursor = get_all_tables()
    content = cursor.fetchall()

    for item in content:
        if item[1] in removeList:
            print("Remove " + item[1])
            cursor.execute("DROP TABLE " + item[1])

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    clearSettings()
