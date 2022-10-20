"""Execute tools/clear_all_paths.py over a temporary copy of the mod database and test 
if the remaining tables after clear all paths are the same as those that were ignored."""


def test_clear_all_paths(session):
    """Key arguments.

    session: cursor object from a temporary copy of mod.db
    """
    sql_instruction = """
		SELECT * FROM sqlite_master WHERE type='table'
	"""
    session.execute(sql_instruction)
    content = session.fetchall()
    ignoreList = ["sqlite_sequence", "FB_Permissions", "FB_Config_Trace", "FB_Settings"]

    for item in content:
        if item[1] in ignoreList:
            continue

        print("Clear " + item[1])
        session.execute("DROP TABLE IF EXISTS " + item[1])

    session.connection.commit()

    session.execute(sql_instruction)
    remaining_tables = [item[1] for item in session.fetchall()]

    assert sorted(remaining_tables) == sorted(ignoreList)
