import operator
from os import walk
from go_back_to_root import go_back_to_root


def createMaplist() -> None:
    # All GameModes
    # TDM, TDM CQ, Rush, CQ Small, CQ Large, Assault, Assault 2, Assault Large GM, CQ Dom, Scavanger, CTF
    GameModesToUse = [
        "TDM",
        "SDM",
        "TDM CQ",
        "Rush",
        "SQ Rush",
        "CQ Small",
        "CQ Large",
        "Assault",
        "Assault 2",
        "Assault Large",
        "GM",
        "CQ Dom",
        "Scavanger",
        "CTF",
        "Tank Superiority",
    ]
    RoundsToUse = "1"
    # AddComment = True # True or False
    MapsWithGunmaster = ["XP2", "XP4"]
    MapsWithoutTdmCq = ["XP2"]
    GameModeTranslations = {
        "TDM": "TeamDeathMatch0",
        "SDM": "SquadDeathMatch0",
        "TDM CQ": "TeamDeathMatchC0",
        "Rush": "RushLarge0",
        "SQ Rush": "SquadRush0",
        "CQ Small": "ConquestSmall0",
        "CQ Large": "ConquestLarge0",
        "Assault": "ConquestAssaultSmall0",
        "Assault 2": "ConquestAssaultSmall1",
        "Assault Large": "ConquestAssaultLarge0",
        "GM": "GunMaster0",
        "CQ Dom": "Domination0",
        "Scavanger": "Scavenger0",
        "CTF": "CaptureTheFlag0",
        "Tank Superiority": "TankSuperiority0",
    }

    outFile = "MapList.txt"

    mapItems = []

    # [] if no file
    filenames = next(walk("mapfiles"), (None, None, []))[2]
    for filename in filenames:
        combinedName = filename.split(".")[0]
        nameParts = combinedName.rsplit("_", 1)
        mapname = nameParts[0]
        translatedGamemode = nameParts[1]
        gameMode = ""
        for mode in GameModesToUse:
            if GameModeTranslations[mode] == translatedGamemode:
                gameMode = mode
                break
        # find special modes for TDM-Paths
        if gameMode in GameModesToUse:
            if gameMode == "TDM":
                if mapname.split("_")[0] in MapsWithGunmaster:
                    mapItems.append([mapname, "GunMaster0", RoundsToUse])
                if mapname.split("_")[0] not in MapsWithoutTdmCq:
                    mapItems.append([mapname, translatedGamemode, RoundsToUse])
                mapItems.append([mapname, "TeamDeathMatchC0", RoundsToUse])
            else:
                mapItems.append([mapname, translatedGamemode, RoundsToUse])

    # sort the list by gamemode
    mapItems = sorted(mapItems, key=operator.itemgetter(2, 1))

    with open(outFile, "w") as output:
        for item in mapItems:
            output.write(" ".join(item) + "\n")
        print("write done")


if __name__ == "__main__":
    go_back_to_root()
    createMaplist()
