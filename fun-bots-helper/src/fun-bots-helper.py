import os
import signal
import sys
import threading
from typing import Callable

import customtkinter
from loguru import logger
from tools.addons.gets import get_to_root, get_version
from tools.clear_all_paths import clear_all_paths
from tools.clear_settings import clear_settings
from tools.create_defaults import create_defaults
from tools.create_language import create_language
from tools.create_maplist import create_map_list
from tools.create_settings import create_settings
from tools.export_permission_and_config import export_permission_and_config
from tools.export_traces import export_traces
from tools.fix_link_and_vehicles import fix_link_and_vehicles
from tools.fix_nodes import fix_nodes
from tools.fix_objectives import fix_objectives
from tools.import_permission_and_config import import_permission_and_config
from tools.import_traces import import_traces
from tools.merge_two_mapfiles import merge_two_mapfiles
from tools.update_all_languages import update_languages
from tools.update_supported_maps import update_supported_maps

os.system("cls" if os.name == "nt" else "clear")


class App(customtkinter.CTk):
    def __init__(self):
        super().__init__()

        customtkinter.set_appearance_mode("dark")

        signal.signal(signal.SIGINT, self.signal_handler)

        self.geometry("900x500")
        self.title("Fun Bots Helper")
        self.minsize(700, 300)

        self.grid_rowconfigure(tuple(range(8)), weight=1)
        self.grid_columnconfigure(tuple(range(4)), weight=1)

        self.label_user_tools = customtkinter.CTkLabel(
            text="User Tools", text_font=("Terminal", 17)
        )
        self.label_user_tools.grid(row=0, column=0, sticky="ew", rowspan=2)

        self.label_traces = customtkinter.CTkLabel(
            master=self, text="Traces", text_font=("Terminal", 12)
        )
        self.label_traces.grid(row=2, column=0, sticky="ew")

        button_properties = {
            "master": self,
            "width": 160,
            "height": 40,
            "text_font": ("Terminal", 10),
        }

        self.button_import_traces = customtkinter.CTkButton(
            text="Import",
            command=lambda: self.create_thread(self.import_traces_fb),
            **button_properties,
        )
        self.button_import_traces.grid(row=3, column=0)

        self.button_export_traces = customtkinter.CTkButton(
            text="Export",
            command=lambda: self.create_thread(self.export_traces_fb),
            **button_properties,
        )
        self.button_export_traces.grid(row=4, column=0)

        self.label_settings = customtkinter.CTkLabel(
            text="Settings", text_font=("Terminal", 12)
        )
        self.label_settings.grid(row=5, column=0, sticky="ew")

        self.button_import_settings = customtkinter.CTkButton(
            text="Import",
            command=lambda: self.create_thread(self.import_permission_and_config_fb),
            **button_properties,
        )
        self.button_import_settings.grid(row=6, column=0)

        self.button_export_settings = customtkinter.CTkButton(
            text="Export",
            command=lambda: self.create_thread(self.export_permission_and_config_fb),
            **button_properties,
        )
        self.button_export_settings.grid(row=7, column=0, pady=(0, 20))

        self.label_dev_tools = customtkinter.CTkLabel(
            text="Dev Tools", text_font=("Terminal", 17)
        )
        self.label_dev_tools.grid(row=0, column=1, columnspan=4, rowspan=2, sticky="ew")

        self.label_mod_database = customtkinter.CTkLabel(
            text="Mod Database", text_font=("Terminal", 12)
        )
        self.label_mod_database.grid(row=2, column=1, sticky="ew")

        button_properties.update(
            {
                "fg_color": "#B744C9",
                "hover_color": "#742980",
            }
        )

        self.button_clear_traces = customtkinter.CTkButton(
            text="Clear Traces",
            command=lambda: self.create_thread(self.clear_all_paths_fb),
            **button_properties,
        )
        self.button_clear_traces.grid(row=3, column=1)

        self.button_clear_settings = customtkinter.CTkButton(
            text="Clear Settings",
            command=lambda: self.create_thread(self.clear_settings_fb),
            **button_properties,
        )
        self.button_clear_settings.grid(row=4, column=1)

        self.label_languages = customtkinter.CTkLabel(
            text="Languages", text_font=("Terminal", 12)
        )
        self.label_languages.grid(row=5, column=1, sticky="ew")

        self.language_code = customtkinter.CTkEntry(
            master=self,
            placeholder_text="Language Code",
            width=160,
            height=40,
            text_font=("Terminal", 10),
            corner_radius=10,
        )
        self.language_code.grid(row=6, column=1)

        self.button_create_language = customtkinter.CTkButton(
            text="Create Language",
            command=lambda: self.create_thread(self.create_language_fb),
            **button_properties,
        )
        self.button_create_language.grid(row=7, column=1, pady=(0, 20))

        self.label_maps = customtkinter.CTkLabel(
            text="Maps", text_font=("Terminal", 12)
        )
        self.label_maps.grid(row=2, column=2, sticky="ew")

        self.button_create_mapfiles = customtkinter.CTkButton(
            text="Create Mapfiles",
            command=lambda: self.create_thread(self.create_mapfiles_fb),
            **button_properties,
        )
        self.button_create_mapfiles.grid(row=3, column=2)

        self.button_fix_nodes = customtkinter.CTkButton(
            text="Fix Mapfiles",
            command=lambda: self.create_thread(self.fix_maps_fb),
            **button_properties,
        )
        self.button_fix_nodes.grid(row=4, column=2)

        get_to_root()
        self.values = os.listdir("mapfiles")
        combobox_properties = {
            "master": self,
            "values": self.values,
            "width": 160,
            "height": 40,
            "corner_radius": 10,
        }

        self.merge_file_1 = customtkinter.CTkComboBox(**combobox_properties)
        self.merge_file_1.grid(row=5, column=2)
        self.merge_file_1.set(self.values[0])

        self.merge_file_2 = customtkinter.CTkComboBox(**combobox_properties)
        self.merge_file_2.grid(row=6, column=2)
        self.merge_file_1.set(self.values[-1])

        self.button_merge_mapfiles = customtkinter.CTkButton(
            text="Merge Mapfiles",
            command=lambda: self.create_thread(self.merge_two_mapfiles_fb),
            **button_properties,
        )
        self.button_merge_mapfiles.grid(row=7, column=2, pady=(0, 20))

        self.label_docs_settings = customtkinter.CTkLabel(
            text="Settings", text_font=("Terminal", 12)
        )
        self.label_docs_settings.grid(row=2, column=3, sticky="ew")

        self.button_update_configs = customtkinter.CTkButton(
            text="Update Configs",
            command=lambda: self.create_thread(self.create_settings_defaults_fb),
            **button_properties,
        )
        self.button_update_configs.grid(row=3, column=3)

        self.button_update_languages = customtkinter.CTkButton(
            text="Update Languages",
            command=lambda: self.create_thread(self.update_languages_fb),
            **button_properties,
        )
        self.button_update_languages.grid(row=4, column=3)

        self.change_theme = customtkinter.CTkComboBox(
            master=self,
            values=["DARK", "LIGHT"],
            width=160,
            height=40,
            text_font=("Terminal", 10),
            command=self.change_appearance_mode,
            corner_radius=20,
            fg_color="#999900",
        )
        self.change_theme.grid(row=6, column=3)

        self.label_version = customtkinter.CTkLabel(
            master=self,
            text=get_version(),
            text_font=("Terminal", 10),
        )
        self.label_version.grid(row=7, column=3, pady=(0, 20))

    def export_traces_fb(self) -> None:
        export_traces()
        logger.info("Maps Exported\n")

    def import_traces_fb(self) -> None:
        import_traces()
        logger.info("Maps Imported\n")

    def export_permission_and_config_fb(self) -> None:
        export_permission_and_config()
        logger.info("Permissions and Configurations Exported\n")

    def import_permission_and_config_fb(self) -> None:
        import_permission_and_config()
        logger.info("Permissions and Configurations Imported\n")

    def clear_all_paths_fb(self) -> None:
        clear_all_paths()
        logger.info("Paths Cleared\n")

    def clear_settings_fb(self) -> None:
        clear_settings()
        logger.info("Settings Cleared\n")

    def create_settings_defaults_fb(self) -> None:
        create_settings()
        create_defaults()
        logger.info("Default and Settings Updated\n")

    def update_languages_fb(self) -> None:
        update_languages()
        logger.info("Languages Updated\n")

    def create_mapfiles_fb(self) -> None:
        update_supported_maps()
        create_map_list()
        logger.info("Mapfiles Updated\n")

    def fix_maps_fb(self) -> None:
        fix_objectives()
        fix_nodes()
        fix_link_and_vehicles()
        logger.info("All Maps Scanned and Fixed\n")

    def create_language_fb(self) -> None:
        lang = self.language_code.get()
        create_language(lang)

    def merge_two_mapfiles_fb(self) -> None:
        merge_file_1 = self.merge_file_1.get()
        merge_file_2 = self.merge_file_2.get()
        merge_two_mapfiles(merge_file_1, merge_file_2)

    def change_appearance_mode(self, new_appearance_mode: str) -> None:
        customtkinter.set_appearance_mode(new_appearance_mode)

    def create_thread(self, function: Callable) -> None:
        threading.Thread(target=function, daemon=True).start()

    def signal_handler(self, signal, frame):
        logger.warning("Crtl+C detected. Exiting Helper...")
        sys.exit(0)


app = App()
app.mainloop()
