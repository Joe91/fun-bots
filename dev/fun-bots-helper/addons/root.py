import os
import sqlite3


def go_back_to_root() -> None:
    cwd_splitted = os.getcwd().split("/")
    new_cwd = "/".join(cwd_splitted[: cwd_splitted.index("fun-bots") + 1])
    os.chdir(new_cwd)

def select_all_tables() -> tuple[sqlite3.Connection, sqlite3.Cursor]:
    connection = sqlite3.connect("mod.db")
    cursor = connection.cursor()

    sql_instruction = """
		SELECT * FROM sqlite_master WHERE type='table'
	"""
    cursor.execute(sql_instruction)

    return connection, cursor