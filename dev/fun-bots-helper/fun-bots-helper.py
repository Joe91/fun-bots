from tkinter import *
from tkinter import ttk

from tools.import_traces import import_traces
from tools.export_traces import export_traces

from tools.import_permission_and_config import import_permission_and_config
from tools.export_permission_and_config import export_permission_and_config

from tools.create_settings import create_settings
from tools.create_defaults import create_defaults
from tools.update_all_languages import update_languages
from tools.create_language import create_language

from tools.clear_settings import clear_settings
from tools.clear_all_paths import clear_all_paths

from tools.scan_for_invalid_objectives import scan_for_invalid_objectives
from tools.scan_for_invalid_nodes import scan_for_invalid_nodes
from tools.scan_for_invalid_comments import scan_for_invalid_comments

from tools.update_supported_maps import update_supported_maps
from tools.create_maplist import create_map_list

SHOW_DEV_TOOLS = True

master = Tk()
master.title("Fun Bots Helper")

master.tk.call("source", "theme/azure.tcl")
master.tk.call("set_theme", "dark")

# TRACES
def export_traces_fb() -> None:
    export_traces()
    print("\nMaps Exported\n")


def import_traces_fb() -> None:
    import_traces()
    print("\nMaps Imported\n")


# SETTINGS
def export_permission_and_config_fb() -> None:
    export_permission_and_config()
    print("\nPermissions and Configurations Exported\n")


def import_permission_and_config_fb() -> None:
    import_permission_and_config()
    print("\nPermissions and Configurations Imported\n")


# DEV TOOLS
def clear_all_paths_fb() -> None:
    clear_all_paths()
    print("\nPaths Cleared\n")


def clear_settings_fb() -> None:
    clear_settings()
    print("\nSettings Cleared\n")


def create_settings_defaults_fb() -> None:
    create_settings()
    create_defaults()
    update_languages()
    print("\nDefault, Settings and Languages Updated\n")


def create_mapfiles_fb() -> None:
    update_supported_maps()
    create_map_list()
    print("\nMapfiles Updated\n")


def fix_maps_fb() -> None:
    scan_for_invalid_objectives()
    scan_for_invalid_nodes()
    print("\nAll Maps Scanned and Fixed\n")


def create_language_fb() -> None:
    lang = entry.get()
    create_language(lang)


def fix_comments_fb() -> None:
    scan_for_invalid_comments()
    print("\nAll Comments Grammarly Checked\n")


tempRow = 0
master.columnconfigure(tuple(range(60)), weight=1)
master.rowconfigure(tuple(range(30)), weight=1)

Label(master, text="Trace Functions").grid(row=tempRow, sticky="nesw")
tempRow += 1
ttk.Button(
    master, text="Export Traces", command=export_traces_fb, style="Accent.TButton"
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1
ttk.Button(
    master, text="Import Traces", command=import_traces_fb, style="Accent.TButton"
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1

Label(master, text="Setting/Permission Functions").grid(
    row=tempRow, sticky="nesw", padx=4
)
tempRow += 1
ttk.Button(
    master,
    text="Export Permissions and Settings",
    command=export_permission_and_config_fb,
    style="Accent.TButton",
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1
ttk.Button(
    master,
    text="Import Permissions and Settings",
    command=import_permission_and_config_fb,
    style="Accent.TButton",
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1

if SHOW_DEV_TOOLS:
    Label(master, text="Dev Tools").grid(row=tempRow, sticky="nesw", padx=4)
    tempRow += 1
    ttk.Button(
        master,
        text="Clear all Traces from DB",
        command=clear_all_paths_fb,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master,
        text="Clear Settings from DB",
        command=clear_settings_fb,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master,
        text="Create Settings, Defaults and Update Languages",
        command=create_settings_defaults_fb,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master,
        text="Create Mapfiles",
        command=create_mapfiles_fb,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master, text="Fix Invalid Paths", command=fix_maps_fb, style="Accent.TButton"
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master, text="Fix Grammar", command=fix_comments_fb, style="Accent.TButton"
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1

    entry = Entry(master)
    entry.grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1

    ttk.Button(
        master,
        text="Create Language",
        command=create_language_fb,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1

mainloop()
