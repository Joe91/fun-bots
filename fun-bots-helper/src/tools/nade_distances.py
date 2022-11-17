import math

SPEED = 15
DROP = 9.8
HEIGHT = 1.6
TARGET_DISTANCE = 24.5


def distance(angle: float) -> float:
    return SPEED * SPEED * math.sin(2 * angle) / (2 * DROP) + SPEED * math.cos(
        angle
    ) / DROP * math.sqrt(
        SPEED * SPEED * math.sin(angle) * math.sin(angle) + 2 * DROP * HEIGHT
    )


out_table = {}
for i in range(430, 900):
    angle_rad = i / 10 * 2 * math.pi / 360
    current_distance = distance(angle_rad)
    if abs(current_distance - TARGET_DISTANCE) < 0.05:
        out_table[TARGET_DISTANCE] = angle_rad
        TARGET_DISTANCE = TARGET_DISTANCE - 0.5

first_line = True
with open("nade_distances.txt", "w", encoding="utf-8") as out_file:
    for key, value in out_table.items():
        start_of_line = "elseif"
        if first_line:
            first_line = False
            start_of_line = "if"
        out_file.write(
            start_of_line
            + " self._distanceToPlayer > "
            + str(key)
            + " then s_GrenadePitch = "
            + str(value)
            + "\n"
        )
    out_file.write("end")
