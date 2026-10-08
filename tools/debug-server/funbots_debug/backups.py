"""Copies of the data of a level before a step overwrites it: nothing recorded or edited gets lost.

Every step that writes the waypoint-file (mapfiles/<map>.map), the mesh (navzones/<map>.json), the census
(census/<map>.json.gz) or the tables of the level in mod.db copies what is there first:

    backups/<map>/<time>-<step>/   <map>.map, <map>.json, ...   the files as they were
                                   db.map, db.navzones.json      the tables <map>_table and <map>_navzones of mod.db

The newest KEEP of each level are kept. To go back: copy the file back (a db.map into mapfiles/ and import it).
"""

from __future__ import annotations

import shutil
import sqlite3
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
BACKUPS = REPO / "backups"
KEEP = 50
HEADER = "pathIndex;pointIndex;transX;transY;transZ;inputVar;data"


def _db_dump(db: Path, name: str, folder: Path) -> list[str]:
    """The tables of the level in mod.db into the folder. Returns the names of the files written."""
    written = []
    connection = sqlite3.connect(db, timeout=30.0)
    try:
        try:
            rows = connection.execute(f"SELECT pathIndex, pointIndex, transX, transY, transZ, inputVar, data FROM "
                                      f"{name}_table ORDER BY pathIndex, pointIndex ASC").fetchall()
        except sqlite3.Error:
            rows = None
        if rows is not None:
            lines = [HEADER]
            for row in rows:
                lines.append(";".join(format(value, ".6f") if isinstance(value, float)
                                      else str(value if value is not None else "") for value in row))
            (folder / "db.map").write_text("\n".join(lines) + "\n", encoding="utf-8")
            written.append("db.map")
        try:
            mesh = connection.execute(f"SELECT data FROM {name}_navzones").fetchone()
        except sqlite3.Error:
            mesh = None
        if mesh is not None and mesh[0]:
            (folder / "db.navzones.json").write_text(mesh[0], encoding="utf-8")
            written.append("db.navzones.json")
    finally:
        connection.close()
    return written


def backup(name: str, step: str, files: list[Path] = (), db: Path | None = None,
           root: Path | None = None) -> Path | None:
    """Copies the files (those that exist) and the tables of the level in db into a new folder of the backups of the
    level. Returns the folder, None if there was nothing to copy."""
    if root is None:
        # Only the data of this repository (not files somewhere else, e.g. of the tests).
        files = [file for file in files if Path(file).resolve().is_relative_to(REPO)]
        db = db if db is not None and Path(db).resolve().is_relative_to(REPO) else None
        root = BACKUPS
    files = [Path(file) for file in files if Path(file).is_file()]
    if not files and (db is None or not Path(db).is_file()):
        return None
    folder = root / name / f"{time.strftime('%Y%m%d-%H%M%S')}-{step}"
    suffix = 1
    while folder.exists():
        suffix += 1
        folder = root / name / f"{time.strftime('%Y%m%d-%H%M%S')}-{step}-{suffix}"
    folder.mkdir(parents=True)
    written = []
    for file in files:
        shutil.copy2(file, folder / file.name)
        written.append(file.name)
    if db is not None and Path(db).is_file():
        written += _db_dump(Path(db), name, folder)
    if not written:
        folder.rmdir()
        return None
    _prune(root / name)
    return folder


def _prune(level: Path) -> None:
    """Only the newest KEEP backups of the level."""
    folders = sorted(path for path in level.iterdir() if path.is_dir())
    for old in folders[:-KEEP]:
        shutil.rmtree(old, ignore_errors=True)
