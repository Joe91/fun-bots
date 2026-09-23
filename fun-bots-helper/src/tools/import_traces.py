import sqlite3

from loguru import logger
from tools.addons.gets import get_it_running
from tools.addons.sets import set_traces_db


def import_traces() -> None:
    # Write into mod.db directly, in one transaction, so tables that aren't
    # traces (settings, permissions, ...) stay untouched and a failed import
    # leaves the database unchanged.
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()
    try:
        cursor.execute("BEGIN")
        set_traces_db(cursor)
    except KeyboardInterrupt:
        connection.rollback()
        logger.warning("Crtl+C detected! Database was restored!")
    except Exception:
        connection.rollback()
        logger.exception("Import failed! Database was restored!")
        raise
    else:
        connection.commit()
    finally:
        connection.close()


if __name__ == "__main__":
    get_it_running(import_traces)
