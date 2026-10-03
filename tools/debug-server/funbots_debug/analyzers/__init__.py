"""Analyzers look at every snapshot and event and report findings (shown in the browser) and statistics.

Add one with a class derived from Analyzer and the @register decorator, either in this package (import it
below) or in any .py file of a directory passed with --plugins.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

from .base import Analyzer, Finding, create_analyzers, register

# The built-in analyzers register themselves on import.
from . import combat, raycasts, server_health, stuck, zones  # noqa: E402,F401

__all__ = ["Analyzer", "Finding", "register", "create_analyzers", "load_plugins"]


def load_plugins(directory: Path) -> list[str]:
    """Imports every .py file of the directory, so its analyzers register themselves."""
    loaded = []
    for path in sorted(directory.glob("*.py")):
        name = f"funbots_debug_plugin_{path.stem}"
        spec = importlib.util.spec_from_file_location(name, path)
        if spec is None or spec.loader is None:
            continue
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
        loaded.append(path.name)
    return loaded
