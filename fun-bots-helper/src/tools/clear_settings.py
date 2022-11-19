from loguru import logger

from tools.addons.gets import get_all_tables, get_it_running


def clear_settings() -> None:

    remove_list = ["FB_Config_Trace", "FB_Settings"]
    connection, cursor = get_all_tables()
    content = cursor.fetchall()

    for item in content:
        if item[1] in remove_list:
            logger.info("Remove " + item[1])
            cursor.execute("DROP TABLE " + item[1])

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    get_it_running(clear_settings)
