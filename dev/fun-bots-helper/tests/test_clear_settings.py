"""Execute tools/clear_settings.py over a temporary copy of the mod database and test 
if any of the remaining tables after clear settings is a setting table."""

from loguru import logger


def test_clear_settings(session) -> None:
    """Test clear_settings algorithm.

    Args:
        - session - cursor object from a temporary copy of mod.db

    Returns:
        None
    """
    remove_list = ["FB_Config_Trace", "FB_Settings"]

    for table_name in remove_list:
        logger.info("Remove " + table_name)
        session.execute("DROP TABLE IF EXISTS " + table_name)

    session.execute("vacuum")
    session.execute(
        """
        SELECT name FROM sqlite_master WHERE type='table'
    """
    )

    retrieved_tables = session.fetchall()

    assert all(
        table not in retrieved_tables
        for table in [("FB_Config_Trace",), ("FB_Settings",)]
    )
