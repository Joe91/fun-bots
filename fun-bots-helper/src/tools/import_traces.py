import sqlite3

from loguru import logger
from tools.addons.gets import get_it_running
from tools.addons.sets import set_traces_db


def import_traces() -> None:

    memory_connection = sqlite3.connect(":memory:")
    cursor = memory_connection.cursor()
    connection = sqlite3.connect("mod.db")
    try:
        set_traces_db(cursor)
    except KeyboardInterrupt:
        logger.warning("Crtl+C detected! Database was restored!")
    else:
        memory_connection.commit()
        memory_connection.backup(connection)
    finally:
        memory_connection.close()
        connection.close()


if __name__ == "__main__":
    get_it_running(import_traces)
