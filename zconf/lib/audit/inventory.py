import json
import os
import re
import tomllib
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

import procs
from model import Component, Kind, Problem, Scope

RawFetcher = Callable[[str, str, str], str]
RepoLookup = Callable[[Kind, str], str | None]

LOCKFILES = ("tools/npm/pnpm-lock.yaml", "tools/python/uv.lock")
PARSERS_PATH = "lua/nvim-treesitter/parsers.lua"
DEPS_PATH = "cmake.deps/deps.txt"
QUOTED = re.compile(r"""['"]([A-Za-z0-9_]+)['"]""")
PARSER_BLOCK = re.compile(r"^  (\w+) = \{(.*?)^  \},", re.MULTILINE | re.DOTALL)
REVISION = re.compile(r"""revision = ['"]([^'"]+)['"]""")
URL = re.compile(r"""url = ['"]([^'"]+)['"]""")
DEPS_LINE = re.compile(r"^([A-Z0-9_]+)_URL\s+(\S+)$", re.MULTILINE)
GITHUB_ARCHIVE = re.compile(r"https://github\.com/([^/]+/[^/]+)/archive/(.+)\.tar\.gz$")
GITHUB_RELEASE = re.compile(r"https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/")
TARBALL = re.compile(r"/([A-Za-z][A-Za-z0-9_]*?)-(\d[^/]*?)\.tar\.gz$")
NOT_IN_RELEASE_BUILD = {
    "WIN32YANK_X86_64": "a Windows-only clipboard tool",
    "LUA": "USE_BUNDLED_LUA is OFF; the release uses LuaJIT",
    "GETTEXT": "bundled only for MSVC (Windows) builds",
    "LIBICONV": "bundled only for MSVC (Windows) builds",
    "WASMTIME": "ENABLE_WASMTIME is OFF and the release workflow does not enable it",
    "UNCRUSTIFY": "a source formatter used by `make format`, not part of the build",
}


@dataclass
class Inventory:
    components: list[Component] = field(default_factory=list)
    leftovers: list[Problem] = field(default_factory=list)
    information: list[Problem] = field(default_factory=list)


@dataclass(frozen=True)
class Paths:
    repo: Path
    home: Path
    mise_data: Path


def _declared(kind: Kind, name: str, version: str, origin: str, **locator: object) -> Component:
    return Component(kind=kind, name=name, version=version, origin=origin, scope=Scope.DECLARED, locator=locator)


def _installed(kind: Kind, name: str, version: str, origin: str, **locator: object) -> Component:
    return Component(kind=kind, name=name, version=version, origin=origin, scope=Scope.INSTALLED, locator=locator)


def mise_tools(repo: Path) -> list[Component]:
    lock = tomllib.loads((repo / "mise/mise.lock").read_text())
    seen: set[tuple[str, str]] = set()
    components: list[Component] = []

    for tool, entries in lock.get("tools", {}).items():
        for entry in entries:
            version = entry["version"]

            if (tool, version) in seen:
                continue

            seen.add((tool, version))
            backend = entry.get("backend", tool)
            components.append(_declared(Kind.MISE_TOOL, tool, version, "mise/mise.lock", backend=backend))

    return components


def mise_itself(repo: Path) -> list[Component]:
    config = tomllib.loads((repo / "mise/mise.toml").read_text())
    version = config.get("min_version")

    if not version:
        return []

    return [_declared(Kind.MISE, "mise", version, "mise/mise.toml")]


def lockfiles(repo: Path) -> list[Component]:
    return [
        _declared(Kind.LOCKFILE, relpath, "-", relpath, path=str(repo / relpath))
        for relpath in LOCKFILES
        if (repo / relpath).is_file()
    ]


def nvim_plugins(repo: Path) -> list[Component]:
    lock = json.loads((repo / "neovim/lazy-lock.json").read_text())

    return [
        _declared(Kind.NVIM_PLUGIN, name, entry["commit"], "neovim/lazy-lock.json", branch=entry.get("branch", ""))
        for name, entry in sorted(lock.items())
    ]


def parser_table(text: str) -> dict[str, tuple[str, str] | None]:
    table: dict[str, tuple[str, str] | None] = {}

    for match in PARSER_BLOCK.finditer(text):
        body = match.group(2)
        revision = REVISION.search(body)
        url = URL.search(body)

        if "install_info" not in body:
            table[match.group(1)] = None
        elif revision and url:
            table[match.group(1)] = (url.group(1), revision.group(1))

    return table


def _parsers_text(repo: Path, home: Path, commit: str, fetch: RawFetcher, lookup: RepoLookup) -> str:
    local = home / ".local/share/nvim/lazy/nvim-treesitter"

    if (local / ".git").exists():
        done = procs.run(["git", "-C", str(local), "show", f"{commit}:{PARSERS_PATH}"])

        if done.code == 0:
            return done.stdout

    source = lookup(Kind.NVIM_PLUGIN, "nvim-treesitter")

    if source is None:
        raise LookupError("nvim-treesitter has no repository in the audit catalog")

    return fetch(source, PARSERS_PATH, commit)


def treesitter_parsers(
    repo: Path, home: Path, fetch: RawFetcher, lookup: RepoLookup
) -> tuple[list[Component], list[Problem]]:
    listed = QUOTED.findall((repo / "neovim/lua/treesitter_parsers.lua").read_text())
    commit = json.loads((repo / "neovim/lazy-lock.json").read_text())["nvim-treesitter"]["commit"]
    table = parser_table(_parsers_text(repo, home, commit, fetch, lookup))
    components: list[Component] = []
    information: list[Problem] = []

    for name in listed:
        if name not in table:
            raise LookupError(f"parser '{name}' is not in nvim-treesitter {commit[:12]} {PARSERS_PATH}")

        entry = table[name]

        if entry is None:
            information.append(
                Problem(None, "inventory", f"tree-sitter '{name}' is query files only, shipped inside nvim-treesitter")
            )
            continue

        url, revision = entry
        components.append(
            _declared(Kind.TREESITTER_PARSER, name, revision, "neovim/lua/treesitter_parsers.lua", url=url)
        )

    return components, information


def tmux_plugins(repo: Path) -> list[Component]:
    components: list[Component] = []

    for line in (repo / "tmux/zconf/pins").read_text().splitlines():
        if not line.strip():
            continue

        name, commit = line.split("\t")
        components.append(_declared(Kind.TMUX_PLUGIN, name, commit, "tmux/zconf/pins", repo=name))

    return components


def ohmyzsh(repo: Path) -> list[Component]:
    values = dict(
        line.split("=", 1) for line in (repo / "zsh/zconf/pins").read_text().splitlines() if "=" in line
    )
    url = values["OHMYZSH_URL"]

    return [_declared(Kind.OHMYZSH, "oh-my-zsh", values["OHMYZSH_COMMIT"], "zsh/zconf/pins", url=url)]


def submodules(repo: Path) -> list[Component]:
    gitmodules = repo / ".gitmodules"

    if not gitmodules.is_file():
        return []

    config = procs.checked(["git", "config", "--file", str(gitmodules), "--get-regexp", r"^submodule\..*\.(path|url)$"])
    entries: dict[str, dict[str, str]] = {}

    for line in config.splitlines():
        key, value = line.split(" ", 1)
        name, attribute = key[len("submodule.") :].rsplit(".", 1)
        entries.setdefault(name, {})[attribute] = value

    components: list[Component] = []

    for name, entry in sorted(entries.items()):
        tree = procs.checked(["git", "-C", str(repo), "ls-tree", "HEAD", entry["path"]]).split()

        if len(tree) < 3 or tree[1] != "commit":
            raise LookupError(f"submodule {entry['path']} has no recorded commit at HEAD")

        components.append(_declared(Kind.SUBMODULE, entry["path"], tree[2], ".gitmodules", url=entry["url"]))

    return components


def _bundled_version(name: str, url: str) -> tuple[str, dict[str, str]]:
    archive = GITHUB_ARCHIVE.match(url)

    if archive and archive.group(1) != "neovim/deps":
        return archive.group(2), {"repo": archive.group(1), "url": url}

    release = GITHUB_RELEASE.match(url)

    if release:
        return release.group(2), {"repo": release.group(1), "url": url}

    tarball = TARBALL.search(url)

    if tarball:
        return tarball.group(2), {"project": tarball.group(1), "url": url}

    raise LookupError(f"cannot read a version from Neovim's bundled dependency {name}: {url}")


def nvim_bundled(repo: Path, fetch: RawFetcher, lookup: RepoLookup) -> tuple[list[Component], list[Problem]]:
    nvim = [component for component in mise_tools(repo) if component.name == "neovim"]

    if not nvim:
        return [], []

    tag = f"v{nvim[0].version}"
    source = lookup(Kind.MISE_TOOL, "neovim")

    if source is None:
        raise LookupError("neovim has no repository in the audit catalog")

    text = fetch(source, DEPS_PATH, tag)
    components: list[Component] = []
    information: list[Problem] = []

    for name, url in DEPS_LINE.findall(text):
        reason = NOT_IN_RELEASE_BUILD.get(name)

        if reason is not None:
            information.append(
                Problem(None, "inventory", f"Neovim {tag} lists {name.lower()} in {DEPS_PATH} but its release build does not ship it: {reason}")
            )
            continue

        version, locator = _bundled_version(name, url)
        components.append(_declared(Kind.NVIM_BUNDLED, name.lower(), version, f"neovim {tag} {DEPS_PATH}", **locator))

    return components, information


def declared(paths: Paths, fetch: RawFetcher, lookup: RepoLookup) -> Inventory:
    repo = paths.repo
    bundled, bundled_information = nvim_bundled(repo, fetch, lookup)
    parsers, parser_information = treesitter_parsers(repo, paths.home, fetch, lookup)
    components = [
        *mise_tools(repo),
        *mise_itself(repo),
        *lockfiles(repo),
        *nvim_plugins(repo),
        *parsers,
        *tmux_plugins(repo),
        *ohmyzsh(repo),
        *submodules(repo),
        *bundled,
    ]

    return Inventory(components=components, information=[*parser_information, *bundled_information])


def _mise_json(args: list[str], home: Path) -> dict:
    text = procs.checked(["mise", *args, "--json"], cwd=home)

    return json.loads(text or "{}")


def _git_head(path: Path) -> str | None:
    done = procs.run(["git", "-C", str(path), "rev-parse", "HEAD"])

    if done.code != 0:
        return None

    return done.stdout.strip()


def mise_installs(paths: Paths, pinned: set[tuple[str, str]]) -> Inventory:
    listing = _mise_json(["ls", "--installed"], paths.home)
    prunable = {
        entry["install_path"]
        for entries in _mise_json(["ls", "--prunable"], paths.home).values()
        for entry in entries
    }
    inventory = Inventory()

    for tool, entries in sorted(listing.items()):
        for entry in entries:
            install_path = entry["install_path"]
            component = _installed(Kind.INSTALL, tool, entry["version"], install_path, path=install_path)
            inventory.components.append(component)

            if (tool, entry["version"]) in pinned:
                continue

            if install_path in prunable:
                inventory.leftovers.append(
                    Problem(component, "inventory", "installed but nothing selects it", "mise prune")
                )
            else:
                inventory.information.append(
                    Problem(component, "inventory", "not pinned by this repository; kept by another tracked mise config")
                )

    return inventory


def stray_tracked_configs(paths: Paths) -> list[Problem]:
    tracked = paths.home / ".local/state/mise/tracked-configs"
    installs = (paths.mise_data / "installs").resolve()
    by_install: dict[str, list[Path]] = {}

    if not tracked.is_dir():
        return []

    for entry in sorted(tracked.iterdir()):
        target = Path(os.path.realpath(entry))

        if target.exists() and target.is_relative_to(installs):
            install = "/".join(target.relative_to(installs).parts[:2])
            by_install.setdefault(install, []).append(entry)

    return [
        Problem(
            None,
            "inventory",
            f"mise tracks {len(entries)} files inside the {install} install as configs; they keep tool versions installed",
            f"remove the tracked-config entries in {tracked} that resolve inside {installs / install}",
        )
        for install, entries in sorted(by_install.items())
    ]


def repo_installs(paths: Paths) -> list[Component]:
    candidates = (
        ("tools/npm", paths.repo / "tools/npm/node_modules"),
        ("tools/python", paths.repo / "tools/python/.venv"),
        (
            "gradle-language-server",
            paths.repo / "neovim/.lsp_vendors/vscode-gradle/gradle-language-server/build/install",
        ),
    )

    return [
        _installed(Kind.INSTALL, name, "-", str(path), path=str(path))
        for name, path in candidates
        if path.is_dir()
    ]


def installed_git(paths: Paths) -> list[Component]:
    components: list[Component] = []
    lazy = paths.home / ".local/share/nvim/lazy"
    tmux = paths.home / ".tmux/plugins"

    for root, kind in ((lazy, Kind.NVIM_PLUGIN), (tmux, Kind.TMUX_PLUGIN)):
        if not root.is_dir():
            continue

        for path in sorted(root.iterdir()):
            head = _git_head(path)

            if head:
                components.append(_installed(kind, path.name, head, str(path), path=str(path)))

    ohmyzsh_dir = paths.home / ".oh-my-zsh"
    head = _git_head(ohmyzsh_dir)

    if head:
        components.append(_installed(Kind.OHMYZSH, "oh-my-zsh", head, str(ohmyzsh_dir), path=str(ohmyzsh_dir)))

    parser_info = paths.home / ".local/share/nvim/site/parser-info"

    if parser_info.is_dir():
        for info in sorted(parser_info.glob("*.revision")):
            components.append(
                _installed(Kind.TREESITTER_PARSER, info.stem, info.read_text().strip(), str(info), path=str(info))
            )

    return components


def os_managers(repo: Path) -> list[str]:
    script = f'. "{repo}/zconf/lib/os.sh"; zc_os'
    name = procs.checked(["bash", "-c", script]).strip()

    if name == "unsupported":
        raise LookupError("this operating system is not supported by zconf (zc_os)")

    managers: list[str] = []

    for line in (repo / "packages/zconf/managers").read_text().splitlines():
        parts = line.split("\t")

        if len(parts) == 2 and parts[0] == name:
            managers.append(parts[1])

    return managers


def _listed_packages(repo: Path, manager: str) -> list[str]:
    names: list[str] = []

    for line in (repo / f"packages/{manager}.txt").read_text().splitlines():
        stripped = line.strip()

        if stripped and not stripped.startswith("#"):
            names.append(stripped.split("\t")[0])

    return names


def _package_version(manager: str, name: str) -> str | None:
    match manager:
        case "dnf":
            done = procs.run(["rpm", "-q", "--qf", "%{EPOCH}:%{VERSION}-%{RELEASE}", name])
        case "apt":
            done = procs.run(["dpkg-query", "-W", "-f", "${Version}", name])
        case "brew":
            done = procs.run(["brew", "list", "--versions", name])
        case "brew-cask":
            done = procs.run(["brew", "list", "--cask", "--versions", name])
        case other:
            raise LookupError(f"unknown package manager '{other}'")

    if done.code != 0 or not done.stdout.strip():
        return None

    text = done.stdout.strip()

    if manager.startswith("brew"):
        return text.split()[-1]

    return text.replace("(none):", "")


def _apt_source(name: str) -> dict[str, str]:
    done = procs.run(["dpkg-query", "-W", "-f", "${source:Package}\t${source:Version}", name])
    source, _, version = done.stdout.strip().partition("\t")

    if done.code != 0 or not source or not version:
        raise LookupError(f"dpkg-query cannot tell the source package of the installed {name}")

    return {"source": source, "source_version": version}


def _package_details(manager: str, name: str) -> dict[str, str]:
    match manager:
        case "apt":
            return _apt_source(name)
        case _:
            return {}


def os_packages(paths: Paths) -> Inventory:
    inventory = Inventory()

    for manager in os_managers(paths.repo):
        for name in _listed_packages(paths.repo, manager):
            version = _package_version(manager, name)

            if version is None:
                inventory.information.append(
                    Problem(None, "inventory", f"{manager} package {name} is listed but not installed on this machine")
                )
                continue

            inventory.components.append(
                _installed(
                    Kind.OS_PACKAGE,
                    name,
                    version,
                    f"packages/{manager}.txt",
                    manager=manager,
                    **_package_details(manager, name),
                )
            )

    return inventory


def installed(paths: Paths) -> Inventory:
    pinned = {(component.name, component.version) for component in mise_tools(paths.repo)}
    installs = mise_installs(paths, pinned)
    packages = os_packages(paths)

    return Inventory(
        components=[*installs.components, *repo_installs(paths), *installed_git(paths), *packages.components],
        leftovers=[*installs.leftovers, *stray_tracked_configs(paths)],
        information=[*installs.information, *packages.information],
    )
