"""Test get_objectives_fixed function."""

from filecmp import cmp
from pathlib import Path

from src.tools.addons.gets import get_objectives_fixed, get_to_root


def test_fix_objectives(tmp_path: Path) -> None:
    """Test get_objectives_fixed function.

    Args:
        - tmp_path - built-in pytest fixture to create Pathlib temporary files

    Returns:
        None
    """
    get_to_root()
    d = tmp_path / "sub"
    d.mkdir()
    temp_objectives_before_path = d / "temp_file_before.map"
    temp_objectives_after_path = d / "temp_file_after.map"
    temp_objectives_fixed_path = d / "temp_file_fixed.map"

    with open(
        temp_objectives_fixed_path, "w", encoding="utf-8"
    ) as temp_objectives_fixed:
        temp_objectives_fixed.write(
            """pathIndex;pointIndex;transX;transY;transZ;inputVar;data
1;1;-124.363281;75.094536;-26.471680;65283;{"Objectives":["base ru"]}
2;1;-85.181641;74.974426;-50.961884;65283;{"Links":[[1,34]],"Objectives":["a","base us"],"LinkMode":0}
4;1;-84.271484;75.227371;-46.142578;65283;{"Links":[[1,35],[26,24]],"Objectives":["b","base ru spawn"],"LinkMode":0}
16;1;-31.112331;77.670776;4.110998;65283;{"Objectives":["c spawn"]}
11;1;-47.282227;74.035934;91.878906;65283;{"Links":[[7,23]],"Objectives":["d","base us"],"LinkMode":0}
"""
        )

    with open(
        temp_objectives_before_path, "w", encoding="utf-8"
    ) as temp_objectives_before:
        temp_objectives_before.write(
            """pathIndex;pointIndex;transX;transY;transZ;inputVar;data
1;1;-124.363281;75.094536;-26.471680;65283;{"Objectives":["BaSe RU"]}
2;1;-85.181641;74.974426;-50.961884;65283;{"Links":[[1,34]],"Objectives":["A","BaSE Us"],"LinkMode":0}
4;1;-84.271484;75.227371;-46.142578;65283;{"Links":[[1,35],[26,24]],"Objectives":["b","BASe rU spaWN"],"LinkMode":0}
16;1;-31.112331;77.670776;4.110998;65283;{"Objectives":["C Spawn"]}
11;1;-47.282227;74.035934;91.878906;65283;{"Links":[[7,23]],"Objectives":["D","BASE Us"],"LinkMode":0}
"""
        )

    with open(
        temp_objectives_before_path, "r", encoding="utf-8"
    ) as temp_objectives_before:
        objectives_to_rename, file_lines = get_objectives_fixed(temp_objectives_before)
        if len(objectives_to_rename) > 0:
            with open(
                temp_objectives_after_path, "w", encoding="utf-8"
            ) as temp_objectives_after:
                for line in file_lines:
                    for rename_item in objectives_to_rename:
                        line = line.replace(rename_item, rename_item.lower())
                    temp_objectives_after.write(line)

    assert cmp(f"{d}/temp_file_after.map", f"{d}/temp_file_fixed.map")
