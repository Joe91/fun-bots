"""python -m funbots_debug [--port 8765] [--record DIR] [--replay FILE] [--plugins DIR]"""

from __future__ import annotations

import argparse
import os
import threading
import webbrowser
from pathlib import Path

from . import __version__
from .analyzers import create_analyzers, load_plugins
from .hub import Hub
from .rcon import DEFAULT_PORT, RconClient, find_startup_password
from .recorder import Recorder, replay
from .server import DebugServer


# mapfiles/ of the repository this debug-server is part of (tools/debug-server/funbots_debug/__main__.py).
MAPFILES = Path(__file__).resolve().parents[3] / "mapfiles"
# Where the censuses of the levels are saved (tools/debug-server/census).
CENSUS = Path(__file__).resolve().parents[1] / "census"


def main() -> None:
    parser = argparse.ArgumentParser(prog="funbots_debug", description="Debug-server for fun-bots.")
    parser.add_argument("--host", default="127.0.0.1",
                        help="address to listen on (default: 127.0.0.1, use 0.0.0.0 if the game-server runs on "
                             "another machine - there is no authentication!)")
    parser.add_argument("--port", type=int, default=8765, help="port (default: 8765, see DEBUG_BRIDGE_URL)")
    parser.add_argument("--record", type=Path, metavar="DIR", help="record everything the mod sends into DIR")
    parser.add_argument("--replay", type=Path, metavar="FILE", help="play back a recording instead of a mod")
    parser.add_argument("--speed", type=float, default=1.0, help="speed of the replay (0 = as fast as possible)")
    parser.add_argument("--loop", action="store_true", help="repeat the replay")
    parser.add_argument("--plugins", type=Path, metavar="DIR", help="load additional analyzers from DIR/*.py")
    parser.add_argument("--disable", action="append", default=[], metavar="NAME", help="disable an analyzer")
    parser.add_argument("--rcon", default=f"127.0.0.1:{DEFAULT_PORT}", metavar="HOST:PORT",
                        help=f"RCON-port of the game-server for the console (default: 127.0.0.1:{DEFAULT_PORT})")
    parser.add_argument("--rcon-password", metavar="PASSWORD",
                        help="RCON-password (default: $FUNBOTS_RCON_PASSWORD, else admin.password of the Startup.txt "
                             "this folder lies in)")
    parser.add_argument("--no-rcon", action="store_true", help="no direct RCON-connection")
    parser.add_argument("--mapfiles", type=Path, metavar="DIR", default=MAPFILES,
                        help="waypoint-files the labeler writes into (default: mapfiles/ of this repository)")
    parser.add_argument("--census", type=Path, metavar="DIR", default=CENSUS,
                        help="folder for the censuses of the levels (default: tools/debug-server/census)")
    parser.add_argument("--navzones", type=Path, metavar="FILE",
                        help="show the walking networks of a census (.json.gz) or a .navzones.json on the map")
    parser.add_argument("--open", action="store_true", help="open the browser")
    parser.add_argument("--verbose", action="store_true", help="log every request")
    args = parser.parse_args()

    if args.plugins:
        print(f"plugins: {', '.join(load_plugins(args.plugins)) or 'none'}")
    analyzers = create_analyzers(set(args.disable))
    recorder = Recorder(args.record) if args.record else None
    hub = Hub(analyzers, recorder=recorder, accept_commands=args.replay is None, rcon=create_rcon(args),
              mapfiles=args.mapfiles if args.mapfiles and args.mapfiles.is_dir() else None, census=args.census)

    if args.navzones:
        print(f"zone networks: {hub.navzones_from(args.navzones)}")
    server = DebugServer((args.host, args.port), hub, quiet=not args.verbose)
    url = f"http://{'127.0.0.1' if args.host in ('0.0.0.0', '') else args.host}:{args.port}/"
    print(f"fun-bots debug-server {__version__} on {url}")
    print(f"analyzers: {', '.join(analyzer.name for analyzer in analyzers)}")

    if hub.rcon:
        print(f"rcon: {hub.rcon.address}, logging in...")
        threading.Thread(target=hub.check_rcon, name="rcon-check", daemon=True).start()
    else:
        print("rcon: off (no password: --rcon-password, $FUNBOTS_RCON_PASSWORD or admin.password in Startup.txt), "
              "the console sends RCON-commands through the mod (only the commands of the mods)")

    stop = threading.Event()
    if args.replay:
        print(f"replaying {args.replay} (speed {args.speed})")
        threading.Thread(target=replay, args=(args.replay, hub.ingest, args.speed, args.loop, stop),
                         name="replay", daemon=True).start()
    else:
        print("waiting for the mod: Registry.DEBUG.DEBUG_BRIDGE = true, or '!debugbridge on' / "
              "RCON 'funbots.debugBridge on'")
    if args.open:
        webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        server.server_close()
        if recorder is not None:
            recorder.close()
            if recorder.path:
                print(f"recorded to {recorder.path}")


def create_rcon(args: argparse.Namespace) -> RconClient | None:
    if args.no_rcon:
        return None
    password = args.rcon_password or os.environ.get("FUNBOTS_RCON_PASSWORD")
    if not password:
        found = find_startup_password(Path(__file__))
        if found is None:
            print("rcon: no Startup.txt with admin.password found above " + str(Path(__file__).resolve().parent))
            return None
        password, startup = found
        print(f"rcon: password from {startup}")
    host, _, port = args.rcon.partition(":")
    return RconClient(host or "127.0.0.1", int(port or DEFAULT_PORT), password)


if __name__ == "__main__":
    main()
