from addons.gets import get_all_tables, get_it_running, get_to_root
from loguru import logger


def clear_all_paths() -> None:
    get_to_root()
    connection, cursor = get_all_tables()
    content = cursor.fetchall()
    ignore_list = [
        "sqlite_sequence",
        "FB_Permissions",
        "FB_Config_Trace",
        "FB_Settings",
    ]

    for item in content:
        if item[1] in ignore_list:
            continue

        logger.info("Clear " + item[1])
        cursor.execute("DROP TABLE IF EXISTS " + item[1])

    cursor.execute("vacuum")
    connection.commit()
    connection.close()


if __name__ == "__main__":
    get_it_running(clear_all_paths)
