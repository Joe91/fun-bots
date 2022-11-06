from addons.gets import get_all_tables, get_to_root


def clear_settings() -> None:
    get_to_root()
    remove_list = ["FB_Config_Trace", "FB_Settings"]
    connection, cursor = get_all_tables()
    content = cursor.fetchall()

    for item in content:
        if item[1] in remove_list:
            print("Remove " + item[1])
            cursor.execute("DROP TABLE " + item[1])

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    clear_settings()
