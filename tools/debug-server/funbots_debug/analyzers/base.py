from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from ..state import WorldState

_REGISTRY: list[type["Analyzer"]] = []


def register(cls: type["Analyzer"]) -> type["Analyzer"]:
    """Class-decorator: the analyzer is created for every run of the server."""
    _REGISTRY.append(cls)
    return cls


def create_analyzers(disabled: set[str] | None = None) -> list["Analyzer"]:
    disabled = disabled or set()
    return [cls() for cls in _REGISTRY if cls.name not in disabled]


@dataclass
class Finding:
    """Something worth a look. key identifies it, so it is updated instead of added again."""

    key: str
    message: str
    severity: str = "warn"  # info | warn | error
    time: float = 0.0  # game-time
    bot: int | None = None  # id of the player (bot or real player)
    pos: list[float] | None = None
    analyzer: str = ""
    data: dict[str, Any] = field(default_factory=dict)

    def to_json(self) -> dict:
        return asdict(self)


class Analyzer:
    """Base-class. Override what you need, all callbacks run under the lock of the hub (keep them fast)."""

    name = "base"
    description = ""

    def __init__(self) -> None:
        self._findings: dict[str, Finding] = {}

    def reset(self) -> None:
        """New level. Called before the first snapshot of it."""
        self._findings.clear()

    def on_frame(self, frame: dict, state: "WorldState") -> None:
        """After the state took over a snapshot."""

    def on_event(self, event: dict, state: "WorldState") -> None:
        """After the state took over an event."""

    def stats(self) -> dict[str, Any]:
        """Numbers for the statistics-panel."""
        return {}

    # --- findings ----------------------------------------------------------------------------------------------

    def report(self, finding: Finding) -> None:
        finding.analyzer = self.name
        self._findings[finding.key] = finding

    def resolve(self, key: str) -> None:
        self._findings.pop(key, None)

    def findings(self) -> list[Finding]:
        return list(self._findings.values())
