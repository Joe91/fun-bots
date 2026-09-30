"""python -m funbots_debug.paths MAPFILE... [--server URL | --flags FILE] [--write]

Labels and links the paths of waypoint-files (see labeler.py). Without --write it only reports what it would change.
The objectives come from the capture points of a running debug-server (--server, the level has to match), from a
JSON-file with them (--flags: the "flags" of /api/state), or else from the paths that already carry one objective.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

from .labeler import Options, anchors_from_flags, anchors_from_labels, label, merge_anchors, uses_objectives
from .mapfile import MapData


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="funbots_debug.paths", description=__doc__.split("\n\n")[1])
    parser.add_argument("files", nargs="+", type=Path, metavar="MAPFILE", help="mapfiles/<Level>_<Mode>.map")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--server", metavar="URL", help="take the capture points from this debug-server "
                                                         "(e.g. http://127.0.0.1:8765)")
    source.add_argument("--flags", type=Path, metavar="FILE", help="take the capture points from this JSON-file")
    parser.add_argument("--write", action="store_true", help="write the changes into the files")
    parser.add_argument("--relabel", action="store_true", help="also recompute paths that already have objectives")
    parser.add_argument("--relink", action="store_true", help="drop all links between walkable paths, link anew")
    parser.add_argument("--crossings", action="store_true", help="also link paths where they cross")
    parser.add_argument("--vehicles", action="store_true", help="also link land vehicle paths and set their loop")
    parser.add_argument("--keep-loops", action="store_true", help="don't change loop / back and forth")
    parser.add_argument("--verbose", "-v", action="store_true", help="list every change")
    args = parser.parse_args(argv)

    flags, level = None, None
    if args.server:
        state = _fetch_state(args.server)
        flags = (state.get("objectives") or {}).get("flags") or []
        meta = state.get("meta") or {}
        level = f"{str(meta.get('level', '')).rsplit('/', 1)[-1]}_{meta.get('mode', '')}"
    elif args.flags:
        loaded = json.loads(args.flags.read_text(encoding="utf-8"))
        flags = loaded if isinstance(loaded, list) else (loaded.get("objectives") or loaded).get("flags", [])

    for file in args.files:
        if level is not None and file.stem != level and len(args.files) == 1:
            print(f"{file.name}: the debug-server runs {level}, not this level", file=sys.stderr)
            return 1
        if level is not None and file.stem != level:
            continue
        data = MapData.load(file)
        anchors = anchors_from_labels(data)
        if flags is not None:
            anchors = merge_anchors(anchors_from_flags(flags), anchors)
        options = Options(relabel=args.relabel, relink=args.relink, crossings=args.crossings, vehicles=args.vehicles,
                          loops=not args.keep_loops, objectives=uses_objectives(file.stem.rsplit("_", 1)[-1]))
        result = label(data, anchors, options)
        counts = result.counts()
        summary = ", ".join(f"{count} {kind}" for kind, count in sorted(counts.items())) or "nothing to do"
        print(f"{file.name}: {summary}")
        for change in result.changes:
            if args.verbose or change.kind == "warning":
                where = f"path {change.path}" + (f":{change.point}" if change.point else "")
                target = f" -> {change.target[0]}:{change.target[1]}" if change.target else ""
                print(f"  {change.kind:12s} {where}{target}  {change.message}")
        if args.write and any(kind != "warning" for kind in counts):
            data.save(file)
    return 0


def _fetch_state(url: str) -> dict:
    with urllib.request.urlopen(url.rstrip("/") + "/api/state", timeout=10) as response:
        return json.loads(response.read())


if __name__ == "__main__":
    sys.exit(main())
