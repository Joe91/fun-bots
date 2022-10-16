import os
import sys

sys.path.insert(1, "../")
from addons.root import go_back_to_root, select_all_tables

# Creating permission_and_config folder files
def exportPermissionAndConfig() -> None:
    go_back_to_root()
    connection, cursor = select_all_tables()
    exportList = ["FB_Permissions", "FB_Config_Trace", "FB_Settings"]
    destFolder = "permission_and_config"

    if not os.path.exists(destFolder):
        os.makedirs(destFolder)
    for item in exportList:
        print("Export " + item)
        structure = cursor.execute("PRAGMA table_info('" + item + "')").fetchall()
        if len(structure) > 1:
            filename = item + ".cfg"
            with open(destFolder + "/" + filename, "w") as outfile:
                header = [collumn[1] for collumn in structure]
                outfile.write(";".join(header) + "\n")
                sql_instruction = (
                    "SELECT * FROM " + item + " ORDER BY " + structure[-3][1] + " ASC"
                )
                cursor.execute(sql_instruction)
                table_content = cursor.fetchall()
                for line in table_content:
                    outList = [format(item, ".6f") if type(item) is float else str(item) for item in line]
                    outfile.write(";".join(outList) + "\n")
    connection.close()


if __name__ == "__main__":
    exportPermissionAndConfig()
