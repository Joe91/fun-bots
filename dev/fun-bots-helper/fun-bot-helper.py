from tkinter import *
import os
master = Tk()

# use "auto-py-to-exe" to convert to exe files

relativePath = "."
if os.path.isfile("./mod.db"):
	relativePath = "./../"
elif os.path.isfile("./../mod.db"):
	relativePath = "./../../"

# TRACES
def export_traces():
	os.system("python ./tools/export_traces.py" + " " + relativePath)
	print("maps exported")

def import_traces():
	os.system("python ./tools/import_traces.py"+ " " + relativePath)
	print("maps imported")

# SETTINGS
def export_settings():
	os.system("python ./tools/export_permission_and_config.py"+ " " + relativePath)
	print("export")

def import_settings():
	os.system("python ./tools/import_permission_and_config.py"+ " " + relativePath)
	print("import")

# OTHER STUFF
def clear_paths():
	os.system("python ./tools/clear_all_paths.py"+ " " + relativePath)
	print("paths cleared")

def clear_settings():
	os.system("python ./tools/clear_settings.py"+ " " + relativePath)
	print("paths cleared")

def create_settings_translations():
	os.system("python ./tools/create_Settings.py"+ " " + relativePath)
	os.system("python ./tools/create_translations.py"+ " " + relativePath)
	print("translation-templates and settigns updated")

def create_mapfiles():
	os.system("python ./tools/create_maplist.py"+ " " + relativePath)
	os.system("python ./tools/update_supported_maps.py"+ " " + relativePath)

def fix_maps():
	#os.system("python ./tools/scan_for_invalid_objectives.py"+ " " + relativePath)
	os.system("python ./tools/scan_for_invalid_nodes.py"+ " " + relativePath)
# TODO: scan for invalid points in traces

tempRow = 0
master.columnconfigure(tuple(range(60)), weight=1)
master.rowconfigure(tuple(range(30)), weight=1)
# var1 = IntVar()
# Checkbutton(master, text="male", variable=var1).grid(row=1, sticky=W)
# var2 = IntVar()
# Checkbutton(master, text="female", variable=var2).grid(row=2, sticky=W)
Label(master, text="Trace functions:").grid(row=tempRow, sticky='nesw')
tempRow = tempRow +1
Button(master, text='Export Traces', command=export_traces).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1
Button(master, text='Import Traces', command=import_traces).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1

Label(master, text="Settings / Permission functions").grid(row=tempRow, sticky='nesw', padx=4)
tempRow = tempRow +1
Button(master, text='Export Permissions and Settings', command=export_settings).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1
Button(master, text='Import Permissions and Settings', command=import_settings).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1

Label(master, text="Other Stuff").grid(row=tempRow, sticky='nesw', padx=4)
tempRow = tempRow +1
Button(master, text='Clear all Traces from DB', command=clear_paths).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1
Button(master, text='Clear settings from DB', command=clear_settings).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1
Button(master, text='Create Settings + Translations', command=create_settings_translations).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1
Button(master, text='Create Mapfiles', command=create_mapfiles).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1
Button(master, text='Fix Invalid paths', command=fix_maps).grid(row=tempRow, sticky='nesw', pady=4, padx=4)
tempRow = tempRow +1
mainloop()