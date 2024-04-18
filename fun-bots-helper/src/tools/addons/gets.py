"""This module provides all intermediary functions for the scripts in /tools."""

import operator
import os
import sqlite3
from io import TextIOWrapper
from typing import Any, Callable, Dict, List, Tuple

import requests
from deep_translator import GoogleTranslator
from loguru import logger

# GLOBALS

ALL_GAME_MODES = [
    "TDM",
    "SDM",
    "TDM CQ",
    "Rush",
    "SQ Rush",
    "CQ Small",
    "CQ Large",
    "Assault",
    "Assault 2",
    "Assault Large",
    "GM",
    "CQ Dom",
    "Scavanger",
    "CTF",
    "Tank Superiority",
]
GAME_MODE_TRANSLATIONS = {
    "TDM": "TeamDeathMatch0",
    "SDM": "SquadDeathMatch0",
    "TDM CQ": "TeamDeathMatchC0",
    "Rush": "RushLarge0",
    "SQ Rush": "SquadRush0",
    "CQ Small": "ConquestSmall0",
    "CQ Large": "ConquestLarge0",
    "Assault": "ConquestAssaultSmall0",
    "Assault 2": "ConquestAssaultSmall1",
    "Assault Large": "ConquestAssaultLarge0",
    "GM": "GunMaster0",
    "CQ Dom": "Domination0",
    "Scavanger": "Scavenger0",
    "CTF": "CaptureTheFlag0",
    "Tank Superiority": "TankSuperiority0",
}
DISTANCE_MAX = 80


# Enviroment related functions.


def get_to_root() -> None:
    """Go back to fun-bots' root, i.e, fun-bots/.

    Args:
        None

    Returns:
        None
    """
    back = ""
    actual_position = os.getcwd()
    while True:
        os.chdir(os.getcwd() + back)
        if "mod.db" in os.listdir():
            break
        back += "/.."
        os.chdir(actual_position)


def get_it_running(function: Callable, *args: str) -> None:
    """Run a function through a pre-defined try-except KeyboardInterrupt block.
    The try statement goes back to the root directory and runs the function there.

    Args:
        - function - The function to be executed

    Returns:
        None
    """
    try:
        get_to_root()
        if args:
            function(*args)
        else:
            function()
    except KeyboardInterrupt:
        logger.warning("Crtl+C detected! Exiting Script...")


def get_version() -> str:
    """Return fun-bots' version.

    Args:
        None

    Returns:
        Fun-bots' version
    """
    with open("ext/Shared/Registry/Registry.lua", "r", encoding="utf-8") as infile:
        lines = infile.readlines()
        readout_active = False
        versions = {}
        for line in lines:
            if readout_active:
                if "=" in line:
                    line_splitted = line.split("=")
                    version = line_splitted[0].strip()
                    value = line_splitted[1].replace('"', "").strip()[:-1]
                    versions[version] = value
                    if "VERSION_TYPE" in line:
                        break
            if "VERSION = {" in line:
                readout_active = True

    if (
        versions["VERSION_LABEL"] in ["nil", ""]
        or versions["VERSION_TYPE"] == "VersionType.Release"
    ):
        return (
            "V"
            + versions["VERSION_MAJ"]
            + "."
            + versions["VERSION_MIN"]
            + "."
            + versions["VERSION_PATCH"]
        )

    maj_min_patch_label = (
        versions["VERSION_MAJ"]
        + "."
        + versions["VERSION_MIN"]
        + "."
        + versions["VERSION_PATCH"]
        + "-"
        + versions["VERSION_LABEL"]
    )
    if versions["VERSION_TYPE"] == "VersionType.DevBuild":
        return "v" + maj_min_patch_label
    if versions["VERSION_TYPE"] == "VersionType.Stable":
        return "V" + maj_min_patch_label
    return ""


def get_tables() -> Tuple[sqlite3.Connection, sqlite3.Cursor]:
    """Get all tables from the mod database.

    Args:
        None

    Returns:
        - connect - The object associated with the database connection
        - cursor - The object associated with the database operations
    """
    connect = sqlite3.connect("mod.db")
    cursor = connect.cursor()

    sql_instruction = """
		SELECT * FROM sqlite_master WHERE type='table'
	"""
    cursor.execute(sql_instruction)

    return connect, cursor


# File creation related functions.


def get_settings(first_key: str) -> List[Dict]:
    """Retrieve settings of SettingsDefinition.lua into a list.

    Args:
        - first_key - The key setting to be retrieved along with Description, Category and Default settings

    Returns:
        - all_settings - A list containing all settings
    """
    settings_definition = "ext/Shared/Settings/SettingsDefinition.lua"

    with open(settings_definition, "r", encoding="utf-8") as in_file:
        readout_active = False
        all_settings = []
        setting = {}
        for line in in_file.read().splitlines():
            if "Elements = {" in line:
                readout_active = True
            if readout_active:
                for key in [f"{first_key} =", "Description =", "Category ="]:
                    if key in line:
                        setting[key[:-2]] = line.split('"')[-2]
                if "Default =" in line:
                    setting["Default"] = (
                        line.split("=")[-1].replace(",", "").replace(" ", "")
                    )
                if "}," in line or (len(setting) != 0 and "}" in line):
                    all_settings.append(setting)
                    setting = {}

    return all_settings


def get_settings_lines(all_settings: List[Dict]) -> List[str]:
    """Create a list of formatted setting lines to be used in Config.lua.

    Args:
        - all_settings - The list of settings

    Returns:
        - out_file_lines - A list of formatted setting lines
    """
    out_file_lines, last_category = [], None

    for setting in all_settings:
        if setting["Category"] != last_category:
            out_file_lines.append("\n	-- " + setting["Category"])
            last_category = setting["Category"]
        temp_string = "	" + setting["Name"] + " = " + setting["Default"] + ","

        width = len(temp_string)
        number_of_tabs = (41 - width) // 4
        if ((41 - width) % 4) == 0:
            number_of_tabs -= 1
        if number_of_tabs <= 0:
            number_of_tabs = 1
        out_file_lines.append(
            temp_string + "	" * number_of_tabs + "-- " + setting["Description"]
        )
    out_file_lines.append("}")

    return out_file_lines


def get_lua_lines(all_settings: List[Dict]) -> List[str]:
    """Create a list of formatted language setting lines to be used in DEFAULT.lua.

    Args:
        - all_settings - The list of settings

    Returns:
        - out_file_lines - A list of formatted language setting lines
    """
    out_file_lines = []

    last_category = None
    for setting in all_settings:
        if setting["Category"] != last_category:
            if last_category is not None:
                out_file_lines.append("")
            out_file_lines.append("-- " + setting["Category"])
            last_category = setting["Category"]
        out_file_lines.append('Language:add(code, "' + setting["Text"] + '", "")')
        out_file_lines.append(
            'Language:add(code, "' + setting["Description"] + '", "")'
        )

    out_file_lines.extend(__scan_other_files())

    return out_file_lines


def __scan_other_files() -> List[str]:
    """Scan other files, besides SettingsDefinition.lua, searching for more settings.

    Args:
        None

    Returns:
        - out_file_lines_others - A list of external formatted language setting lines
    """
    list_of_translation_files = [
        "ext/Client/ClientNodeEditor.lua",
        "ext/Server/BotSpawner.lua",
        "ext/Server/UIServer.lua",
        "ext/Server/UIPathMenu.lua",
        "ext/Server/NodeCollection.lua",
    ]
    out_file_lines_others = []
    for file_name in list_of_translation_files:
        out_file_lines_others.append("\n-- Strings of " + file_name)
        with open(file_name, "r", encoding="utf-8") as file_with_translation:
            for line in file_with_translation.read().splitlines():
                if "Language:I18N(" in line:
                    translation = line.split("Language:I18N(")[1]
                    translation = translation.split(translation[0])[1]
                    if translation != "":
                        newLine = 'Language:add(code, "' + translation + '", "")'
                        if newLine not in out_file_lines_others:
                            out_file_lines_others.append(newLine)

    return out_file_lines_others


def get_js_lines() -> List[str]:
    """Create a list of formatted language setting lines to be used in DEFAULT.js.

    Args:
        None

    Returns:
        - out_file_lines - A list of formatted language setting lines
    """
    index_html = "WebUI/index.html"
    list_of_js_translation_files = [
        "WebUI/classes/EntryElement.js",
        "WebUI/classes/BotEditor.js",
    ]

    out_file_lines = []

    with open(index_html, "r", encoding="utf-8") as in_file_html:
        for line in in_file_html.read().splitlines():
            if 'data-lang="' in line:
                translation_html = line.split('data-lang="')[1].split('"')[0]
                if translation_html not in out_file_lines:
                    out_file_lines.append(translation_html)
        for file_name in list_of_js_translation_files:
            with open(file_name, "r", encoding="utf-8") as file_with_translation:
                for line in file_with_translation.read().splitlines():
                    if "I18N('" in line:
                        translation = line.split("I18N('")[1]
                        translation = translation.split("'")[0]
                        if translation not in out_file_lines:
                            out_file_lines.append(translation)

    return out_file_lines


def get_map_lines_updated() -> List[List]:
    """Build a list of maps to be used in Supported-maps.md.

    Args:
        None

    Returns:
        - map_items - A list of all maps' information
    """
    maps_with_gunmaster = ["XP2", "XP4", "sp_", "coop_"]
    maps_without_tdm_cq = ["XP2", "sp_", "coop_"]

    map_items = []

    file_names = os.listdir("mapfiles")
    for file_name in file_names:
        name_parts = file_name.split(".")[0].rsplit("_", 1)
        mapname = name_parts[0]
        mapname_splitted = mapname.split("_")[0]
        translated_game_mode = name_parts[1]
        game_mode = ""

        vehicle_support = False
        with open("mapfiles" + "/" + file_name, "r", encoding="utf-8") as temp_map_file:
            for line in temp_map_file.readlines():
                if '"Vehicles":[' in line:
                    vehicle_support = True
                    break

        for mode in ALL_GAME_MODES:
            if GAME_MODE_TRANSLATIONS[mode] == translated_game_mode:
                game_mode = mode
                break

        if game_mode in ALL_GAME_MODES:
            if game_mode == "TDM":
                if mapname_splitted in maps_with_gunmaster:
                    map_items.append([mapname, "GM", "GunMaster0", vehicle_support])
                if mapname_splitted not in maps_without_tdm_cq:
                    map_items.append(
                        [mapname, game_mode, translated_game_mode, vehicle_support]
                    )
                map_items.append(
                    [mapname, "TDM CQ", "TeamDeathMatchC0", vehicle_support]
                )
            else:
                map_items.append(
                    [mapname, game_mode, translated_game_mode, vehicle_support]
                )

    map_items = sorted(map_items, key=operator.itemgetter(2, 1))

    return map_items


def get_map_lines_created() -> List[List]:
    """Build a list of maps to be used in MapList.txt.

    Args:
        None

    Returns:
        - map_items - A list of all maps' information
    """
    rounds_to_use = "1"
    maps_with_gunmaster = ["XP2", "XP4"]
    maps_without_tdm_cq = ["XP2"]

    map_items = []

    file_names = os.listdir("mapfiles")
    for file_name in file_names:
        name_parts = file_name.split(".")[0].rsplit("_", 1)
        mapname = name_parts[0]
        mapname_splitted = mapname.split("_")[0]
        translated_game_mode = name_parts[1]
        game_mode = ""

        for mode in ALL_GAME_MODES:
            if GAME_MODE_TRANSLATIONS[mode] == translated_game_mode:
                game_mode = mode
                break

        if game_mode in ALL_GAME_MODES:
            if game_mode == "TDM":
                if mapname_splitted in maps_with_gunmaster:
                    map_items.append([mapname, "GunMaster0", rounds_to_use])
                if mapname_splitted not in maps_without_tdm_cq:
                    map_items.append([mapname, translated_game_mode, rounds_to_use])
                map_items.append([mapname, "TeamDeathMatchC0", rounds_to_use])
            else:
                map_items.append([mapname, translated_game_mode, rounds_to_use])

    map_items = sorted(map_items, key=operator.itemgetter(2, 1))

    return map_items


def get_updated_lines_lua(in_file: TextIOWrapper) -> List[str]:
    """Update all lua language files based on DEFAULT.lua.

    Args:
        - in_file - The file to be updated

    Returns:
        - out_file_lines - A list with all translated lines, including new ones
    """
    language_file = "ext/Shared/Languages/DEFAULT.lua"
    with open(language_file, "r", encoding="utf8") as lua_file:
        lua_lines = lua_file.read().splitlines()

    out_file_lines = in_file.read().splitlines()

    LANG = out_file_lines[0].split("'")[1].split("_")[0]
    if LANG == "cn":
        LANG = "zh-CN"

    translator = GoogleTranslator(source="en", target=LANG)

    lines_to_remove = [
        out_line for out_line in out_file_lines if "Language:add" in out_line
    ]
    lines_to_add = []

    for line in lua_lines:
        if "Language:add" in line:
            line_found = False
            line_part = line.split('",')[0]
            for out_line in out_file_lines:
                if "Language:add" in out_line:
                    line_part_2 = out_line.split('",')[0]
                    if line_part == line_part_2:
                        line_found = True
                        if out_line in lines_to_remove:
                            lines_to_remove.remove(out_line)
                        break
            if not line_found:
                lines_to_add.append(get_translation(translator, line))
    for remove_line in lines_to_remove:
        out_file_lines.remove(remove_line)
    for add_line in lines_to_add:
        out_file_lines.append(add_line)
    return out_file_lines


def get_updated_lines_js(in_file: TextIOWrapper) -> List[str]:
    """Update all JS language files based on DEFAULT.js.

    Args:
        - in_file - The file to be updated

    Returns:
        - out_file_lines - A list with all translated lines, including new ones
    """
    language_file_js = "WebUI/languages/DEFAULT.js"

    with open(language_file_js, "r", encoding="utf8") as js_file:
        js_lines = js_file.read().splitlines()

    out_file_lines = in_file.read().splitlines()

    LANG = out_file_lines[0].split("'")[1].split("_")[0]
    if LANG == "cn":
        LANG = "zh-CN"
    translator = GoogleTranslator(source="en", target=LANG)

    lines_to_remove = [out_line for out_line in out_file_lines[6:] if ":" in out_line]
    lines_to_add = []

    for line in js_lines[6:]:
        if ":" in line:
            line_found = False
            line_part = line.split('": ')[0].replace(" ", "").replace("	", "")
            for out_line in out_file_lines[6:]:
                if ":" in line:
                    line_part_2 = (
                        out_line.split('": ')[0].replace(" ", "").replace("	", "")
                    )
                    if line_part == line_part_2:
                        line_found = True
                        if out_line in lines_to_remove:
                            lines_to_remove.remove(out_line)
                        break
            if not line_found:
                if line.startswith('\t"') and not line.split(":")[0].startswith('\t""'):
                    lines_to_add.append(get_translation(translator, line))
    for remove_line in lines_to_remove:
        out_file_lines.remove(remove_line)
    for add_line in lines_to_add:
        out_file_lines.insert(-1, add_line)

    return out_file_lines


def get_maps_merged(merge_file_1: str, merge_file_2: str) -> List[str]:
    """Merge the paths of two map files.

    Args:
        - merge_file_1 - 1st map file
        - merge_file_2 - 2nd map file

    Returns:
        - out_file_lines - The lines of the merged map file
    """
    with open("mapfiles/" + merge_file_1, "r", encoding="utf-8") as base_file:
        out_file_lines = base_file.readlines()
        last_base_path = out_file_lines[-1].split(";")[0]

        with open("mapfiles/" + merge_file_2, "r", encoding="utf-8") as addition_file:
            lines_to_add = addition_file.readlines()
            path_dict: Dict[str, str]
            path_dict = {}
            last_path = ""
            for line in lines_to_add[1:-1]:
                lines_parts_addition = line.split(";")
                if len(lines_parts_addition) > 1:
                    current_path = lines_parts_addition[0]
                    if current_path != last_path:
                        path_dict[current_path] = str(
                            int(last_base_path) + 1 + len(path_dict)
                        )
                        last_path = current_path
            for line in lines_to_add[1:-1]:
                lines_parts_addition = line.split(";")
                if len(lines_parts_addition) >= 6:
                    lines_parts_addition[0] = path_dict[lines_parts_addition[0]]
                    data_parts = lines_parts_addition[-1]
                    if "links" in data_parts.lower():
                        pos_1 = data_parts.find("[[") + 2
                        pos_2 = data_parts.find("]]")
                        link_part = data_parts[pos_1:pos_2]
                        all_links = link_part.split("],[")
                        new_link_parts = []
                        for link in all_links:
                            parts_of_link = link.split(",")
                            if parts_of_link[0] in path_dict:
                                parts_of_link[0] = path_dict[parts_of_link[0]]
                                new_link_parts.append(",".join(parts_of_link))
                        newLinks = "],[".join(new_link_parts)
                        lines_parts_addition[-1] = (
                            data_parts[:pos_1] + newLinks + data_parts[pos_2:]
                        )
                    new_line = ";".join(lines_parts_addition)
                    out_file_lines.append(new_line)
    return out_file_lines


# Fixing functions.


def get_nodes_fixed(in_file: TextIOWrapper) -> List[str]:
    """Fix invalid nodes of all maps.

    Args:
        - in_file - The opened map file to be fixed

    Returns:
        - out_file_lines - The lines to update the map's node
    """
    out_file_lines = in_file.readlines()
    for i in range(2, len(out_file_lines) - 2):
        current_items = out_file_lines[i].split(";")
        current_path = int(current_items[0])
        pos_x = float(current_items[2])
        pos_y = float(current_items[3])
        pos_z = float(current_items[4])

        items = out_file_lines[i - 1].split(";")
        last_path = int(items[0])
        last_pos_x = float(items[2])
        last_pos_y = float(items[3])
        last_pos_z = float(items[4])

        items = out_file_lines[i + 1].split(";")
        next_path = int(items[0])
        next_pos_x = float(items[2])
        next_pos_y = float(items[3])
        next_pos_z = float(items[4])

        if (
            last_path == current_path and next_path == current_path
        ):  # Wrong in the middle
            if (
                abs(last_pos_x - pos_x) > DISTANCE_MAX
                or abs(last_pos_y - pos_y) > DISTANCE_MAX
                or abs(last_pos_z - pos_z) > DISTANCE_MAX
            ) and (
                abs(next_pos_x - pos_x) > DISTANCE_MAX
                or abs(next_pos_y - pos_y) > DISTANCE_MAX
                or abs(next_pos_z - pos_z) > DISTANCE_MAX
            ):
                current_items[2] = format(
                    last_pos_x + (next_pos_x - last_pos_x) / 2, ".6f"
                )
                current_items[3] = format(
                    last_pos_y + (next_pos_y - last_pos_y) / 2, ".6f"
                )
                current_items[4] = format(
                    last_pos_z + (next_pos_z - last_pos_z) / 2, ".6f"
                )
                out_file_lines[i] = ";".join(current_items)
        if last_path == current_path and next_path != current_path:  # Wrong at the end
            if (
                abs(last_pos_x - pos_x) > DISTANCE_MAX
                or abs(last_pos_y - pos_y) > DISTANCE_MAX
                or abs(last_pos_z - pos_z) > DISTANCE_MAX
            ):
                current_items[2] = format(last_pos_x + 0.2, ".6f")
                current_items[3] = format(last_pos_y, ".6f")
                current_items[4] = format(last_pos_z + 0.2, ".6f")
                out_file_lines[i] = ";".join(current_items)
        if (
            last_path != current_path and next_path == current_path
        ):  # Wrong at the start
            if (
                abs(next_pos_x - pos_x) > DISTANCE_MAX
                or abs(next_pos_y - pos_y) > DISTANCE_MAX
                or abs(next_pos_z - pos_z) > DISTANCE_MAX
            ):
                current_items[2] = format(next_pos_x + 0.2, ".6f")
                current_items[3] = format(next_pos_y, ".6f")
                current_items[4] = format(next_pos_z + 0.2, ".6f")
                out_file_lines[i] = ";".join(current_items)

    return out_file_lines


def get_objectives_fixed(in_file: TextIOWrapper) -> Tuple[List[str], List[str]]:
    """Fix invalid objective names.

    Args:
        - in_file - The opened map file to have objectives fixed

    Returns:
        - out_file_lines - The new lines used to update the map's objectives
        - file_lines - A list with the original file lines
    """
    all_objectives = []
    file_lines = in_file.readlines()
    for line in file_lines[1:]:
        if '"Objectives":[' in line:
            objectives = line.split('"Objectives":[')[1].split("]")[0].split(",")
            for objective in objectives:
                if objective not in all_objectives:
                    all_objectives.append(objective)
    all_objectives.sort()
    objectives_to_rename = [
        objective_name
        for objective_name in all_objectives
        if objective_name.lower() != objective_name
    ]

    return objectives_to_rename, file_lines


def get_links_and_vehicles_fixed(in_file: TextIOWrapper) -> List[str]:
    """Fix links and vehicles of all maps.

    Args:
        - in_file - The file to be updated

    Returns:
        - out_file_lines - The lines to update the map's links and vehicles
    """
    lines = in_file.readlines()
    out_file_lines = [lines[0]]
    (
        paths_objectives_us,
        paths_objectives_ru,
        vehicles,
        vehicle_paths,
    ) = get_paths_to_fix(lines)

    replace_dict, replace_paths = get_paths_to_replace(
        lines, paths_objectives_us, paths_objectives_ru, vehicles, vehicle_paths
    )

    for line in lines[1:]:
        path_Index = int(line.split(";")[0])
        if path_Index in replace_paths and '"Objectives":[' in line:
            for key, value in replace_dict.items():
                line = line.replace(key, value)
        if 'Links":{}' in line:
            for link in [
                ',"Links":{}',
                '"Links":{},',
                '"Links":{}',
                ',"Links":{}',
                '"LinkMode":0,',
                ',"LinkMode":0',
                '"LinkMode":0',
            ]:
                line = line.replace(link, "")
        if '"Objectives":{}' in line:
            for objective in [
                ',"Objectives":{}',
                '"Objectives":{},',
                '"Objectives":{}',
            ]:
                line = line.replace(objective, "")
        if '"Vehicles":{}' in line:
            for vehicle in [
                ',"Vehicles":{}',
                '"Vehicles":{},',
                '"Vehicles":{}',
            ]:
                line = line.replace(vehicle, "")
        if ";{}" in line:
            line = line.replace("{}", "")
        out_file_lines.append(line)

    return out_file_lines


# Auxiliary functions.


def get_translation(translator: Any, line: str) -> str:
    """Translate a line from one language to another.

    Args:
        - translator - The translator object used to translate it
        - line - The line to be translated

    Returns:
        - str - The translated line
    """
    splitted_line = line.split('"')
    splitted_line.remove("")
    splitted_line.insert(3, translator.translate(splitted_line[1]))
    return '"'.join(splitted_line)


def get_paths_to_fix(
    lines: List[str],
) -> Tuple[List[int], List[int], Dict[int, str], List[int]]:
    """Computes all paths that needs to be fixed.

    Args:
        - lines - The file lines

    Returns:
        - paths_objectives_us - The US paths objectives to be fixed
        - paths_objectives_ru - The RU paths objectives to be fixed
        - vehicles - A dictionary of paths for objectives with vehicles in them
        - vehicle_paths - The vehicle paths themselves
    """
    paths_objectives_us = []
    paths_objectives_ru = []
    vehicles = {}
    vehicle_paths = []
    for line in lines[1:]:
        if '"Objectives":[' in line:
            objectives = line.split('"Objectives":[')[1].split("]")[0].split(",")
            path_index = int(line.split(";")[0])
            if len(objectives) == 1 and "base" in objectives[0]:
                if "us" in objectives[0]:
                    paths_objectives_us.append(path_index)
                elif "ru" in objectives[0]:
                    paths_objectives_ru.append(path_index)
            if len(objectives) == 1 and "vehicle" in objectives[0]:
                vehicles[path_index] = objectives[0]
                vehicle_paths.append(path_index)

    return paths_objectives_us, paths_objectives_ru, vehicles, vehicle_paths


def get_paths_to_replace(
    lines: List[str],
    paths_objectives_us: List[int],
    paths_objectives_ru: List[int],
    vehicles: Dict[int, str],
    vehicle_paths: List[int],
) -> Tuple[Dict[str, str], List[int]]:
    """Replace the content of paths that need to be fixed.

    Args:
        - lines - The file lines
        - paths_objectives_us - The US paths objectives to be fixed
        - paths_objectives_ru - The RU paths objectives to be fixed
        - vehicles - A dictionary of paths for objectives with vehicles in them
        - vehicle_paths - The vehicle paths themselves

    Returns:
        - replace_dict - The strings used to replace wrong paths objectives
        - replace_paths - The paths' index themselves
    """
    replace_dict = {}
    replace_paths = []
    for line in lines[1:]:
        path_index = int(line.split(";")[0])
        for paths_objectives, ally_team, enemy_team in zip(
            [paths_objectives_us, paths_objectives_ru], ["us", "ru"], ["ru", "us"]
        ):
            if path_index in paths_objectives:
                if "Links" in line and 'Links":{}' not in line:
                    links = line.split("[[")[1].split("]]")[0].split("],[")
                    for link in links:
                        linked_path = int(link.split(",")[0])
                        if linked_path in vehicle_paths:
                            if (
                                ally_team not in vehicles[linked_path]
                                or enemy_team in vehicles[linked_path]
                            ):
                                vehicle_string = vehicles[linked_path]
                                replace_dict[vehicle_string] = (
                                    vehicle_string.replace(enemy_team, "")[:-1]
                                    + f'{ally_team}"'
                                )
                                replace_paths.append(linked_path)

    return replace_dict, replace_paths
