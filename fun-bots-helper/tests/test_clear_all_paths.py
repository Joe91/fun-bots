"""Execute tools/clear_all_paths.py over a temporary copy of the mod database and test 
if the remaining tables after clear all paths are the same as those that were ignored."""

import sqlite3

from loguru import logger


def test_clear_all_paths(session: sqlite3.Cursor) -> None:
    """Test clear_all_paths algorithm.

    Args:
        - session - cursor object from a temporary copy of mod.db

    Returns:
        None
    """
    sql_instruction = """
		SELECT * FROM sqlite_master WHERE type='table'
	"""
    session.execute(sql_instruction)
    content = session.fetchall()
    ignored_tables = [
        "sqlite_sequence",
        "FB_Permissions",
        "FB_Config_Trace",
        "FB_Settings",
    ]

    ignored_tables_copy = ignored_tables.copy()

    for ignored_table in ignored_tables_copy:
        next = False
        for item in content:
            if item[1] == ignored_table:
                next = True
                break
        if next:
            continue
        ignored_tables.remove(ignored_table)

    for item in content:
        if item[1] in ignored_tables:
            continue

        logger.info("Clear " + item[1])
        session.execute("DROP TABLE IF EXISTS " + item[1])

    session.execute("vacuum")
    session.connection.commit()

    session.execute(sql_instruction)
    remaining_tables = [item[1] for item in session.fetchall()]
    ignored_tables.remove("sqlite_sequence")

    assert sorted(remaining_tables) == sorted(ignored_tables)
