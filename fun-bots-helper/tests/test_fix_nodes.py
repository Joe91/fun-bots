"""Test get_nodes_fixed function."""

from filecmp import cmp
from pathlib import Path

from src.tools.addons.gets import get_nodes_fixed, get_to_root


def test_fix_nodes(tmp_path: Path) -> None:
    """Test get_nodes_fixed function.

    Args:
        - tmp_path - built-in pytest fixture to create Pathlib temporary files

    Returns:
        None
    """
    get_to_root()
    d = tmp_path / "sub"
    d.mkdir()
    temp_nodes_before_path = d / "temp_file_before.map"
    temp_nodes_after_path = d / "temp_file_after.map"
    temp_nodes_fixed_path = d / "temp_file_fixed.map"

    with open(temp_nodes_fixed_path, "w", encoding="utf-8") as temp_nodes_fixed:
        temp_nodes_fixed.write(
            """pathIndex;pointIndex;transX;transY;transZ;inputVar;data
1;1;0;0;-925.737244;3;
1;2;0.000000;0.000000;-925.637244;3; # Z is wrong in the middle
1;3;0;0;-925.537244;3;
1;4;0.200000;0.000000;-925.337244;3; # X is wrong at the end
2;1;0;0;-925.237244;3;
2;2;0;0;-925.137244;3;
3;1;303.094723;0.000000;-924.737244;3; # X and Y are wrong at the start
3;2;302.894723;0;-924.937244;3;
3;3;302.694723;0;-925.137244;3;"""
        )
    with open(temp_nodes_before_path, "w", encoding="utf-8") as temp_nodes_before:
        temp_nodes_before.write(
            """pathIndex;pointIndex;transX;transY;transZ;inputVar;data
1;1;0;0;-925.737244;3;
1;2;0;0;137.295535;3; # Z is wrong in the middle
1;3;0;0;-925.537244;3;
1;4;120.610194;0;-925.437244;3; # X is wrong at the end
2;1;0;0;-925.237244;3;
2;2;0;0;-925.137244;3;
3;1;0;100;-925.037244;3; # X and Y are wrong at the start
3;2;302.894723;0;-924.937244;3;
3;3;302.694723;0;-925.137244;3;"""
        )
    with open(temp_nodes_before_path, "r", encoding="utf-8") as temp_nodes_before:
        out_file_lines = get_nodes_fixed(temp_nodes_before)
        with open(temp_nodes_after_path, "w", encoding="utf-8") as temp_nodes_after:
            for line in out_file_lines:
                temp_nodes_after.write(line)

    assert cmp(f"{d}/temp_file_after.map", f"{d}/temp_file_fixed.map")
