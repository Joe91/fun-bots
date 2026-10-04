"""Runs the census of levels through a running debug-server, and checks saved ones.

    python -m funbots_debug.census run --current                      # the level that runs now
    python -m funbots_debug.census run --map "MP_001 ConquestLarge0"  # switches the level over RCON first
    python -m funbots_debug.census run --maplist ../../MapList.txt    # every level of the list, one after the other
    python -m funbots_debug.census run --all --modes ConquestSmall0,ConquestLarge0,RushLarge0 --apply
                                                                     # every waypoint-file of these modes
    python -m funbots_debug.census report census/XP3_Desert_ConquestLarge0.json.gz [--issues 40]
    python -m funbots_debug.census navzones census/*.json.gz        # walking networks of the zones (navzones.py)
    python -m funbots_debug.census navpaths MP_012_RushLarge0 [--write] [--db ../../mod.db]
                                                                     # cut the paths at the zones (navpaths.py)
    python -m funbots_debug.census check MP_Subway_RushLarge0        # rays of the game over the mesh (check.py)

The debug-server saves every census into its census-folder (--census, default tools/debug-server/census). Switching
levels needs the RCON-connection of the debug-server. Afterwards the map-list of the game-server is loaded again
from its MapList.txt (mapList.load).

Per level: the bots measure the capture zones first (zone probe, ZoneProbe.lua: they are put around each capture
point), then the census runs with a larger raycast-budget (20 ms per update). Kicking the bots first (--kick-bots) is
only 5 % faster, and crashed the game-server on rush maps (the vehicles they leave behind?).
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from ..paths.mapfile import MapData
from . import check, navpaths, navzones
from .report import build_report
from .store import load

MAPFILES = Path(__file__).resolve().parents[4] / "mapfiles"
NAVZONES = MAPFILES.parent / "navzones"
CENSUS = Path(__file__).resolve().parents[2] / "census"
# Seconds to wait for a level to load, and for the waypoints after that.
LEVEL_TIMEOUT = 300.0
WAYPOINT_TIMEOUT = 120.0
# Seconds to wait for the objectives of a new level (the GameDirector sets them up), and for bots to probe with.
OBJECTIVES_TIMEOUT = 60.0
BOTS_TIMEOUT = 120.0
PROBE_BOTS = 4
# Seconds the zone probe may take.
PROBE_TIMEOUT = 300.0
# Seconds to wait for the zone networks the debug-server builds after a census.
NAVZONES_TIMEOUT = 180.0
# Seconds without the mod during a census: the game-server is gone.
DISCONNECT_TIMEOUT = 60.0


class Server:
    def __init__(self, url: str):
        self.url = url.rstrip("/")

    def request(self, path: str, data: dict | None = None, timeout: float = 30.0):
        body = None if data is None else json.dumps(data).encode()
        request = urllib.request.Request(self.url + path, data=body, method="GET" if data is None else "POST",
                                         headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            return json.loads(error.read() or b"{}") | {"httpStatus": error.code}

    def meta(self) -> tuple[dict, dict]:
        state = self.request("/api/state")
        return state.get("meta") or {}, state.get("status") or {}

    def rcon(self, *words: str) -> list[str]:
        # Once more after an error: the connection of the debug-server may still be the one to a crashed game-server.
        for attempt in range(2):
            answer = self.request("/api/rcon", {"words": list(words)})
            if "error" not in answer:
                return answer.get("words") or []
            if attempt == 0:
                time.sleep(2)
        raise RuntimeError(f"rcon {' '.join(words)}: {answer['error']}")


def _level_matches(meta: dict, level: str, mode: str) -> bool:
    # During a change of the mode on the same level, the game reports the new mode while the old one still runs. The
    # waypoints of the new one are only loaded with it.
    paths = meta.get("paths")
    return str(meta.get("level") or "").rsplit("/", 1)[-1].lower() == level.lower() and \
        str(meta.get("mode") or "").lower() == mode.lower() and \
        (paths is None or str(paths).lower() == f"{level}_{mode}".lower())


def switch_level(server: Server, level: str, mode: str) -> None:
    meta, _ = server.meta()
    if _level_matches(meta, level, mode):
        return
    print(f"  switching to {level} {mode}")
    server.rcon("mapList.clear")
    server.rcon("mapList.add", level, mode, "1")
    server.rcon("mapList.setNextMapIndex", "0")
    server.rcon("mapList.runNextRound")
    end = time.monotonic() + LEVEL_TIMEOUT
    while time.monotonic() < end:
        time.sleep(3)
        try:
            meta, status = server.meta()
        except OSError:
            continue
        if status.get("modConnected") and _level_matches(meta, level, mode):
            return
    raise RuntimeError(f"{level} {mode} didn't load within {LEVEL_TIMEOUT:.0f} s")


def wait_objectives(server: Server) -> int:
    """Waits until the debug-server knows the objectives of the level. Returns the number of capture points."""
    end = time.monotonic() + OBJECTIVES_TIMEOUT
    while True:
        objectives = server.request("/api/state").get("objectives") or {}
        flags = [flag for flag in objectives.get("flags") or [] if not flag.get("hq")]
        if flags or objectives.get("mcoms") or time.monotonic() > end:
            return len(flags)
        time.sleep(2)


def wait_command(server: Server, command: dict, timeout: float) -> dict:
    """Waits for the answer of the mod to a command of the debug-server."""
    command_id = command.get("id")
    if command_id is None:
        raise RuntimeError(f"command not sent: {command}")
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        entry = next((item for item in server.request("/api/commands") if item.get("id") == command_id), None)
        if entry and entry.get("status") not in ("queued", "sent"):
            return entry
        time.sleep(1)
    raise RuntimeError(f"no answer to {command.get('type')} within {timeout:.0f} s")


def probe_zones(server: Server) -> str:
    """Measures the capture zones with the bots (ZoneProbe.lua), once enough of them are alive and on foot (the mod can
    only put soldiers somewhere, not vehicles)."""
    end = time.monotonic() + BOTS_TIMEOUT
    while sum(1 for bot in server.request("/api/state").get("bots") or []
              if bot.get("alive") and not bot.get("vehicle")) < PROBE_BOTS:
        if time.monotonic() > end:
            return "no bots on foot"
        time.sleep(2)
    entry = wait_command(server, server.request("/api/command", {"type": "zone_probe", "args": {}}), PROBE_TIMEOUT)
    if entry.get("status") != "ok":
        return f"error: {entry.get('error')}"
    zones = server.request("/api/census").get("zones") or []
    active = [zone for zone in zones if zone.get("probed") and zone.get("active")]
    inactive = [zone["name"] for zone in zones if zone.get("probed") and not zone.get("active")]
    return f"{len(active)} zones" + (f", not active: {', '.join(inactive)}" if inactive else "")


def run_census(server: Server, args: dict, timeout: float) -> dict:
    """Starts the census and waits until the debug-server saved it. Retries while the waypoints are still loading."""
    end = time.monotonic() + WAYPOINT_TIMEOUT
    saves = int(server.request("/api/census").get("saves") or 0)
    while True:
        command = server.request("/api/census", args)
        command_id = command.get("id")
        if command_id is None:
            raise RuntimeError(f"census not started: {command}")
        # Wait for the answer of the mod.
        deadline = time.monotonic() + timeout
        connected_at = time.monotonic()
        while time.monotonic() < deadline:
            time.sleep(2)
            if server.meta()[1].get("modConnected"):
                connected_at = time.monotonic()
            elif time.monotonic() - connected_at > DISCONNECT_TIMEOUT:
                raise RuntimeError("the mod is gone (game-server crashed?)")
            entry = next((item for item in server.request("/api/commands") if item.get("id") == command_id), None)
            status = server.request("/api/census")
            current = status.get("current") or {}
            print(f"\r  {current.get('nodes', 0)} waypoints, {current.get('areas', 0)} areas, rows "
                  f"{current.get('areaRows', '-')}   ", end="", flush=True)
            if entry and entry.get("status") in ("ok", "error"):
                break
        else:
            raise RuntimeError(f"census not done within {timeout:.0f} s")
        print()
        if entry.get("status") == "ok":
            break
        if "still loading" in str(entry.get("error")) and time.monotonic() < end:
            time.sleep(5)
            continue
        raise RuntimeError(f"census failed: {entry.get('error')}")

    # The debug-server saves and checks it in the background.
    for _ in range(60):
        status = server.request("/api/census")
        if int(status.get("saves") or 0) > saves:
            return status
        time.sleep(1)
    raise RuntimeError("the debug-server didn't save the census")


def restart_server(server: Server, options) -> bool:
    """Starts the game-server with --restart-command if the mod isn't connected (any more). True once it is."""
    try:
        if server.meta()[1].get("modConnected"):
            return True
    except OSError:
        pass
    print(f"  starting the game-server: {options.restart_command}")
    subprocess.Popen(options.restart_command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    end = time.monotonic() + LEVEL_TIMEOUT
    while time.monotonic() < end:
        time.sleep(5)
        try:
            if server.meta()[1].get("modConnected"):
                time.sleep(20)  # The waypoints load after the level.
                return True
        except OSError:
            continue
    print("  the game-server didn't come back", file=sys.stderr)
    return False


def apply_navzones(server: Server, name: str) -> str:
    """Waits for the zone networks of the census (built by the debug-server) and sends them to the mod, which saves
    them into mod.db; the debug-server also writes navzones/<map>.json."""
    end = time.monotonic() + NAVZONES_TIMEOUT
    while time.monotonic() < end:
        # Only the networks of this census, not older ones of navzones/ the debug-server shows for the level.
        answer = server.request("/api/navzones/apply", {"save": True, "census": name}, timeout=120.0)
        result = answer.get("result") or {}
        if answer.get("status") == "ok":
            return f"{result.get('zones')} zones, {result.get('junctions')} junctions, {answer.get('file') or 'no file'}"
        if answer.get("status") == "error":
            return f"error: {answer.get('error')}"
        if answer.get("status") in ("queued", "sent"):
            return "no answer from the mod"
        time.sleep(3)
    return "not applied (no networks)"


def _maplist(file: Path) -> list[tuple[str, str]]:
    maps = []
    for line in file.read_text(encoding="utf-8").splitlines():
        words = line.split()
        if len(words) >= 2 and not line.lstrip().startswith("#"):
            maps.append((words[0], words[1]))
    return maps


def command_run(options) -> int:
    server = Server(options.server)
    maps: list[tuple[str, str]] = []
    if options.maplist:
        maps += _maplist(options.maplist)
    if options.all:
        modes = [mode for mode in (options.modes or "").split(",") if mode]
        for file in sorted(options.mapfiles.glob("*.map")):
            level, _, mode = file.stem.rpartition("_")
            if level and (not modes or mode in modes):
                maps.append((level, mode))
    for entry in options.map or []:
        level, mode = entry.split()
        maps.append((level, mode))
    if options.current or not maps:
        meta, status = server.meta()
        if not status.get("modConnected"):
            print("the mod isn't connected to the debug-server", file=sys.stderr)
            return 1
        maps.insert(0, (str(meta.get("level") or "").rsplit("/", 1)[-1], str(meta.get("mode") or "")))

    args: dict = {"budgetMs": options.budget_ms}
    if options.parts:
        args["parts"] = options.parts.split(",")
    if options.area_step:
        args["areaStep"] = options.area_step
    if options.area_layers:
        args["areaLayers"] = options.area_layers
    if options.detail_mesh:
        args["detailMesh"] = True

    switched = False
    failed = []
    retry: list[tuple[str, str]] = []
    queue = list(maps)
    index = 0
    while queue:
        level, mode = queue.pop(0)
        index += 1
        print(f"[{index}/{len(maps) + len(retry)}] {level} {mode}")
        try:
            meta, _ = server.meta()
            if not _level_matches(meta, level, mode):
                switch_level(server, level, mode)
                switched = True
            flags = wait_objectives(server)
            if options.warmup > 0:
                # The bots play for a while, so the sizes of the capture zones get measured (zones.py).
                print(f"  bots play for {options.warmup:.0f} s first")
                time.sleep(options.warmup)
            if flags and options.probe:
                print(f"  zone probe: {probe_zones(server)}")
            if flags or options.warmup > 0:
                zones = server.request("/api/census").get("zones") or []
                print(f"  capture zones measured: {sum(1 for zone in zones if zone.get('samples'))}/{len(zones)}")
            if options.kick_bots:
                server.rcon("funbots.kickAll")
            status = run_census(server, args, options.timeout)
            last = status["last"]
            print(f"  saved {last['file']}")
            report = status.get("report") or {}
            for kind, count in (report.get("issues") or {}).items():
                print(f"    {kind}: {count}")
            if options.apply:
                print(f"  networks: {apply_navzones(server, f'{level}_{mode}')}")
        except RuntimeError as error:
            print(f"\n  {error}", file=sys.stderr)
            # A crashed game-server: start it again and try this level once more.
            if options.restart_command and (level, mode) not in retry and restart_server(server, options):
                retry.append((level, mode))
                queue.insert(0, (level, mode))
                switched = True
                continue
            failed.append(f"{level} {mode}")

    if switched:
        server.rcon("mapList.load")
        print("map-list loaded again from the MapList.txt of the game-server")
    if failed:
        print(f"failed: {', '.join(failed)}", file=sys.stderr)
    return 1 if failed else 0


def compare_mapfile(census: dict, mapfiles: Path) -> str:
    """Whether the waypoints of the census (mod.db of the game-server) are the ones of the waypoint-file in git."""
    file = mapfiles / f"{census.get('paths')}.map"
    if not file.is_file():
        return f"{file.name} not found"
    data = MapData.load(file)
    nodes = census.get("nodes") or {}
    differing = []
    for path, entry in nodes.items():
        mapped = data.paths.get(int(path))
        if mapped is None or len(mapped.nodes) != len(entry["points"]) or any(
                math.dist(node.pos, pos) > 0.05 for node, pos in zip(mapped.nodes, entry["points"])):
            differing.append(int(path))
    missing = [path for path in data.paths if str(path) not in nodes]
    if not differing and not missing:
        return f"same as {file.name}"
    return (f"differs from {file.name}: {len(differing)} paths changed, {len(missing)} missing in the game "
            f"(e.g. {sorted(differing + missing)[:8]})")


def command_report(options) -> int:
    for file in options.files:
        census = load(file)
        report = build_report(census)
        print(report.text())
        print(f"  waypoint-file: {compare_mapfile(census, options.mapfiles)}")
        if options.issues:
            print("  first issues:")
            for issue in report.limited()[:options.issues]:
                print(f"    [{issue.severity}] {issue.kind}: {issue.message}")
    return 0


def command_navzones(options) -> int:
    for file in options.files:
        data = navzones.build(load(file), checks=check.load_checks(file))
        target = file.with_name(file.name.replace(".json.gz", ".navzones.json"))
        navzones.save(data, target)
        print(navzones.summary(data))
        print(f"  saved {target}")
    return 0


def command_check(options) -> int:
    """Rays of the game over the mesh of each level (check.py): switches to the level, casts them, saves
    census/<map>.checks.json. The mesh is left as it is: cut the level again (navpaths) to leave the findings out."""
    server = Server(options.server)
    failed = []
    for name in options.maps:
        name = Path(name).name.split(".")[0]
        level, _, mode = name.rpartition("_")
        zones_file = options.navzones / f"{name}.json"
        census_file = options.census / f"{name}.json.gz"
        if not zones_file.is_file():
            print(f"{name}: {zones_file} is missing", file=sys.stderr)
            failed.append(name)
            continue
        print(name, flush=True)
        try:
            switch_level(server, level, mode)
            networks = json.loads(zones_file.read_text(encoding="utf-8"))
            rays, meaning = check.rays(networks)
            hits: list[float] = []
            for start in range(0, len(rays), check.CHUNK):
                answer = server.request("/api/command?wait=120", {"type": "rays", "args": {
                    "rays": rays[start:start + check.CHUNK], "flags": check.RAY_FLAGS}}, timeout=130.0)
                result = answer.get("result") or {}
                if "hits" not in result:
                    raise RuntimeError(f"rays: {answer.get('error') or result.get('error') or answer}")
                hits += result["hits"]
            found = check.evaluate(networks, hits, meaning)
            print(check.summary(networks, found))
            merged = check.merge(check.load_checks(census_file), found)
            target = check.checks_file(census_file)
            target.write_text(json.dumps(merged, separators=(",", ":")), encoding="utf-8")
            print(f"  saved {target}")
        except (RuntimeError, OSError) as error:
            print(f"  {name} failed: {error}", file=sys.stderr)
            failed.append(name)
    return 1 if failed else 0


def command_navpaths(options) -> int:
    for name in options.maps:
        name = Path(name).name.split(".")[0]
        map_file = options.mapfiles / f"{name}.map"
        zones_file = options.navzones / f"{name}.json"
        census_file = options.census / f"{name}.json.gz"
        for file in (map_file, zones_file, census_file):
            if not file.is_file():
                print(f"{name}: {file} is missing", file=sys.stderr)
                return 1
        before = MapData.load(map_file)
        if any("Nav" in path.first.data for path in before.paths.values()):
            print(f"{name}: the paths are cut already (navigation paths in {map_file.name})", file=sys.stderr)
            return 1
        result = navpaths.build(before, json.loads(zones_file.read_text(encoding="utf-8")))
        print(name)
        print(navpaths.summary(result, before, options.verbose))
        if not options.write:
            continue
        # The networks again, with the junctions on the new paths.
        networks = navzones.build(load(census_file), attach=navpaths.attach_nodes(result.data),
                                  checks=check.load_checks(census_file))
        if networks.get("stats", {}).get("checkRemovedPoints") is not None:
            print(f"  check: {networks['stats']['checkRemovedEdges']} connections and "
                  f"{networks['stats']['checkRemovedPoints']} points left out")
        networks["map"] = name
        result.data.save(map_file)
        navzones.save(networks, zones_file)
        print(f"  written {map_file} and {zones_file} "
              f"({len(networks['attach'])} junctions)")
        for path, end in navpaths.missing_ends(result.data, networks):
            print(f"  warning: navigation path {path} has no junction at its {end}, the bots don't use it")
        if options.db:
            navpaths.write_db(options.db, name, result.data, networks)
            print(f"  written into {options.db}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(prog="python -m funbots_debug.census", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    run = commands.add_parser("run", help="census of levels through the debug-server")
    run.add_argument("--server", default="http://127.0.0.1:8765", help="address of the debug-server")
    run.add_argument("--current", action="store_true", help="the level that runs now (default without maps)")
    run.add_argument("--map", action="append", metavar='"LEVEL MODE"', help='e.g. "MP_001 ConquestLarge0"')
    run.add_argument("--maplist", type=Path, metavar="FILE", help="all levels of a map-list (LEVEL MODE ROUNDS)")
    run.add_argument("--all", action="store_true", help="every waypoint-file of mapfiles/ (see --modes)")
    run.add_argument("--modes", help="with --all: only these modes, e.g. ConquestSmall0,ConquestLarge0,RushLarge0")
    run.add_argument("--mapfiles", type=Path, default=MAPFILES, help="waypoint-files for --all")
    run.add_argument("--apply", action="store_true", help="send the zone networks to the mod and save them")
    run.add_argument("--restart-command", metavar="CMD",
                     help="shell-command that starts the game-server again after a crash (the level is tried again)")
    run.add_argument("--parts", help="entities,nodes,areas (default: all)")
    run.add_argument("--budget-ms", type=float, default=20.0,
                     help="ms of raycasts per update of the server (100k raycasts/s at most, from about 20 ms)")
    run.add_argument("--area-step", type=float, help="cell-size of the grids around the objectives (default 0.5)")
    run.add_argument("--area-layers", type=int, help="floors per cell of the grids (default 4)")
    run.add_argument("--detail-mesh", action="store_true",
                     help="the rays also hit the detail-meshes of the level (walls, ceilings, floors made of them)")
    run.add_argument("--timeout", type=float, default=3600.0, help="seconds per level")
    run.add_argument("--warmup", type=float, default=0.0, metavar="SECONDS",
                     help="let the bots play this long before each census (the zone probe measures the capture zones)")
    run.add_argument("--no-probe", dest="probe", action="store_false",
                     help="don't measure the capture zones with the zone probe")
    run.add_argument("--kick-bots", action="store_true",
                     help="kick the bots before the census (5 %% faster, but the game-server crashed on rush maps)")
    run.set_defaults(handler=command_run)

    report = commands.add_parser("report", help="check saved censuses")
    report.add_argument("files", nargs="+", type=Path)
    report.add_argument("--issues", type=int, default=0, metavar="N", help="also list the first N issues")
    report.add_argument("--mapfiles", type=Path, default=MAPFILES, help="waypoint-files to compare with")
    report.set_defaults(handler=command_report)

    zones = commands.add_parser("navzones", help="walking networks of the zones of saved censuses")
    zones.add_argument("files", nargs="+", type=Path)
    zones.set_defaults(handler=command_navzones)

    checks = commands.add_parser("check", help="rays of the game over the mesh: walls and ceilings the census missed")
    checks.add_argument("maps", nargs="+", help="<Level>_<Mode>, e.g. MP_Subway_RushLarge0")
    checks.add_argument("--server", default="http://127.0.0.1:8765", help="address of the debug-server")
    checks.add_argument("--navzones", type=Path, default=NAVZONES, help="the networks (navzones/<map>.json)")
    checks.add_argument("--census", type=Path, default=CENSUS, help="where the checks are saved (next to the census)")
    checks.set_defaults(handler=command_check)

    paths = commands.add_parser("navpaths", help="cut the paths at the zones: navigation paths from zone to zone")
    paths.add_argument("maps", nargs="+", help="<Level>_<Mode>, e.g. MP_012_RushLarge0")
    paths.add_argument("--mapfiles", type=Path, default=MAPFILES)
    paths.add_argument("--navzones", type=Path, default=NAVZONES, help="the networks (navzones/<map>.json)")
    paths.add_argument("--census", type=Path, default=CENSUS, help="the censuses the networks were made from")
    paths.add_argument("--write", action="store_true",
                       help="write the waypoint-file and the networks (with junctions on the new paths)")
    paths.add_argument("--db", type=Path, metavar="MOD_DB", help="with --write: also into the tables of this mod.db")
    paths.add_argument("-v", "--verbose", action="store_true", help="list the navigation paths")
    paths.set_defaults(handler=command_navpaths)

    options = parser.parse_args()
    return options.handler(options)


if __name__ == "__main__":
    sys.exit(main())
