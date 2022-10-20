from tkinter import *
from tkinter import ttk

from tools.import_traces import importTraces
from tools.export_traces import exportTraces

from tools.import_permission_and_config import importPermissionAndConfig
from tools.export_permission_and_config import exportPermissionAndConfig

from tools.create_settings import createSettings
from tools.create_defaults import createDefaults
from tools.update_all_languages import updateLanguages
from tools.create_language import createLanguage

from tools.clear_settings import clearSettings
from tools.clear_all_paths import clearAllPaths

from tools.scan_for_invalid_objectives import scanForInvalidObjectives
from tools.scan_for_invalid_nodes import scanForInvalidNodes

from tools.update_supported_maps import updateSupportedMaps
from tools.create_maplist import createMaplist

SHOW_DEV_TOOLS = True

master = Tk()
master.title("fun-bots-helper")

master.tk.call("source", "azure.tcl")
master.tk.call("set_theme", "dark")

# TRACES
def export_traces() -> None:
    exportTraces()
    print("\nMaps Exported\n")


def import_traces() -> None:
    importTraces()
    print("\nMaps Imported\n")


# SETTINGS
def export_settings() -> None:
    exportPermissionAndConfig()
    print("\nPermission and Configurations Exported\n")


def import_settings() -> None:
    importPermissionAndConfig()
    print("\nPermission and Configurations Imported\n")


# OTHER STUFF
def clear_paths() -> None:
    clearAllPaths()
    print("\nPaths Cleared\n")


def clear_settings() -> None:
    clearSettings()
    print("\nSettings Cleared\n")


def create_settings_defaults() -> None:
    createSettings()
    createDefaults()
    updateLanguages()
    print("\nDefault Templates and Settings Updated\n")


def create_mapfiles() -> None:
    updateSupportedMaps()
    createMaplist()
    print("\nMapfiles Updated\n")


def fix_maps() -> None:
    scanForInvalidObjectives()
    scanForInvalidNodes()
    print("\nAll Maps Scanned and Fixed\n")


def create_language() -> None:
    lang = entry.get()
    createLanguage(lang)


tempRow = 0
master.columnconfigure(tuple(range(60)), weight=1)
master.rowconfigure(tuple(range(30)), weight=1)

Label(master, text="Trace functions").grid(row=tempRow, sticky="nesw")
tempRow += 1
ttk.Button(
    master, text="Export Traces", command=export_traces, style="Accent.TButton"
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1
ttk.Button(
    master, text="Import Traces", command=import_traces, style="Accent.TButton"
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1

Label(master, text="Settings / Permission functions").grid(
    row=tempRow, sticky="nesw", padx=4
)
tempRow += 1
ttk.Button(
    master,
    text="Export Permissions and Settings",
    command=export_settings,
    style="Accent.TButton",
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1
ttk.Button(
    master,
    text="Import Permissions and Settings",
    command=import_settings,
    style="Accent.TButton",
).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
tempRow += 1

if SHOW_DEV_TOOLS:
    Label(master, text="Other Stuff").grid(row=tempRow, sticky="nesw", padx=4)
    tempRow += 1
    ttk.Button(
        master,
        text="Clear all Traces from DB",
        command=clear_paths,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master,
        text="Clear settings from DB",
        command=clear_settings,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master,
        text="Create Settings + Defaults",
        command=create_settings_defaults,
        style="Accent.TButton",
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master, text="Create Mapfiles", command=create_mapfiles, style="Accent.TButton"
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1
    ttk.Button(
        master, text="Fix Invalid paths", command=fix_maps, style="Accent.TButton"
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1

    entry = Entry(master)
    entry.grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1

    ttk.Button(
        master, text="Create Language", command=create_language, style="Accent.TButton"
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow += 1

mainloop()
