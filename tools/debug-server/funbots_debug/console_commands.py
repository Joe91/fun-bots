"""The commands the console of the web UI knows: suggestions and the "help" list.

Frostbite-RCON can't list its commands, so the BF3- and VU-commands are written down here. The commands of
fun-bots are read from the source of the mod (Commands/Chat.lua, Commands/RCON.lua, Config.lua), so they stay
up to date by themselves.
"""

from __future__ import annotations

import re
from pathlib import Path

# ext/ of the mod: funbots_debug -> debug-server -> tools -> fun-bots
MOD_EXT = Path(__file__).resolve().parents[3] / "ext"

# BF3 server-protocol (R-20). login.*, logout and quit are left out, the debug-server manages the connection.
SUBSET = "<all | team <team> | squad <team> <squad> | player <name>>"
BF3_COMMANDS = [
    ("serverInfo", "", "Server name, players, game mode, map, rounds, scores, ..."),
    ("version", "", "Game and build of the server"),
    ("listPlayers", SUBSET, "Players with name, guid, team, squad, kills, deaths, score"),
    ("admin.eventsEnabled", "[true|false]", "Events of the server on this connection"),
    ("admin.effectiveMaxPlayers", "", "Current maximum number of players"),
    ("admin.say", f"<message> {SUBSET}", "Chat-message to the players"),
    ("admin.yell", f"<message> [seconds] [{SUBSET[1:-1]}]", "Big message in the middle of the screen"),
    ("admin.kickPlayer", "<name> [reason]", "Kicks a player"),
    ("admin.listPlayers", SUBSET, "Players, with more details than listPlayers"),
    ("admin.movePlayer", "<name> <team> <squad> <forceKill>", "Moves a player to another team/squad"),
    ("admin.killPlayer", "<name>", "Kills a player"),
    ("admin.password", "[password]", "RCON-password"),
    ("punkBuster.isActive", "", "Whether PunkBuster runs"),
    ("punkBuster.activate", "", "Starts PunkBuster"),
    ("punkBuster.pb_sv_command", "<command>", "PunkBuster server-command"),
    ("banList.load", "", "Loads the ban-list from the file"),
    ("banList.save", "", "Saves the ban-list to the file"),
    ("banList.add", "<name|ip|guid> <id> <perm | rounds <n> | seconds <n>> [reason]", "Bans a player"),
    ("banList.remove", "<name|ip|guid> <id>", "Removes a ban"),
    ("banList.clear", "", "Removes all bans"),
    ("banList.list", "[offset]", "Lists the bans"),
    ("reservedSlotsList.load", "", "Loads the reserved slots from the file"),
    ("reservedSlotsList.save", "", "Saves the reserved slots to the file"),
    ("reservedSlotsList.add", "<name>", "Reserves a slot for a player"),
    ("reservedSlotsList.remove", "<name>", "Removes a reserved slot"),
    ("reservedSlotsList.clear", "", "Removes all reserved slots"),
    ("reservedSlotsList.list", "[offset]", "Lists the reserved slots"),
    ("reservedSlotsList.aggressiveJoin", "[true|false]", "Players with a reserved slot kick others to join"),
    ("mapList.load", "", "Loads the map-list from the file"),
    ("mapList.save", "", "Saves the map-list to the file"),
    ("mapList.add", "<map> <gamemode> <rounds> [index]", "Adds a map, e.g. MP_001 ConquestLarge0 2"),
    ("mapList.remove", "<index>", "Removes a map"),
    ("mapList.clear", "", "Removes all maps"),
    ("mapList.list", "[offset]", "Lists the maps"),
    ("mapList.setNextMapIndex", "<index>", "Map to play next"),
    ("mapList.getMapIndices", "", "Index of the current and the next map"),
    ("mapList.getRounds", "", "Current round and rounds of this map"),
    ("mapList.runNextRound", "", "Switches to the next round/map now"),
    ("mapList.restartRound", "", "Restarts the current round"),
    ("mapList.endRound", "<winning team>", "Ends the round with a winner"),
]
BF3_VARS = [
    ("ranked", "Ranked server (only at startup)"), ("serverName", "Name of the server"),
    ("gamePassword", "Password to join"), ("autoBalance", "Balances the teams"),
    ("roundStartPlayerCount", "Players needed to start a round"),
    ("roundRestartPlayerCount", "Players below which the round restarts"),
    ("roundLockdownCountdown", "Seconds of the pre-round"), ("serverMessage", "Welcome message"),
    ("friendlyFire", "Friendly fire"), ("maxPlayers", "Maximum number of players"),
    ("serverDescription", "Description in the server browser"), ("killCam", "Kill-cam"), ("miniMap", "Mini-map"),
    ("hud", "HUD"), ("crossHair", "Cross-hair"), ("3dSpotting", "3D-spotting"),
    ("miniMapSpotting", "Spotting on the mini-map"), ("nameTag", "Name tags"), ("3pCam", "3rd-person vehicle cam"),
    ("regenerateHealth", "Health regeneration"), ("teamKillCountForKick", "Team-kills until kick"),
    ("teamKillValueForKick", "Team-kill value until kick"), ("teamKillValueIncrease", "Value per team-kill"),
    ("teamKillValueDecreasePerSecond", "Decrease of the team-kill value"),
    ("teamKillKickForBan", "Team-kill kicks until ban"), ("idleTimeout", "Seconds until idle players are kicked"),
    ("idleBanRounds", "Rounds an idle-kicked player is banned"), ("vehicleSpawnAllowed", "Vehicles spawn"),
    ("vehicleSpawnDelay", "Vehicle respawn time in %"), ("soldierHealth", "Soldier health in %"),
    ("playerRespawnTime", "Player respawn time in %"), ("playerManDownTime", "Man-down time in %"),
    ("bulletDamage", "Bullet damage in %"), ("gameModeCounter", "Tickets in %"),
    ("onlySquadLeaderSpawn", "Only spawn on the squad leader"), ("unlockMode", "Unlocks: all|common|stats|none"),
    ("premiumStatus", "Premium server"), ("bannerUrl", "Banner in the server browser"),
    ("gunMasterWeaponsPreset", "Weapon preset of gun master"),
]
# https://docs.veniceunleashed.net/hosting/commands/
VU_COMMANDS = [
    ("modList.Add", "<mod>", "Adds a mod to load on the next server restart"),
    ("modList.Available", "", "Mods that can be added"),
    ("modList.Clear", "", "Clears the mods to load on the next server restart"),
    ("modList.Debug", "[true|false]", "Debug mode of the extensions"),
    ("modList.List", "", "Mods to load on the next restart"),
    ("modList.ListRunning", "", "Mods loaded right now"),
    ("modList.ReloadExtensions", "", "Reloads all loaded mods (also fun-bots)"),
    ("modList.Remove", "<mod>", "Removes a mod to load on the next server restart"),
    ("vu.ColorCorrectionEnabled", "[true|false]", "Blue-tint filter"),
    ("vu.CorpseDamageEnabled", "[true|false]", "Damage to corpses"),
    ("vu.DesertingAllowed", "[true|false]", "Players may leave the combat area"),
    ("vu.DestructionEnabled", "[true|false]", "Destruction"),
    ("vu.DisablePreRound", "[true|false]", "No pre-round on the next level"),
    ("vu.FadeInAll", "", "Fades all screens in from black"),
    ("vu.FadeOutAll", "", "Fades all screens to black"),
    ("vu.Fps", "", "Current server FPS"),
    ("vu.FpsMa", "", "Server FPS, 30 s moving average"),
    ("vu.FrequencyMode", "", "Frequency mode of the server"),
    ("vu.FriendlyFireSuppression", "[true|false]", "Suppression by friendly fire"),
    ("vu.HighPerformanceReplication", "[true|false]", "Same update rate for all players"),
    ("vu.HttpAssetUrl", "[url]", "External asset hosting"),
    ("vu.ServerBanner", "[url]", "Banner image of the server"),
    ("vu.SetTeamTicketCount", "<team> <tickets>", "Tickets of a team"),
    ("vu.SpectatorCount", "", "Connected spectators"),
    ("vu.SquadSize", "[size]", "Maximum players per squad"),
    ("vu.SunFlareEnabled", "[true|false]", "Sun flare"),
    ("vu.SuppressionMultiplier", "[factor]", "Suppression multiplier"),
    ("vu.TeamActivatedMines", "[true|false]", "Mines triggered by the own team"),
    ("vu.TimeScale", "[0.0-2.0]", "Game speed"),
    ("vu.VehicleDisablingEnabled", "[true|false]", "Vehicles get disabled"),
]


def _entry(group: str, name: str, args: str = "", help_text: str = "") -> dict:
    return {"group": group, "name": name, "args": args, "help": help_text}


def parse_chat_commands(chat_lua: Path) -> list[dict]:
    """The "!command" branches of ChatCommands:Execute, with the arguments they read and their permission."""
    source = chat_lua.read_text(encoding="utf-8", errors="replace")
    branches = re.split(r"\n\s*(?:else)?if p_Parts\[1\] == '(![^']+)' then", source)
    entries = []
    for name, body in zip(branches[1::2], branches[2::2]):
        body = re.split(r"\n\t(?:else|end)\b", body)[0]
        usage = re.search(r"'Usage: (![^']+)'", body)
        permission = re.search(r"_HasPermission\(p_Player, '([^']+)'\)", body)
        help_text = f"permission {permission.group(1)}" if permission else ""
        if usage:
            args = usage.group(1)[len(name):].strip()
        else:
            found: dict[int, str] = {}
            for line in body.splitlines():
                read = re.search(r"p_Parts\[(\d)\](.*)", line)
                if read is None:
                    continue
                index, rest = int(read.group(1)), read.group(2)
                named = re.search(r"(?:local s_|Config\.)(\w+) = ", line)
                label = named.group(1) if named else "0|1" if "== 0" in rest else f"arg{index}"
                optional = " or " in rest
                if index not in found or "arg" in found[index]:
                    found[index] = f"[{label}]" if optional else f"<{label}>"
            args = " ".join(found[index] for index in sorted(found))
        entries.append(_entry("fun-bots chat", name, args, help_text))
    return entries


def parse_rcon_commands(rcon_lua: Path, config_lua: Path | None) -> list[dict]:
    """funbots.* of RCONCommands, and funbots.config.<Setting> for every setting of Config.lua."""
    entries = [_entry("fun-bots", "funbots", "", "Lists the funbots-commands")]
    comment = ""
    parameters_pending: dict | None = None
    for line in rcon_lua.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("--"):
            # A comment of several lines describes the next command.
            text = stripped.lstrip("- ").rstrip(".")
            comment = f"{comment}. {text}" if comment else text
            continue
        if match := re.match(r"Name = '([^']+)'", stripped):
            parameters_pending = _entry("fun-bots", match.group(1), "", comment)
            entries.append(parameters_pending)
        elif parameters_pending and (match := re.match(r"Parameters = \{(.*)\}", stripped)):
            parameters_pending["args"] = " ".join(f"<{name}>" for name in re.findall(r"'([^']+)'", match.group(1)))
            parameters_pending = None
        if stripped and not re.match(r"\w+ = \{$", stripped):  # "KICK_ALL = {" is between comment and Name
            comment = ""
    if config_lua and config_lua.is_file():
        for match in re.finditer(r"^\t(\w+) = [^\n]*?,\s*(?:--\s*([^\n]*))?$", config_lua.read_text(encoding="utf-8"),
                                 re.MULTILINE):
            entries.append(_entry("fun-bots settings", f"funbots.config.{match.group(1)}", "[value]",
                                  (match.group(2) or "").strip()))
    return entries


def catalog(ext: Path = MOD_EXT) -> dict[str, list[dict]]:
    """{"chat": [...], "rcon": [...]}, each entry {group, name, args, help}."""
    rcon = [_entry("BF3", *command) for command in BF3_COMMANDS]
    rcon += [_entry("BF3", f"vars.{name}", "[value]", help_text) for name, help_text in BF3_VARS]
    rcon += [_entry("VU", *command) for command in VU_COMMANDS]
    chat: list[dict] = []
    if (ext / "Server/Commands/RCON.lua").is_file():
        rcon += parse_rcon_commands(ext / "Server/Commands/RCON.lua", ext / "Shared/Config.lua")
    if (ext / "Server/Commands/Chat.lua").is_file():
        chat = parse_chat_commands(ext / "Server/Commands/Chat.lua")
    return {"chat": chat, "rcon": rcon}
