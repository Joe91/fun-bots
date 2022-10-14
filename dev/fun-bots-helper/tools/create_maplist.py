import sys

sys.path.insert(1, "../")
from addons.go_back_to_root import go_back_to_root
from addons.retrieves import retrieve_lines_maps


# Creating Maplist.txt
def createMaplist() -> None:
    go_back_to_root()
    outFile = "MapList.txt"

    # Lines
    mapItems = retrieve_lines_maps(create=True)
    with open(outFile, "w") as output:
        for item in mapItems:
            output.write(" ".join(item) + "\n")
        print("Write MapList.txt Done")


if __name__ == "__main__":
    createMaplist()
