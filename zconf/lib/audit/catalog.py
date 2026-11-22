import re
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

from model import Component, Kind, Scope

GITHUB_URL = re.compile(r"^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+?)(?:\.git)?/?$")
KNOWN_KEYS = {
    "repo",
    "cpe",
    "cna",
    "osv",
    "upstream_tag",
    "upstream_files",
    "upstream_submodules",
    "upstream_deps",
    "vendored",
    "bundles",
    "bundled_from_lock_url",
    "installed",
    "feeds",
    "eol",
    "version_pattern",
    "shipped_by",
}
CATALOG_KINDS = {Kind.MISE_TOOL, Kind.MISE, Kind.NVIM_PLUGIN, Kind.OHMYZSH, Kind.NVIM_BUNDLED, Kind.OS_PACKAGE}
DISTRO_MANAGERS = ("dnf", "apt")


class CatalogError(Exception):
    pass


@dataclass(frozen=True)
class Source:
    kind: str
    params: dict = field(default_factory=dict, compare=False, hash=False)


def vendored_version(text: str, regex: str | list[str]) -> str | None:
    patterns = regex

    if isinstance(regex, str):
        patterns = [regex]

    parts: list[str] = []

    for pattern in patterns:
        match = re.search(pattern, text)

        if match is None:
            return None

        parts.extend(match.groups())

    return ".".join(parts)


def github_repo(url: str) -> str | None:
    match = GITHUB_URL.match(url)

    if match is None:
        return None

    return match.group(1)


class Catalog:
    def __init__(self, path: Path):
        self.path = path

        try:
            self.data: dict = tomllib.loads(path.read_text())
        except FileNotFoundError as error:
            raise CatalogError(f"the audit catalog {path} is missing") from error
        except tomllib.TOMLDecodeError as error:
            raise CatalogError(f"the audit catalog {path} is not valid TOML: {error}") from error

    def problems(self) -> list[str]:
        found: list[str] = []
        known_kinds = {str(kind) for kind in CATALOG_KINDS}

        for kind, section in self.data.items():
            if kind not in known_kinds:
                found.append(f"{self.path}: unknown section [{kind}]")
                continue

            for name, entry in section.items():
                unknown = sorted(set(entry) - KNOWN_KEYS)

                if unknown:
                    found.append(f"{self.path}: [{kind}.{name}] has unknown keys: {', '.join(unknown)}")

        return found

    def entry(self, kind: Kind, name: str) -> dict | None:
        section = self.data.get(str(kind), {})
        value = section.get(name)

        if value is None or not isinstance(value, dict):
            return None

        return value

    def repo(self, kind: Kind, name: str) -> str | None:
        entry = self.entry(kind, name)

        if entry is None:
            return None

        return entry.get("repo")

    def entry_for(self, component: Component) -> dict | None:
        match component.kind:
            case Kind.OS_PACKAGE:
                return self.entry(Kind.OS_PACKAGE, f"{component.locator.get('manager')}:{component.name}")
            case Kind.INSTALL:
                return self.entry(Kind.MISE_TOOL, component.name)
            case _:
                return self.entry(component.kind, component.name)

    def used_entries(self, components: list[Component]) -> set[tuple[str, str]]:
        used: set[tuple[str, str]] = set()

        for component in components:
            match component.kind:
                case Kind.OS_PACKAGE:
                    used.add((str(Kind.OS_PACKAGE), f"{component.locator.get('manager')}:{component.name}"))
                case Kind.INSTALL:
                    used.add((str(Kind.MISE_TOOL), component.name))
                case _:
                    used.add((str(component.kind), component.name))

        return used

    def unused(self, components: list[Component], managers: list[str]) -> list[str]:
        used = self.used_entries(components)
        listed = {
            (kind, name)
            for kind, section in self.data.items()
            for name in section
            if kind != str(Kind.OS_PACKAGE) or name.split(":")[0] in managers
        }

        return sorted(f"[{kind}.{name}]" for kind, name in listed - used)


def _version(entry: dict, version: str) -> str:
    pattern = entry.get("version_pattern")

    if not pattern:
        return version.removeprefix("v")

    match = re.match(pattern, version)

    if match is None:
        raise CatalogError(f"version {version} does not match version_pattern {pattern}")

    return match.group(1)


def _tag(entry: dict, version: str) -> str:
    return entry.get("upstream_tag", "v{version}").format(version=version)


def _repo_sources(repo: str | None, version: str, commit: bool) -> list[Source]:
    if not repo:
        return []

    key = "version"

    if commit:
        key = "commit"

    return [Source("github-advisories", {"repo": repo, key: version})]


def _entry_sources(entry: dict, component: Component) -> list[Source]:
    version = _version(entry, component.version)
    sources = _repo_sources(entry.get("repo"), version, False)
    tag = _tag(entry, version)

    for cpe in entry.get("cpe", []):
        sources.append(Source("nvd", {"cpe": cpe, "version": version}))

    for package in entry.get("osv", []):
        ecosystem, _, name = package.partition(":")
        sources.append(Source("osv-package", {"ecosystem": ecosystem, "name": name, "version": version}))

    if entry.get("upstream_files"):
        sources.append(Source("upstream-files", {"repo": entry["repo"], "tag": tag, "paths": entry["upstream_files"]}))

    if entry.get("upstream_submodules"):
        sources.append(Source("upstream-submodules", {"repo": entry["repo"], "tag": tag}))

    if entry.get("upstream_deps"):
        sources.append(Source("upstream-deps", {"repo": entry["repo"], "tag": tag, "path": entry["upstream_deps"]}))

    if entry.get("vendored"):
        sources.append(Source("upstream-vendored", {"repo": entry["repo"], "tag": tag, "entries": entry["vendored"]}))

    for bundle in entry.get("bundles", []):
        sources.append(Source("upstream-bundle", {"repo": entry["repo"], "tag": tag, "bundle": bundle}))

    if entry.get("bundled_from_lock_url"):
        sources.append(Source("pbs-bundled", {"version": component.version, **entry["bundled_from_lock_url"]}))

    for feed in entry.get("feeds", []):
        sources.append(Source("feed", {"name": feed, "version": version}))

    if entry.get("eol"):
        sources.append(Source("eol", {"product": entry["eol"], "version": version}))

    if entry.get("shipped_by"):
        sources.append(Source("shipped-by", {"vendor": entry["shipped_by"]}))

    return sources


def _installed_entry_sources(entry: dict | None, component: Component) -> list[Source]:
    path = component.locator.get("path", "")
    sources = [Source("osv-artifact", {"path": path})]

    for reader in (entry or {}).get("installed", []):
        params = {key: value for key, value in reader.items() if key != "reader"}

        if "path" in params:
            params["path"] = str(Path(path) / params["path"].format(version=component.version))

        sources.append(Source(f"reader-{reader['reader']}", {"install": path, "version": component.version, **params}))

    return sources


def sources_for(catalog: Catalog, component: Component) -> list[Source]:
    entry = catalog.entry_for(component)

    match component.kind, component.scope:
        case Kind.LOCKFILE, _:
            return [Source("osv-lockfile", {"path": component.locator["path"]})]
        case Kind.INSTALL, Scope.INSTALLED:
            return _installed_entry_sources(entry, component)
        case Kind.OS_PACKAGE, _ if component.locator.get("manager") in DISTRO_MANAGERS:
            return [Source("distro", {"manager": component.locator["manager"], "name": component.name, "version": component.version})]
        case Kind.TREESITTER_PARSER | Kind.TMUX_PLUGIN | Kind.SUBMODULE | Kind.NVIM_PLUGIN, Scope.INSTALLED:
            return [Source("osv-artifact", {"path": component.locator.get("path", "")})]
        case Kind.OHMYZSH, Scope.INSTALLED:
            return [Source("osv-artifact", {"path": component.locator.get("path", "")})]
        case Kind.TREESITTER_PARSER, _:
            repo = github_repo(component.locator.get("url", ""))
            return [*_repo_sources(repo, component.version, True), Source("osv-commit", {"commit": component.version})]
        case Kind.TMUX_PLUGIN, _:
            return [*_repo_sources(component.name, component.version, True), Source("osv-commit", {"commit": component.version})]
        case Kind.SUBMODULE, _:
            repo = github_repo(component.locator.get("url", ""))
            return [*_repo_sources(repo, component.version, True), Source("osv-commit", {"commit": component.version})]
        case Kind.NVIM_PLUGIN | Kind.OHMYZSH, _:
            repo = (entry or {}).get("repo")
            cpes = [Source("nvd-commit", {"cpe": cpe, "repo": repo, "commit": component.version}) for cpe in (entry or {}).get("cpe", [])]
            return [*_repo_sources(repo, component.version, True), Source("osv-commit", {"commit": component.version}), *cpes]
        case Kind.NVIM_BUNDLED, _:
            repo = component.locator.get("repo")
            own = _repo_sources(repo, component.version.removeprefix("v"), False)

            if entry is not None:
                own = [*own, *_entry_sources(entry, component)]

            return own
        case _ if entry is not None:
            return _entry_sources(entry, component)
        case _:
            return []
