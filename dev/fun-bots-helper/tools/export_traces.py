import os
import sys

sys.path.insert(1, "../")
from addons.root import go_back_to_root, select_all_tables


def exportTraces() -> None:
    go_back_to_root()
    connection, cursor = select_all_tables()
    content = cursor.fetchall()
    ignoreList = ["sqlite_sequence", "FB_Permissions", "FB_Config_Trace", "FB_Settings"]
    destFolder = "mapfiles"

    if not os.path.exists(destFolder):
        os.makedirs(destFolder)
    for item in content:
        if item[1] in ignoreList:
            continue

        print("Export " + item[1])
        structure = cursor.execute("PRAGMA table_info('" + item[1] + "')").fetchall()

        filename = item[1].replace("_table", "") + ".map"
        with open(destFolder + "/" + filename, "w") as outfile:
            idsToRemove = False
            header = [collumn[1] for collumn in structure]
            if header[0] == "id":
                header.pop(0)
                idsToRemove = True
            outfile.write(";".join(header) + "\n")
            sql_instruction = (
                "SELECT * FROM " + item[1] + " ORDER BY pathIndex, pointIndex ASC"
            )
            cursor.execute(sql_instruction)
            table_content = cursor.fetchall()
            for line in table_content:
                outList = [
                    format(item, ".6f") if type(item) is float else str(item)
                    for item in line
                ]
                if len(outList) > 1 and idsToRemove:
                    outList.pop(0)
                outfile.write(";".join(outList) + "\n")
    connection.close()


if __name__ == "__main__":
    exportTraces()
