import sys

sys.path.append("tools")

import os
from tkinter import Entry, Label, Tk, mainloop, ttk

from loguru import logger

from tools.clear_all_paths import clear_all_paths
from tools.clear_settings import clear_settings
from tools.create_defaults import create_defaults
from tools.create_language import create_language
from tools.create_maplist import create_map_list
from tools.create_settings import create_settings
from tools.export_permission_and_config import export_permission_and_config
from tools.export_traces import export_traces
from tools.import_permission_and_config import import_permission_and_config
from tools.import_traces import import_traces
from tools.scan_for_invalid_comments import scan_for_invalid_comments
from tools.scan_for_invalid_nodes import scan_for_invalid_nodes
from tools.scan_for_invalid_objectives import scan_for_invalid_objectives
from tools.update_all_languages import update_languages
from tools.update_supported_maps import update_supported_maps

os.system("cls" if os.name == "nt" else "clear")

SHOW_DEV_TOOLS = True

master = Tk()
master.title("Fun Bots Helper")

master.tk.call("source", "theme/azure.tcl")
master.tk.call("set_theme", "dark")

# TRACES
def export_traces_fb() -> None:
    export_traces()
    logger.info("Maps Exported\n")


def import_traces_fb() -> None:
    import_traces()
    logger.info("Maps Imported\n")


# SETTINGS
def export_permission_and_config_fb() -> None:
    export_permission_and_config()
    logger.info("Permissions and Configurations Exported\n")


def import_permission_and_config_fb() -> None:
    import_permission_and_config()
    logger.info("Permissions and Configurations Imported\n")


# DEV TOOLS
def clear_all_paths_fb() -> None:
    clear_all_paths()
    logger.info("Paths Cleared\n")


def clear_settings_fb() -> None:
    clear_settings()
    logger.info("Settings Cleared\n")


def create_settings_defaults_fb() -> None:
    create_settings()
    create_defaults()
    update_languages()
    logger.info("Default, Settings and Languages Updated\n")


def create_mapfiles_fb() -> None:
    update_supported_maps()
    create_map_list()
    logger.info("Mapfiles Updated\n")


def fix_maps_fb() -> None:
    scan_for_invalid_objectives()
    scan_for_invalid_nodes()
    logger.info("All Maps Scanned and Fixed\n")


def create_language_fb() -> None:
    lang = entry.get()
    create_language(lang)


def fix_comments_fb() -> None:
    scan_for_invalid_comments()
    logger.info("All Comments Grammarly Checked\n")


temp_row = 0
master.columnconfigure(tuple(range(60)), weight=1)
master.rowconfigure(tuple(range(30)), weight=1)

Label(master, text="Trace Functions").grid(row=temp_row, sticky="nesw")
temp_row += 1
ttk.Button(
    master, text="Export Traces", command=export_traces_fb, style="Accent.TButton"
).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
temp_row += 1
ttk.Button(
    master, text="Import Traces", command=import_traces_fb, style="Accent.TButton"
).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
temp_row += 1

Label(master, text="Setting/Permission Functions").grid(
    row=temp_row, sticky="nesw", padx=4
)
temp_row += 1
ttk.Button(
    master,
    text="Export Permissions and Settings",
    command=export_permission_and_config_fb,
    style="Accent.TButton",
).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
temp_row += 1
ttk.Button(
    master,
    text="Import Permissions and Settings",
    command=import_permission_and_config_fb,
    style="Accent.TButton",
).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
temp_row += 1

if SHOW_DEV_TOOLS:
    Label(master, text="Dev Tools").grid(row=temp_row, sticky="nesw", padx=4)
    temp_row += 1
    ttk.Button(
        master,
        text="Clear all Traces from DB",
        command=clear_all_paths_fb,
        style="Accent.TButton",
    ).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1
    ttk.Button(
        master,
        text="Clear Settings from DB",
        command=clear_settings_fb,
        style="Accent.TButton",
    ).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1
    ttk.Button(
        master,
        text="Create Settings, Defaults and Update Languages",
        command=create_settings_defaults_fb,
        style="Accent.TButton",
    ).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1
    ttk.Button(
        master,
        text="Create Mapfiles",
        command=create_mapfiles_fb,
        style="Accent.TButton",
    ).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1
    ttk.Button(
        master, text="Fix Invalid Paths", command=fix_maps_fb, style="Accent.TButton"
    ).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1
    ttk.Button(
        master, text="Fix Grammar", command=fix_comments_fb, style="Accent.TButton"
    ).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1

    entry = Entry(master)
    entry.grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1

    ttk.Button(
        master,
        text="Create Language",
        command=create_language_fb,
        style="Accent.TButton",
    ).grid(row=temp_row, sticky="nesw", pady=4, padx=4)
    temp_row += 1

try:
    mainloop()
except KeyboardInterrupt:
    logger.warning("Crtl+C detected! Exiting Helper...")
