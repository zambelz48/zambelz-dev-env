import ast
import json
import re
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

import ghapi
from catalog import vendored_version


class SourceError(Exception):
    pass


@dataclass(frozen=True)
class Bundled:
    name: str
    version: str
    cpe: tuple[str, ...] = ()
    osv: tuple[str, ...] = ()
    cna: tuple[dict, ...] = field(default=(), compare=False, hash=False)
    shipped_by: str = ""


def _raw(repo: str, path: str, tag: str) -> str:
    try:
        return ghapi.raw_file(repo, path, tag)
    except ghapi.GitHubError as error:
        raise SourceError(f"cannot fetch {repo} {path} at {tag}: {error}") from error


def normalized(version: str, regex: str | None) -> str:
    if not regex:
        return version

    match = re.match(regex, version)

    if match is None:
        raise SourceError(f"bundled version {version} does not match {regex}")

    return ".".join(str(int(group)) for group in match.groups())


def vendored(repo: str, tag: str, entries: list[dict]) -> list[Bundled]:
    found: list[Bundled] = []

    for entry in entries:
        version = vendored_version(_raw(repo, entry["path"], tag), entry["regex"])

        if version is None:
            raise SourceError(f"{repo}: cannot read {entry['name']} version from {entry['path']} at {tag}")

        found.append(Bundled(name=entry["name"], version=version, cpe=(entry["cpe"],), cna=tuple(entry.get("cna", []))))

    return found


def _downloads(text: str) -> dict:
    for node in ast.parse(text).body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "DOWNLOADS":
            return ast.literal_eval(node.value)

    raise SourceError("python-build-standalone downloads.py has no DOWNLOADS literal")


def pbs_release(repo_root: Path, python_version: str, url_regex: str) -> str:
    lock = tomllib.loads((repo_root / "mise/mise.lock").read_text())

    for entry in lock.get("tools", {}).get("python", []):
        if entry.get("version") != python_version:
            continue

        for key, value in entry.items():
            if key.startswith("platforms.") and isinstance(value, dict):
                match = re.search(url_regex, value.get("url", ""))

                if match:
                    return match.group(1)

    raise SourceError(f"mise/mise.lock has no python-build-standalone URL for python {python_version}")


def pbs(repo_root: Path, params: dict) -> list[Bundled]:
    tag = pbs_release(repo_root, params["version"], params["url_regex"])
    downloads = _downloads(_raw(params["repo"], params["path"], tag))
    found: list[Bundled] = []

    for ship in params["ships"]:
        entry = downloads.get(ship["key"])

        if entry is None or "version" not in entry:
            raise SourceError(f"python-build-standalone {tag} has no {ship['key']} in {params['path']}")

        found.append(
            Bundled(
                name=ship["key"],
                version=normalized(str(entry["version"]), ship.get("version_regex")),
                cpe=tuple(ship.get("cpe", [])),
                osv=tuple(ship.get("osv", [])),
                cna=tuple(ship.get("cna", [])),
                shipped_by=ship.get("shipped_by", ""),
            )
        )

    return found


def _json_path(text: str, dotted: str) -> str:
    value: object = json.loads(text)

    for key in dotted.split("."):
        value = value[key]

    return str(value)


def bundle(repo: str, tag: str, spec: dict) -> tuple[Bundled, str]:
    path, _, dotted = spec["version_from"].partition(":")

    try:
        version = _json_path(_raw(repo, path, tag), dotted)
    except (KeyError, ValueError) as error:
        raise SourceError(f"{repo}: cannot read {spec['name']} version from {path}:{dotted} at {tag}") from error

    inner_tag = spec.get("upstream_tag", "v{version}").format(version=version)
    found = Bundled(name=spec["name"], version=version, osv=tuple(spec.get("osv", [])))

    return found, inner_tag
