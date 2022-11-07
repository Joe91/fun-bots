"""Execute tools/clear_all_paths.py over a temporary copy of the mod database and test 
if the remaining tables after clear all paths are the same as those that were ignored."""

from loguru import logger


def test_clear_all_paths(session) -> None:
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
        session.execute("DROP TABLE IF EXISTS " + item[1])

    session.execute("vacuum")
    session.connection.commit()

    session.execute(sql_instruction)
    remaining_tables = [item[1] for item in session.fetchall()]
    ignore_list.remove("sqlite_sequence")

    assert sorted(remaining_tables) == sorted(ignore_list)
