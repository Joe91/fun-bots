import sqlite3
import sys

sys.path.insert(1, "../")

from addons.gets import get_to_root
from addons.sets import set_permission_config_db


def importPermissionAndConfig() -> None:
    get_to_root()
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()
    set_permission_config_db(cursor)
    connection.commit()
    connection.close()


if __name__ == "__main__":
    importPermissionAndConfig()
