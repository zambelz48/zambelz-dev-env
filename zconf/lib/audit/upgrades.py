import importlib
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

import ghapi
from cpe import version_key
from model import Component, Kind

LIB = Path(__file__).resolve().parents[1]
MISE_REPO = "jdx/mise"
PARALLEL = 8
TOOL_KINDS = (Kind.MISE_TOOL, Kind.INSTALL)
CHILD_KINDS = (Kind.BUNDLED, Kind.UPSTREAM_PIN)


def _versions_module():
    if str(LIB) not in sys.path:
        sys.path.append(str(LIB))

    return importlib.import_module("versions")


@dataclass(frozen=True)
class Newest:
    tool: str
    pinned: str
    in_line: str | None
    any_line: str | None


def _newer(candidate: str | None, pinned: str) -> bool:
    return bool(candidate) and candidate != pinned and version_key(candidate) > version_key(pinned)


def _lookup(job: tuple[str, str, list[str]]) -> Newest:
    tool, version, pins = job
    versions = _versions_module()
    in_line = next((query for pinned, query in versions.queries(tool, pins, False) if pinned == version), tool)
    any_line = next((query for pinned, query in versions.queries(tool, [version], True)), tool)

    return Newest(tool, version, versions.latest(in_line), versions.latest(any_line))


def _mise_itself(version: str) -> Newest:
    try:
        tag = ghapi.json_get(f"repos/{MISE_REPO}/releases/latest").get("tag_name", "")
    except ghapi.GitHubError:
        return Newest("mise", version, None, None)

    newest = tag.removeprefix("v") or None

    return Newest("mise", version, newest, newest)


def newest_versions(tools_and_versions: set[tuple[str, str]], config: Path) -> dict[tuple[str, str], Newest]:
    versions = _versions_module()
    tools = versions.load_tools(config)
    jobs: list[tuple[str, str, list[str]]] = []
    answers: dict[tuple[str, str], Newest] = {}

    for name, version in sorted(tools_and_versions):
        match name:
            case "mise":
                answers[(name, version)] = _mise_itself(version)
            case _ if name.startswith("http:"):
                continue
            case _:
                pins = versions.versions_of(tools.get(name)) or [version]
                jobs.append((name, version, pins))

    with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
        for newest in pool.map(_lookup, jobs):
            answers[(newest.tool, newest.pinned)] = newest

    return answers


def parent_of(component: Component) -> tuple[str, str] | None:
    match component.kind:
        case Kind.MISE:
            return ("mise", component.version)
        case kind if kind in TOOL_KINDS:
            return (component.name, component.version)
        case kind if kind in CHILD_KINDS and component.locator.get("root_tool"):
            return (component.locator["root_tool"], component.locator["root_version"])
        case kind if kind in CHILD_KINDS:
            return None
        case _:
            return None


def available(newest: Newest) -> str | None:
    if _newer(newest.in_line, newest.pinned):
        return newest.in_line

    return None


def action(newest: Newest) -> str:
    target = available(newest)

    if target is not None:
        return f"upgrade {newest.tool} {newest.pinned} -> {target} (zconf upgrade {newest.tool}), then run the audit again"

    message = f"none possible yet; {newest.tool} {newest.pinned} is the newest release in its pinned line"

    if _newer(newest.any_line, newest.pinned) and newest.any_line != newest.in_line:
        message += f" (a newer line exists: {newest.any_line}, not taken without zconf upgrade --major)"

    return message
