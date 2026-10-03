"""Runs the census of levels through a running debug-server, and checks saved ones.

    python -m funbots_debug.census run --current                      # the level that runs now
    python -m funbots_debug.census run --map "MP_001 ConquestLarge0"  # switches the level over RCON first
    python -m funbots_debug.census run --maplist ../../MapList.txt    # every level of the list, one after the other
    python -m funbots_debug.census report census/XP3_Desert_ConquestLarge0.json.gz [--issues 40]
    python -m funbots_debug.census navzones census/*.json.gz        # walking networks of the zones (navzones.py)

The debug-server saves every census into its census-folder (--census, default tools/debug-server/census). Switching
levels needs the RCON-connection of the debug-server. Afterwards the map-list of the game-server is loaded again
from its MapList.txt (mapList.load).
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from ..paths.mapfile import MapData
from . import navzones
from .report import build_report
from .store import load

MAPFILES = Path(__file__).resolve().parents[4] / "mapfiles"
# Seconds to wait for a level to load, and for the waypoints after that.
LEVEL_TIMEOUT = 300.0
WAYPOINT_TIMEOUT = 120.0


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
        answer = self.request("/api/rcon", {"words": list(words)})
        if "error" in answer:
            raise RuntimeError(f"rcon {' '.join(words)}: {answer['error']}")
        return answer.get("words") or []


def _level_matches(meta: dict, level: str, mode: str) -> bool:
    return str(meta.get("level") or "").rsplit("/", 1)[-1].lower() == level.lower() and \
        str(meta.get("mode") or "").lower() == mode.lower()


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
        while time.monotonic() < deadline:
            time.sleep(2)
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

    switched = False
    failed = []
    for index, (level, mode) in enumerate(maps, start=1):
        print(f"[{index}/{len(maps)}] {level} {mode}")
        try:
            meta, _ = server.meta()
            if not _level_matches(meta, level, mode):
                switch_level(server, level, mode)
                switched = True
            if options.warmup > 0:
                # The bots play for a while, so the sizes of the capture zones get measured (zones.py).
                print(f"  bots play for {options.warmup:.0f} s first")
                time.sleep(options.warmup)
                zones = server.request("/api/census").get("zones") or []
                print(f"  capture zones measured: {sum(1 for zone in zones if zone.get('samples'))}/{len(zones)}")
            status = run_census(server, args, options.timeout)
            last = status["last"]
            print(f"  saved {last['file']}")
            report = status.get("report") or {}
            for kind, count in (report.get("issues") or {}).items():
                print(f"    {kind}: {count}")
        except RuntimeError as error:
            print(f"\n  {error}", file=sys.stderr)
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
        data = navzones.build(load(file))
        target = file.with_name(file.name.replace(".json.gz", ".navzones.json"))
        navzones.save(data, target)
        print(navzones.summary(data))
        print(f"  saved {target}")
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
    run.add_argument("--parts", help="entities,nodes,areas (default: all)")
    run.add_argument("--budget-ms", type=float, default=6.0, help="ms of raycasts per update of the server")
    run.add_argument("--area-step", type=float, help="cell-size of the grids around the objectives (default 0.5)")
    run.add_argument("--timeout", type=float, default=3600.0, help="seconds per level")
    run.add_argument("--warmup", type=float, default=0.0, metavar="SECONDS",
                     help="let the bots play this long before each census, to measure the capture zones")
    run.set_defaults(handler=command_run)

    report = commands.add_parser("report", help="check saved censuses")
    report.add_argument("files", nargs="+", type=Path)
    report.add_argument("--issues", type=int, default=0, metavar="N", help="also list the first N issues")
    report.add_argument("--mapfiles", type=Path, default=MAPFILES, help="waypoint-files to compare with")
    report.set_defaults(handler=command_report)

    zones = commands.add_parser("navzones", help="walking networks of the zones of saved censuses")
    zones.add_argument("files", nargs="+", type=Path)
    zones.set_defaults(handler=command_navzones)

    options = parser.parse_args()
    return options.handler(options)


if __name__ == "__main__":
    sys.exit(main())
