"""python -m funbots_debug.paths.fix_bases MAPFILE... [--write]

Finds the base-paths bots can't leave and relabels, relinks or removes them (see bases.py), and in rush links the paths
bots get stuck on, on the way to their MCOM (see routes.py). Without --write it only
reports what it would change.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .bases import Options, fix
from .mapfile import MapData


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="funbots_debug.paths.fix_bases", description=__doc__.split("\n\n")[1])
    parser.add_argument("files", nargs="+", type=Path, metavar="MAPFILE", help="mapfiles/<Level>_<Mode>.map")
    parser.add_argument("--write", action="store_true", help="write the changes into the files")
    parser.add_argument("--link-radius", type=float, default=Options.link_radius,
                        help="metres from a base-path to the way out it's linked to (default %(default)s)")
    parser.add_argument("--keep", action="store_true", help="don't remove base-paths without links, only report them")
    parser.add_argument("--verbose", "-v", action="store_true", help="list every change")
    args = parser.parse_args(argv)

    options = Options(link_radius=args.link_radius, remove=not args.keep)
    total: dict[str, int] = {}
    for file in args.files:
        data = MapData.load(file)
        result = fix(data, file.stem.rsplit("_", 1)[-1], options)
        counts = result.counts()
        for kind, count in counts.items():
            total[kind] = total.get(kind, 0) + count
        if not counts:
            continue
        print(f"{file.name}: " + ", ".join(f"{count} {kind}" for kind, count in sorted(counts.items())))
        for change in result.changes:
            if args.verbose or change.kind == "warning":
                where = f"path {change.path}" + (f":{change.point}" if change.point else "")
                target = f" -> {change.target[0]}:{change.target[1]}" if change.target else ""
                print(f"  {change.kind:12s} {where}{target}  {change.message}")
        if args.write and any(kind != "warning" for kind in counts):
            data.save(file)
    if len(args.files) > 1:
        print("total: " + (", ".join(f"{count} {kind}" for kind, count in sorted(total.items())) or "nothing to do"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
