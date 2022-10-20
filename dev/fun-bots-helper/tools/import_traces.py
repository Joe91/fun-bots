import sqlite3

from addons.gets import get_to_root
from addons.sets import set_traces_db


def importTraces() -> None:
    get_to_root()
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()
    set_traces_db(cursor)
    connection.commit()
    connection.close()


if __name__ == "__main__":
    importTraces()
