"""This module provides functions that interact with the mod database.

All functions receive a cursor that's used to interact with the mod database, writing files out of 
specific SQL instructions or inserting values in the database itself. All functions return None.
"""

import os
import sqlite3
import json

from loguru import logger


def set_permission_config_files(cursor: sqlite3.Cursor) -> None:
    """Write permission_and_config files out of the database.

    Args:
        - cursor - The object that'll interact with the database

    Returns:
        None
    """
    export_list = ["FB_Permissions", "FB_Config_Trace", "FB_Settings"]
    dest_folder = "permission_and_config"

    for item in export_list:
        structure = cursor.execute("PRAGMA table_info('" + item + "')").fetchall()
        file_name = item + ".cfg"
        with open(dest_folder + "/" + file_name, "w", encoding="utf-8") as out_file:
            header = [column[1] for column in structure]
            out_file.write(";".join(header) + "\n")
            try:
                sql_instruction = (
                    "SELECT * FROM " + item + " ORDER BY " + structure[-3][1] + " ASC"
                )
            except IndexError:
                logger.warning(f"{item} table not found!")
            else:
                logger.info("Export " + item)
                cursor.execute(sql_instruction)
                table_content = cursor.fetchall()
                for line in table_content:
                    outList = [
                        format(item, ".6f") if isinstance(item, float) else str(item)
                        for item in line
                    ]
                    out_file.write(";".join(outList) + "\n")


def set_permission_config_db(cursor: sqlite3.Cursor) -> None:
    """Write permission and configuration tables to the database, out of permission_and_config.

    Args:
        - cursor - The object that'll interact with the database

    Returns:
        None
    """
    all_structures = {
        "FB_Permissions": ["GUID", "PlayerName", "Value", "Time"],
        "FB_Config_Trace": ["Key", "Value", "Time"],
        "FB_Settings": ["Key", "Value", "Time"],
    }
    source_folder = "permission_and_config"

    file_names = os.listdir(source_folder)

    for file_name in file_names:
        table_name = file_name.split(".")[0]
        logger.info("Import " + table_name)
        cursor.execute("DROP TABLE IF EXISTS " + table_name)

        sql_instruction = "CREATE TABLE " + table_name + " ("
        for key, value in all_structures.items():
            if key == table_name:
                for item in value:
                    if item == "Time":
                        sql_instruction = sql_instruction + item + " DATETIME, "
                    else:
                        sql_instruction = sql_instruction + item + " TEXT, "
                break
        sql_instruction = sql_instruction[:-2] + ");"
        cursor.execute(sql_instruction)
        with open(source_folder + "/" + file_name, "r", encoding="utf-8") as in_file:
            all_data = [
                line.replace("\n", "").split(";") for line in in_file.readlines()[1:]
            ]
            items = all_structures[table_name]
            cursor.executemany(
                "INSERT INTO "
                + table_name
                + " ("
                + ", ".join(items)
                + ") VALUES("
                + (len(items) * "?,")[:-1]
                + ")",
                all_data,
            )

def sort_dict_and_lists(data):
    if isinstance(data, dict):
        return {k: sort_dict_and_lists(data[k]) for k in sorted(data)}
    elif isinstance(data, list):
        return sorted(sort_dict_and_lists(item) for item in data)
    else:
        return data
    
def sort_dict_and_string_lists(data):
    if isinstance(data, dict):
        return {k: sort_dict_and_string_lists(data[k]) for k in sorted(data)}
    elif isinstance(data, list):
        if all(isinstance(item, str) for item in data):
            return sorted(data)
        elif all(isinstance(item, (int, float)) for item in data):
            return data
        else:
            return [sort_dict_and_string_lists(item) for item in data]
    else:
        return data
    
def set_traces_files(cursor: sqlite3.Cursor) -> None:
    """Write trace mapfiles out of the database.

    Args:
        - cursor - The object that'll interact with the database

    Returns:
        None
    """
    content = cursor.fetchall()
    ignore_list = [
        "sqlite_sequence",
        "FB_Permissions",
        "FB_Config_Trace",
        "FB_Settings",
    ]
    dest_folder = "mapfiles"

    for item in content:
        if item[1] in ignore_list:
            continue

        logger.info("Export " + item[1])
        structure = cursor.execute("PRAGMA table_info('" + item[1] + "')").fetchall()

        file_name = item[1].replace("_table", "") + ".map"
        with open(dest_folder + "/" + file_name, "w", encoding="utf-8") as out_file:
            header = [column[1] for column in structure[1:]]
            out_file.write(";".join(header) + "\n")
            sql_instruction = (
                "SELECT * FROM " + item[1] + " ORDER BY pathIndex, pointIndex ASC"
            )
            cursor.execute(sql_instruction)
            table_content = cursor.fetchall()
            for line in table_content:
                outList = [
                    format(item, ".6f") if isinstance(item, float) else str(item)
                    for item in line[1:]
                ]
                dataString = outList[-1]
                if "{" in dataString and "}" in dataString:
                    data_dict = json.loads(dataString)
                    sorted_data = sort_dict_and_string_lists(data_dict)
                    sorted_data_keys = json.dumps(sorted_data, separators=(',', ':'))
                    outList[-1] = sorted_data_keys
                out_file.write(";".join(outList) + "\n")


def set_traces_db(cursor: sqlite3.Cursor) -> None:
    """Write trace tables to the the database, out of mapfiles folder.

    Args:
        - cursor - The object that'll interact with the database

    Returns:
        None
    """
    source_folder = "mapfiles"
    file_names = os.listdir(source_folder)

    for file_name in file_names:
        table_name = file_name.split(".")[0] + "_table"
        logger.info("Import " + table_name)
        cursor.execute("DROP TABLE IF EXISTS " + table_name)
        sql_instruction = (
            """
			CREATE TABLE """
            + table_name
            + """ (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			pathIndex INTEGER,
			pointIndex INTEGER,
			transX FLOAT,
			transY FLOAT,
			transZ FLOAT,
			inputVar INTEGER,
			data TEXT
			)
		"""
        )
        cursor.execute(sql_instruction)
        with open(source_folder + "/" + file_name, "r", encoding="utf-8") as in_file:
            all_node_data = []
            for line in in_file.readlines()[1:]:
                if len(line) > 1:
                    line_data = line.split(";")
                    dataString = (
                        line_data[6].replace("\n", "") if len(line_data) >= 7 else ""
                    )
                    node = (
                        int(line_data[0]),
                        int(line_data[1]),
                        float(line_data[2]),
                        float(line_data[3]),
                        float(line_data[4]),
                        int(line_data[5]),
                        dataString,
                    )
                    all_node_data.append(node)
            cursor.executemany(
                "INSERT INTO "
                + table_name
                + " (pathIndex, pointIndex, transX, transY, transZ, inputVar, data) VALUES(?,?,?,?,?,?,?)",
                all_node_data,
            )
