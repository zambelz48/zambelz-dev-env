import hashlib
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

import events
from events import Decision, Event
from tools import ToolKind
from writer import atomic_write, json_bytes

WATCHED = (
    "mise/mise.toml",
    "mise/mise.lock",
    "tools/npm/package.json",
    "tools/npm/pnpm-lock.yaml",
    "tools/npm/pnpm-workspace.yaml",
    "tools/python/pyproject.toml",
    "tools/python/uv.lock",
)
AUDIT_TIMEOUT_SECONDS = 420
GATED_SUBCOMMANDS = ("commit", "push")
WRAPPERS = ("command", "exec", "env", "nohup", "time")
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=.*")
GIT_OPTIONS_WITH_VALUE = (
    "-C",
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--exec-path",
    "--config-env",
    "--super-prefix",
)
SEPARATORS = (";", "|", "&", "\n", "(", ")", "`")
DETAIL_LIMIT = 6000


@dataclass(frozen=True)
class Audit:
    code: int
    detail: str


class _Splitter:
    def __init__(self, command: str):
        self.command = command
        self.commands: list[list[str]] = [[]]
        self.word = ""
        self.has_word = False

    def _flush_word(self) -> None:
        if self.has_word:
            self.commands[-1].append(self.word)

        self.word = ""
        self.has_word = False

    def _end_command(self) -> None:
        self._flush_word()
        self.commands.append([])

    def _quoted(self, index: int, quote: str) -> int:
        index += 1

        while index < len(self.command) and self.command[index] != quote:
            if quote == '"' and self.command[index] == "\\" and index + 1 < len(self.command):
                index += 1

            self.word += self.command[index]
            index += 1

        self.has_word = True

        return index + 1

    def split(self) -> list[list[str]]:
        index = 0

        while index < len(self.command):
            char = self.command[index]
            following = self.command[index + 1 : index + 2]

            match char:
                case "'" | '"':
                    index = self._quoted(index, char)
                    continue
                case "\\" if following:
                    self.word += following
                    self.has_word = True
                    index += 2
                    continue
                case " " | "\t":
                    self._flush_word()
                case "$" if following == "(":
                    self._end_command()
                    index += 1
                case separator if separator in SEPARATORS:
                    self._end_command()
                case _:
                    self.word += char
                    self.has_word = True

            index += 1

        self._flush_word()

        return [words for words in self.commands if words]


def simple_commands(command: str) -> list[list[str]]:
    return _Splitter(command).split()


def git_subcommand(words: list[str]) -> str | None:
    index = 0

    while index < len(words) and (ASSIGNMENT.fullmatch(words[index]) or words[index] in WRAPPERS):
        index += 1

    if index >= len(words) or Path(words[index]).name != "git":
        return None

    index += 1

    while index < len(words):
        word = words[index]

        if word in GIT_OPTIONS_WITH_VALUE:
            index += 2
            continue

        if word.startswith("-"):
            index += 1
            continue

        return word

    return None


def is_gated(command: str) -> bool:
    return any(git_subcommand(words) in GATED_SUBCOMMANDS for words in simple_commands(command))


def _detail(output: str) -> str:
    keep = [
        line
        for line in output.splitlines()
        if line.startswith(("|", "+-", "Total ", "ERROR:", "  fix:", "WARN:"))
    ]
    text = "\n".join(keep) or output.strip()

    if len(text) > DETAIL_LIMIT:
        return text[:DETAIL_LIMIT] + "\n(truncated; run zconf audit --declared for the full report)"

    return text


def run_audit(repo_root: Path, gate: bool = False) -> Audit:
    zconf = repo_root / "zconf" / "bin" / "zconf"
    argv = [str(zconf), "audit", "--declared"]

    if gate:
        argv.append("--gate")

    try:
        run = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            timeout=AUDIT_TIMEOUT_SECONDS,
            cwd=repo_root,
        )
    except subprocess.TimeoutExpired:
        return Audit(code=3, detail=f"the scan did not finish within {AUDIT_TIMEOUT_SECONDS} seconds")
    except OSError as error:
        return Audit(code=3, detail=f"cannot run {zconf}: {error}")

    return Audit(code=run.returncode, detail=_detail(run.stdout + run.stderr))


def _gate(repo_root: Path) -> Decision | None:
    audit = run_audit(repo_root, gate=True)

    match audit.code:
        case 0:
            return None
        case 1:
            return events.deny(
                "Blocked: zconf audit --declared --gate reports findings that block, so commits and pushes are "
                "blocked: a fix is available (a newer release in the pinned line), the fix cannot be checked, or "
                "components are uncovered or left over. Follow each blocking finding's Action line (the fix-cve "
                "skill), then run the audit again. There is no bypass.\n\n" + audit.detail
            )
        case 3:
            return events.deny(
                "Blocked: zconf audit --declared could not run, so commits and pushes are blocked. "
                "Tell the user what failed; do not work around it.\n\n" + audit.detail
            )
        case other:
            return events.deny(
                f"Blocked: zconf audit --declared exited {other}, so commits and pushes are blocked. "
                "Tell the user what failed.\n\n" + audit.detail
            )


def _hashes(repo_root: Path) -> dict[str, str]:
    hashes: dict[str, str] = {}

    for relpath in WATCHED:
        path = repo_root / relpath

        if path.is_file():
            hashes[relpath] = hashlib.sha256(path.read_bytes()).hexdigest()

    return hashes


def _load_hashes(path: Path) -> dict[str, str] | None:
    if not path.is_file():
        return None

    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        return None

    if not isinstance(data, dict):
        return None

    return data.get("hashes")


def _after(repo_root: Path) -> Decision | None:
    state = repo_root / "tmp" / "ai" / "cve-guard.json"
    current = _hashes(repo_root)
    previous = _load_hashes(state)

    if previous == current:
        return None

    audit = run_audit(repo_root)
    changed = sorted(relpath for relpath in set(current) | set(previous or {}) if current.get(relpath) != (previous or {}).get(relpath))

    atomic_write(state, json_bytes({"hashes": current}))

    match audit.code:
        case 0 if previous is None:
            return None
        case 0:
            return events.warn(f"OK: zconf audit --declared reports no known vulnerabilities after changes to {', '.join(changed)}.")
        case 1:
            return events.warn(
                f"WARN: zconf audit --declared reports known vulnerabilities after changes to {', '.join(changed)}. "
                "Follow each finding's Action line now (the fix-cve skill); findings marked 'fix available' or "
                "'blocks push' keep commits and pushes blocked.\n\n" + audit.detail
            )
        case _:
            return events.warn("WARN: zconf audit --declared could not run after a dependency change.\n\n" + audit.detail)


def handle(event: Event) -> Decision | None:
    match event.kind:
        case events.BEFORE if event.tool_kind is ToolKind.SHELL and is_gated(event.command):
            return _gate(event.repo_root)
        case events.AFTER:
            return _after(event.repo_root)
        case _:
            return None
