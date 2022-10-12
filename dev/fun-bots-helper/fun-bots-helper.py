from tkinter import *
import os

from tools.import_traces import importTraces
from tools.export_traces import exportTraces

from tools.import_permission_and_config import importPermissionAndConfig
from tools.export_permission_and_config import exportPermissionAndConfig

from tools.create_Settings import createSettings
from tools.create_translations import createTranslations
from tools.update_all_languages import updateLanguages

from tools.clear_settings import clearSettings
from tools.clear_all_paths import clearAllPaths

from tools.scan_for_invalid_objectives import scanForInvalidObjectives
from tools.scan_for_invalid_nodes import scanForInvalidNodes

from tools.update_supported_maps import updateSupportedMaps
from tools.create_maplist import createMaplist

SHOW_DEV_TOOLS = True

master = Tk()
master.title("fun-bots-helper")

# use "auto-py-to-exe" to convert to exe files

relativePath = "./"
if os.path.isfile("./../mod.db"):
    relativePath = "./../"
elif os.path.isfile("./../../mod.db"):
    relativePath = "./../../"

# TRACES
def export_traces() -> None:
    exportTraces(relativePath)
    # os.system("python tools/export_traces.py" + " " + relativePath)
    print("maps exported")


def import_traces() -> None:
    importTraces(relativePath)
    # os.system("python tools/import_traces.py"+ " " + relativePath)
    print("maps imported")


# SETTINGS
def export_settings() -> None:
    exportPermissionAndConfig(relativePath)
    # os.system("python tools/export_permission_and_config.py"+ " " + relativePath)
    print("export")


def import_settings() -> None:
    importPermissionAndConfig(relativePath)
    # os.system("python tools/import_permission_and_config.py"+ " " + relativePath)
    print("import")


# OTHER STUFF
def clear_paths() -> None:
    clearAllPaths(relativePath)
    # os.system("python tools/clear_all_paths.py"+ " " + relativePath)
    print("paths cleared")


def clear_settings() -> None:
    clearSettings(relativePath)
    # os.system("python tools/clear_settings.py"+ " " + relativePath)
    print("settings cleared")


def create_settings_translations() -> None:
    createSettings(relativePath)
    createTranslations(relativePath)
    updateLanguages(relativePath)
    # os.system("python tools/create_Settings.py"+ " " + relativePath)
    # os.system("python tools/create_translations.py"+ " " + relativePath)
    # os.system("python tools/update_all_languages.py"+ " " + relativePath)
    print("translation-templates and settigns updated")


def create_mapfiles() -> None:
    updateSupportedMaps(relativePath)
    createMaplist(relativePath)
    # os.system("python tools/create_maplist.py"+ " " + relativePath)
    # os.system("python tools/update_supported_maps.py"+ " " + relativePath)
    print("mapfiles updated")


def fix_maps() -> None:
    scanForInvalidObjectives(relativePath)
    scanForInvalidNodes(relativePath)
    print("all maps scanned and fixed")
    # os.system("python tools/scan_for_invalid_objectives.py"+ " " + relativePath)
    # os.system("python tools/scan_for_invalid_nodes.py"+ " " + relativePath)


tempRow = 0
master.columnconfigure(tuple(range(60)), weight=1)
master.rowconfigure(tuple(range(30)), weight=1)
# var1 = IntVar()
# Checkbutton(master, text="male", variable=var1).grid(row=1, sticky=W)
# var2 = IntVar()
# Checkbutton(master, text="female", variable=var2).grid(row=2, sticky=W)
Label(master, text="Trace functions:").grid(row=tempRow, sticky="nesw")
tempRow = tempRow + 1
Button(master, text="Export Traces", command=export_traces).grid(
    row=tempRow, sticky="nesw", pady=4, padx=4
)
tempRow = tempRow + 1
Button(master, text="Import Traces", command=import_traces).grid(
    row=tempRow, sticky="nesw", pady=4, padx=4
)
tempRow = tempRow + 1

Label(master, text="Settings / Permission functions").grid(
    row=tempRow, sticky="nesw", padx=4
)
tempRow = tempRow + 1
Button(master, text="Export Permissions and Settings", command=export_settings).grid(
    row=tempRow, sticky="nesw", pady=4, padx=4
)
tempRow = tempRow + 1
Button(master, text="Import Permissions and Settings", command=import_settings).grid(
    row=tempRow, sticky="nesw", pady=4, padx=4
)
tempRow = tempRow + 1
if SHOW_DEV_TOOLS:
    Label(master, text="Other Stuff").grid(row=tempRow, sticky="nesw", padx=4)
    tempRow = tempRow + 1
    Button(master, text="Clear all Traces from DB", command=clear_paths).grid(
        row=tempRow, sticky="nesw", pady=4, padx=4
    )
    tempRow = tempRow + 1
    Button(master, text="Clear settings from DB", command=clear_settings).grid(
        row=tempRow, sticky="nesw", pady=4, padx=4
    )
    tempRow = tempRow + 1
    Button(
        master,
        text="Create Settings + Translations",
        command=create_settings_translations,
    ).grid(row=tempRow, sticky="nesw", pady=4, padx=4)
    tempRow = tempRow + 1
    Button(master, text="Create Mapfiles", command=create_mapfiles).grid(
        row=tempRow, sticky="nesw", pady=4, padx=4
    )
    tempRow = tempRow + 1
    Button(master, text="Fix Invalid paths", command=fix_maps).grid(
        row=tempRow, sticky="nesw", pady=4, padx=4
    )
    tempRow = tempRow + 1
mainloop()
