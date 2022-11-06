import sqlite3

from addons.gets import get_to_root
from addons.sets import set_permission_config_db


def import_permission_and_config() -> None:
    get_to_root()
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()
    set_permission_config_db(cursor)
    connection.commit()
    connection.close()


if __name__ == "__main__":
    import_permission_and_config()
