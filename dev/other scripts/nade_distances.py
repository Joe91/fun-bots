import math

Speed = 15
Drop = 9.8
Height = 1.6


def Distance(angle: float) -> float:
    return Speed * Speed * math.sin(2 * angle) / (2 * Drop) + Speed * math.cos(
        angle
    ) / Drop * math.sqrt(
        Speed * Speed * math.sin(angle) * math.sin(angle) + 2 * Drop * Height
    )


targetDistance = 24.5
outTable = {}
for i in range(430, 900):
    angleRad = i / 10 * 2 * math.pi / 360
    currentDistance = Distance(angleRad)
    if abs(currentDistance - targetDistance) < 0.05:
        outTable[targetDistance] = angleRad
        targetDistance = targetDistance - 0.5
        print(str(i / 10) + " " + str(Distance(angleRad)))

print(outTable)
FirtstLine = True
with open("temp.txt", "w") as outfile:
    for key, value in outTable.items():
        startOfLine = "elseif"
        if FirtstLine:
            FirtstLine = False
            startOfLine = "if"
        outfile.write(
            startOfLine
            + " self._DistanceToPlayer > "
            + str(key)
            + " then s_GrenadePitch = "
            + str(value)
            + "\n"
        )
    outfile.write("end")
