#     Copyright (C) 2021, Firjens <firjen@plontivion.com>
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU Affero General Public License as published
#     by the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU Affero General Public License for more details.
#
#     You should have received a copy of the GNU Affero General Public License
#     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import json
import sys
from datetime import datetime

workflow_configuration_structure = "./.funbots/workflow/conf_generator/config.json"  # URL to the configuration file skeleton
workflow_configuration_file = "./ext/shared/Config.lua"  # URL to the path to generate to

print("Generating the fun-bots configuration file...")

# Read and parse the JSON. Failure will not be tolerated and should cause the action to fail.
try:
    s_jsonFile = json.load(open(workflow_configuration_structure))
except:
    print("[ERROR] Failed to load or parse the JSON located at %s" % workflow_configuration_structure)
    sys.exit(1)

# Write the JSON to the target file in Lua
with open(workflow_configuration_file, "w") as outFile:
    outFile.write("-- This file was automatically generated on %s!\n" % datetime.today().strftime('%d-%m-%Y %H:%M:%S'))

    i = 0 # We use this variable to see how many values we've looped.

    # Loop through the initial objects

    for value in s_jsonFile:
        i += 1

        # If it's empty, don't generate it.
        if not value[0]:
            print("[WARN] Refused to generate %s. Empty variables are not generated!" % value)
            continue

        # Add the value
        outFile.write(value + " = {\n")

        # End the value
        outFile.write("}")

        # If there's another value after, add a space
        if len(s_jsonFile) > i:
          outFile.write("\n")

print("SUCCESS! Configuration file generated.")