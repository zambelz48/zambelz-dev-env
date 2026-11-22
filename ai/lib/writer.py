import hashlib
import json
import os
import stat
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

from report import Report

STATE_VERSION = 1


@dataclass(frozen=True)
class Output:
    content: bytes
    executable: bool = False


@dataclass(frozen=True)
class Plan:
    agent: str
    files: dict[str, Output]
    owned: tuple[str, ...]


def digest(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def json_bytes(data: object) -> bytes:
    return (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode()


def atomic_write(path: Path, content: bytes, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")

    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(content)

        mode = 0o644

        if executable:
            mode = 0o755

        os.chmod(temp, mode)
        os.replace(temp, path)
    except BaseException:
        Path(temp).unlink(missing_ok=True)
        raise


class State:
    def __init__(self, repo_root: Path):
        self.path = repo_root / "tmp" / "ai" / "state.json"
        self.agents: dict[str, dict[str, str]] = {}

        if self.path.is_file():
            data = json.loads(self.path.read_text())

            if data.get("version") == STATE_VERSION:
                self.agents = {name: dict(entry["files"]) for name, entry in data["agents"].items()}

    def recorded(self, agent: str) -> dict[str, str]:
        return self.agents.get(agent, {})

    def is_synced(self, agent: str) -> bool:
        return agent in self.agents

    def record(self, agent: str, files: dict[str, str]) -> None:
        self.agents[agent] = files

    def forget(self, agent: str) -> None:
        self.agents.pop(agent, None)

    def save(self) -> None:
        agents = {name: {"files": dict(sorted(files.items()))} for name, files in sorted(self.agents.items())}
        data = {"version": STATE_VERSION, "agents": agents}

        atomic_write(self.path, json_bytes(data))


class Workspace:
    def __init__(self, repo_root: Path, report: Report):
        self.root = repo_root
        self.report = report
        self.backup_dir = repo_root / "tmp" / "ai" / "backup" / f"{time.strftime('%Y%m%dT%H%M%S')}-{os.getpid()}"

    def backup(self, relpath: str) -> Path:
        target = self.backup_dir / relpath

        target.parent.mkdir(parents=True, exist_ok=True)
        os.replace(self.root / relpath, target)

        return target

    def files_under(self, owned: tuple[str, ...]) -> set[str]:
        found: set[str] = set()

        for entry in owned:
            path = self.root / entry

            if entry.endswith("/") and path.is_dir():
                found.update(str(item.relative_to(self.root)) for item in path.rglob("*") if item.is_file())
            elif not entry.endswith("/") and path.is_file():
                found.add(entry)

        return found

    def prune_empty_dirs(self, owned: tuple[str, ...]) -> None:
        for entry in owned:
            path = self.root / entry

            if not entry.endswith("/") or not path.is_dir():
                continue

            directories = sorted((item for item in path.rglob("*") if item.is_dir()), reverse=True)

            for directory in [*directories, path]:
                if not any(directory.iterdir()):
                    directory.rmdir()

    def remove(self, relpath: str, recorded_digest: str | None) -> None:
        path = self.root / relpath
        current = digest(path.read_bytes())

        if current == recorded_digest:
            path.unlink()
            self.report.changed(f"removed {relpath}")
            return

        target = self.backup(relpath)
        self.report.changed(f"removed {relpath} (changed by hand; kept a copy in {target})")


def _is_executable(path: Path) -> bool:
    return bool(path.stat().st_mode & stat.S_IXUSR)


def sync(workspace: Workspace, plan: Plan, state: State) -> None:
    report = workspace.report
    recorded = state.recorded(plan.agent)
    unchanged = 0

    for relpath, output in sorted(plan.files.items()):
        path = workspace.root / relpath

        if path.is_file():
            existing = path.read_bytes()

            if existing == output.content and _is_executable(path) == output.executable:
                unchanged += 1
                continue

            if recorded.get(relpath) != digest(existing):
                target = workspace.backup(relpath)
                report.changed(f"{relpath}: an existing file was moved to {target}")

        atomic_write(path, output.content, output.executable)
        report.changed(f"wrote {relpath}")

    stale = (workspace.files_under(plan.owned) | set(recorded)) - set(plan.files)

    for relpath in sorted(stale):
        path = workspace.root / relpath

        if not path.is_file():
            continue

        if relpath in recorded:
            workspace.remove(relpath, recorded[relpath])
        else:
            report.warn(
                f"{relpath} is not generated by ai/sync-ai.sh",
                f"move it into ai/ and run ai/sync-ai.sh {plan.agent}, or delete it",
            )

    workspace.prune_empty_dirs(plan.owned)
    state.record(plan.agent, {relpath: digest(output.content) for relpath, output in plan.files.items()})
    report.ok(f"{plan.agent}: {len(plan.files)} files, {unchanged} already up to date")


def check(workspace: Workspace, plan: Plan, state: State) -> bool:
    report = workspace.report
    fix = f"ai/sync-ai.sh {plan.agent}"

    if not state.is_synced(plan.agent):
        report.ok(f"{plan.agent}: not synced on this machine (skipped)")
        return True

    recorded = state.recorded(plan.agent)
    problems = 0

    for relpath, output in sorted(plan.files.items()):
        path = workspace.root / relpath

        if not path.is_file():
            report.error(f"{plan.agent}: {relpath} is missing", fix)
            problems += 1
        elif path.read_bytes() != output.content:
            report.error(f"{plan.agent}: {relpath} is out of date", fix)
            problems += 1

    stale = (workspace.files_under(plan.owned) | set(recorded)) - set(plan.files)

    for relpath in sorted(stale):
        if not (workspace.root / relpath).is_file():
            continue

        if relpath in recorded:
            report.error(f"{plan.agent}: {relpath} is stale", fix)
            problems += 1
        else:
            report.warn(f"{relpath} is not generated by ai/sync-ai.sh")

    if problems == 0:
        report.ok(f"{plan.agent}: {len(plan.files)} files up to date")

    return problems == 0


def clean(workspace: Workspace, agent: str, owned: tuple[str, ...], state: State) -> None:
    recorded = state.recorded(agent)

    for relpath in sorted(recorded):
        if (workspace.root / relpath).is_file():
            workspace.remove(relpath, recorded[relpath])

    workspace.prune_empty_dirs(owned)
    state.forget(agent)
    workspace.report.ok(f"{agent}: generated files removed")
