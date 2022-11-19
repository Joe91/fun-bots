import sqlite3

from tools.addons.gets import get_it_running
from tools.addons.sets import set_traces_db


def import_traces() -> None:

    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()
    set_traces_db(cursor)
    connection.commit()
    connection.close()


if __name__ == "__main__":
    get_it_running(import_traces)
