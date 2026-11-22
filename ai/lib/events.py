from dataclasses import dataclass, field
from pathlib import Path

from tools import ToolKind

BEFORE = "tool.before"
AFTER = "tool.after"


@dataclass(frozen=True)
class TextEdit:
    old: str
    new: str
    replace_all: bool


@dataclass(frozen=True)
class Event:
    kind: str
    agent: str
    tool: str
    tool_kind: ToolKind | None
    repo_root: Path
    command: str = ""
    path: Path | None = None
    content: str | None = None
    edits: tuple[TextEdit, ...] = ()
    patch: str = ""
    args: dict = field(default_factory=dict)


@dataclass(frozen=True)
class Decision:
    deny: str = ""
    warnings: tuple[str, ...] = ()


def no_objection() -> Decision:
    return Decision()


def deny(message: str) -> Decision:
    return Decision(deny=message)


def warn(*messages: str) -> Decision:
    return Decision(warnings=tuple(messages))


def combine(decisions: list[Decision]) -> Decision:
    denial = next((decision.deny for decision in decisions if decision.deny), "")
    warnings = tuple(message for decision in decisions for message in decision.warnings)

    return Decision(deny=denial, warnings=warnings)
