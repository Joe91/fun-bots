"""Execute tools/clear_settings.py over a temporary copy of the mod database and test 
if any of the remaining tables after clear settings is a setting table."""


def test_clear_settings(session) -> None:
    """Test clearSettings algorithm.

    Args:
        - session - cursor object from a temporary copy of mod.db

    Returns:
        None
    """
    removeList = ["FB_Config_Trace", "FB_Settings"]

    for tablename in removeList:
        print("Remove " + tablename)
        session.execute("DROP TABLE IF EXISTS " + tablename)

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
