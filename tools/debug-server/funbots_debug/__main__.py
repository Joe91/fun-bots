"""python -m funbots_debug [--port 8765] [--record DIR] [--replay FILE] [--plugins DIR]"""

from __future__ import annotations

import argparse
import threading
import webbrowser
from pathlib import Path

from . import __version__
from .analyzers import create_analyzers, load_plugins
from .hub import Hub
from .recorder import Recorder, replay
from .server import DebugServer


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
    parser.add_argument("--open", action="store_true", help="open the browser")
    parser.add_argument("--verbose", action="store_true", help="log every request")
    args = parser.parse_args()

    if args.plugins:
        print(f"plugins: {', '.join(load_plugins(args.plugins)) or 'none'}")
    analyzers = create_analyzers(set(args.disable))
    recorder = Recorder(args.record) if args.record else None
    hub = Hub(analyzers, recorder=recorder, accept_commands=args.replay is None)

    server = DebugServer((args.host, args.port), hub, quiet=not args.verbose)
    url = f"http://{'127.0.0.1' if args.host in ('0.0.0.0', '') else args.host}:{args.port}/"
    print(f"fun-bots debug-server {__version__} on {url}")
    print(f"analyzers: {', '.join(analyzer.name for analyzer in analyzers)}")

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


if __name__ == "__main__":
    main()
