"""Execute the inner function of tools/create_maplist.py to create a temporary MapList.txt 
file and compare it with the original MapList.txt already merged on dev branch. This test must 
be executed after any change in get_map_lines, by doing this we will ensure it is creating the 
same file."""


from addons.gets import get_map_lines, get_to_root


def test_create_maplist(tmp_path) -> None:
    """Key arguments.

    tmp_path: built-in pytest fixture to create Pathlib temporary files"""
    get_to_root()
    original_maplist_path = "MapList.txt"
    d = tmp_path / "sub"
    d.mkdir()
    temp_maplist_path = d / "temp_file.txt"

    mapItems = get_map_lines(create=True)
    with temp_maplist_path.open("w") as temp_maplist_file:
        for item in mapItems:
            temp_maplist_file.write(" ".join(item) + "\n")

    with temp_maplist_path.open("r") as temp_maplist_file:
        temp_maplist = temp_maplist_file.readlines()

    with open(original_maplist_path, "r") as outFile:
        original_maplist = outFile.readlines()

    assert sorted(temp_maplist) == sorted(original_maplist)
