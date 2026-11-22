import dataclasses
import re
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

import ghapi
import inventory
import procs
import upgrades
from catalog import Catalog, CatalogError, Source, github_repo, sources_for
from model import (
    FIX_AVAILABLE,
    NOT_COMPILED_IN,
    NOT_FAILING,
    WAITING,
    Component,
    Finding,
    Kind,
    Problem,
    Result,
    Scope,
)
from sources import bundled, distro, feeds, github, nvd, osv, readers

PARALLEL = 8
UPSTREAM_SCAN = "osv-scanner "
GITHUB_SOURCE = "github "
COMMIT_SHA = re.compile(r"[0-9a-f]{40}")
BATCHED_DISTRO = {
    "dnf": distro.dnf,
    "apt": distro.apt,
}


@dataclass(frozen=True)
class Task:
    component: Component
    source: Source


@dataclass
class Outcome:
    findings: list[Finding] = field(default_factory=list)
    information: list[Problem] = field(default_factory=list)
    not_covered: list[Problem] = field(default_factory=list)
    components: list[Component] = field(default_factory=list)
    tasks: list[Task] = field(default_factory=list)


def _child(parent: Component, kind: Kind, name: str, version: str, origin: str, **locator: object) -> Component:
    root = {
        "root_tool": parent.locator.get("root_tool", parent.name),
        "root_version": parent.locator.get("root_version", parent.version),
    }

    return Component(kind=kind, name=name, version=version, origin=origin, scope=parent.scope, locator={**locator, **root})


def _bundled_outcome(parent: Component, items: list[bundled.Bundled], origin: str) -> Outcome:
    outcome = Outcome()

    for item in items:
        component = _child(parent, Kind.BUNDLED, f"{parent.name}@{parent.version}/{item.name}", item.version, origin)
        tasks = [
            *(Task(component, Source("nvd", {"cpe": cpe, "version": item.version})) for cpe in item.cpe),
            *(
                Task(component, Source("osv-package", {"ecosystem": ecosystem, "name": name, "version": item.version}))
                for ecosystem, _, name in (package.partition(":") for package in item.osv)
            ),
        ]

        if item.cna:
            tasks.append(Task(component, Source("cna", {"specs": list(item.cna), "version": item.version})))

        outcome.components.append(component)
        outcome.tasks.extend(tasks)

        if item.shipped_by:
            outcome.information.append(
                Problem(component, "shipped-by", f"has no advisory channel of its own; covered by {item.shipped_by}")
            )
        elif not tasks:
            outcome.not_covered.append(Problem(component, "catalog", "the bundled library has no advisory source"))

    return outcome


def _pinned_outcome(parent: Component, pinned: list[github.Pinned], origin: str) -> Outcome:
    outcome = Outcome()

    for pin in pinned:
        name = f"{parent.name}@{parent.version}/{pin.path}"
        component = _child(parent, Kind.UPSTREAM_PIN, name, pin.revision, origin, url=pin.url)
        repo = github_repo(pin.url)
        outcome.components.append(component)
        outcome.tasks.append(Task(component, Source("osv-commit", {"commit": pin.revision})))

        if repo:
            outcome.tasks.append(Task(component, Source("github-advisories", {"repo": repo, "commit": pin.revision})))

    return outcome


def _commit_sha(ref: str, repo: str | None) -> str:
    if COMMIT_SHA.fullmatch(ref):
        return ref

    if not repo:
        raise CatalogError(f"{ref} is not a commit and no GitHub repository is known to resolve it")

    answer = ghapi.json_get(f"repos/{repo}/commits/{ref}")
    sha = answer.get("sha", "") if isinstance(answer, dict) else ""

    if not COMMIT_SHA.fullmatch(sha):
        raise CatalogError(f"{repo} {ref} does not resolve to a commit")

    return sha


def _package_outcome(component: Component, packages: list[readers.Package]) -> Outcome:
    queries = [osv.PackageQuery(component, package.ecosystem, package.name, package.version) for package in packages]

    return Outcome(findings=osv.query_packages(queries))


class Engine:
    def __init__(self, catalog: Catalog, repo: Path):
        self.catalog = catalog
        self.repo = repo

    def _python_ships(self) -> list[dict]:
        entry = self.catalog.entry(Kind.MISE_TOOL, "python") or {}

        return entry.get("bundled_from_lock_url", {}).get("ships", [])

    def _python_runtime(self, component: Component, params: dict) -> Outcome:
        found: list[bundled.Bundled] = []
        ships = self._python_ships()

        for library, version in readers.python_runtime(params["install"]).items():
            ship = next((item for item in ships if item["key"] == library or item["key"].startswith(f"{library}-")), None)

            if ship is None:
                raise readers.SourceError(f"the catalog's python ships list has no entry for {library}")

            found.append(
                bundled.Bundled(
                    name=library,
                    version=version,
                    cpe=tuple(ship.get("cpe", [])),
                    osv=tuple(ship.get("osv", [])),
                    cna=tuple(ship.get("cna", [])),
                    shipped_by=ship.get("shipped_by", ""),
                )
            )

        return _bundled_outcome(component, found, f"{component.locator.get('path')} (runtime)")

    def _command_version(self, component: Component, params: dict) -> Outcome:
        version = readers.command_version(params["path"], params["args"], params["regex"])
        item = bundled.Bundled(name=Path(params["path"]).name, version=version, cpe=(params["cpe"],))

        return _bundled_outcome(component, [item], params["path"])

    def _upstream_bundle(self, component: Component, params: dict) -> Outcome:
        spec = params["bundle"]
        item, inner_tag = bundled.bundle(params["repo"], params["tag"], spec)
        outcome = _bundled_outcome(component, [item], f"{params['repo']}@{params['tag']}")

        if spec.get("upstream_files"):
            child = outcome.components[0]
            files = {
                "repo": spec["repo"],
                "tag": inner_tag,
                "paths": spec["upstream_files"],
                "context": spec.get("upstream_context", []),
            }
            outcome.tasks.append(Task(child, Source("upstream-files", files)))

        return outcome

    def _upstream_deps(self, component: Component, params: dict) -> Outcome:
        pinned, unpinned = github.deps(params["repo"], params["tag"], params["path"])
        outcome = _pinned_outcome(component, pinned, f"{params['repo']}@{params['tag']} {params['path']}")

        for path in unpinned:
            outcome.information.append(
                Problem(component, "upstream-deps", f"{params['path']} entry {path} is a prebuilt package, not a git pin")
            )

        return outcome

    def _advisory_version(self, params: dict) -> str:
        match params.get("version_from"):
            case None:
                return params["version"]
            case "dotnet-runtime":
                return feeds.dotnet_runtime(params["version"])
            case other:
                raise CatalogError(f"unknown advisory_version '{other}'")

    def handle(self, task: Task) -> Outcome:
        component, params = task.component, task.source.params

        match task.source.kind:
            case "osv-lockfile":
                return Outcome(findings=osv.scan_lockfile(component, params["path"]))
            case "osv-artifact":
                return Outcome(findings=osv.scan_artifact(component, params["path"]))
            case "osv-package":
                query = osv.PackageQuery(component, params["ecosystem"], params["name"], params["version"])
                return Outcome(findings=osv.query_packages([query]))
            case "osv-commit":
                commit = _commit_sha(params["commit"], params.get("repo"))
                return Outcome(findings=osv.query_commits([osv.CommitQuery(component, commit)]))
            case "github-advisories" if "commit" in params:
                return Outcome(findings=github.check_commit(component, params["repo"], params["commit"]))
            case "github-advisories":
                version = self._advisory_version(params)
                found = github.check_version(component, params["repo"], version, params.get("product"))
                return Outcome(findings=found)
            case "nvd":
                return Outcome(findings=nvd.analysed(component, params["cpe"], params["version"]))
            case "nvd-commit":
                return Outcome(findings=nvd.commit_pinned(component, params["cpe"], params["repo"], params["commit"]))
            case "cna":
                return Outcome(findings=nvd.awaiting(component, params["specs"], params["version"]))
            case "upstream-files":
                found = osv.scan_upstream(
                    component,
                    params["repo"],
                    params["tag"],
                    params["paths"],
                    params.get("context", []),
                    params.get("roots", []),
                )
                return Outcome(findings=found)
            case "upstream-nuget-central":
                text = ghapi.raw_file(params["repo"], params["path"], params["tag"])
                return _package_outcome(component, readers.nuget_central(text, params["path"]))
            case "upstream-submodules":
                pinned = github.submodules(params["repo"], params["tag"])
                return _pinned_outcome(component, pinned, f"{params['repo']}@{params['tag']} .gitmodules")
            case "upstream-deps":
                return self._upstream_deps(component, params)
            case "upstream-vendored":
                items = bundled.vendored(params["repo"], params["tag"], params["entries"])
                return _bundled_outcome(component, items, f"{params['repo']}@{params['tag']}")
            case "upstream-bundle":
                return self._upstream_bundle(component, params)
            case "pbs-bundled":
                return _bundled_outcome(component, bundled.pbs(self.repo, params), "python-build-standalone")
            case "feed":
                return Outcome(findings=feeds.FEEDS[params["name"]](component, params["version"]))
            case "eol":
                return Outcome(findings=feeds.end_of_life(component, params["product"], params["version"]))
            case "shipped-by":
                message = f"has no advisory channel of its own; covered by {params['vendor']}"
                return Outcome(information=[Problem(component, "shipped-by", message)])
            case "reader-haskell-binary":
                return _package_outcome(component, readers.haskell_binary(params["path"]))
            case "reader-dotnet-single-file":
                return _package_outcome(component, readers.dotnet_single_file(params["path"]))
            case "reader-python-runtime":
                return self._python_runtime(component, params)
            case "reader-command-version":
                return self._command_version(component, params)
            case other:
                raise CatalogError(f"no handler for source kind '{other}'")

    def _guarded(self, task: Task) -> Outcome | Problem:
        try:
            return self.handle(task)
        except Exception as error:
            return Problem(task.component, task.source.kind, f"{type(error).__name__}: {error}")

    def _distro(self, tasks: list[Task]) -> list[Outcome | Problem]:
        answers: list[Outcome | Problem] = []
        by_manager: dict[str, list[Component]] = {}

        for task in tasks:
            by_manager.setdefault(task.source.params["manager"], []).append(task.component)

        for manager, components in by_manager.items():
            check = BATCHED_DISTRO.get(manager)

            if check is None:
                answers.append(Problem(components[0], "distro", f"no advisory source for package manager {manager}"))
                continue

            try:
                answers.append(Outcome(findings=check(components)))
            except Exception as error:
                answers.append(Problem(components[0], f"distro {manager}", f"{type(error).__name__}: {error}"))

        return answers

    def tasks_for(self, components: list[Component], result: Result) -> list[Task]:
        tasks: list[Task] = []

        for component in components:
            try:
                sources = sources_for(self.catalog, component)
            except CatalogError as error:
                result.could_not_run.append(Problem(component, "catalog", str(error)))
                continue

            if not sources:
                result.not_covered.append(Problem(component, "catalog", "no source in catalog.toml"))
                continue

            tasks.extend(Task(component, source) for source in sources)

        return tasks

    def run(self, components: list[Component]) -> Result:
        result = Result(components=list(components))
        pending = self.tasks_for(components, result)

        while pending:
            distro_tasks = [task for task in pending if task.source.kind == "distro"]
            other = [task for task in pending if task.source.kind != "distro"]
            pending = []

            with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
                answers = [*pool.map(self._guarded, other), *self._distro(distro_tasks)]

            for answer in answers:
                match answer:
                    case Problem():
                        result.could_not_run.append(answer)
                    case Outcome():
                        result.findings.extend(answer.findings)
                        result.information.extend(answer.information)
                        result.not_covered.extend(answer.not_covered)
                        result.components.extend(answer.components)
                        pending.extend(answer.tasks)

        result.findings = self.with_status(self.narrowed_to_binaries(unique_findings(result.findings)))

        return result

    def _repo_of(self, component: Component) -> tuple[tuple[str, str] | None, str | None]:
        key = upgrades.parent_of(component)

        if key is None:
            return None, None

        match component.kind:
            case Kind.TMUX_PLUGIN:
                return key, component.name
            case Kind.SUBMODULE:
                return key, github_repo(component.locator.get("url", ""))
            case Kind.NVIM_PLUGIN | Kind.OHMYZSH:
                return key, self.catalog.repo(component.kind, component.name)
            case _:
                return key, self.catalog.repo(Kind.MISE_TOOL, key[0])

    def with_status(self, findings: list[Finding]) -> list[Finding]:
        failing = [finding for finding in findings if not finding.dev_only and finding.notice not in NOT_FAILING]
        parents = {parent for parent in map(upgrades.parent_of, (f.component for f in failing)) if parent}
        repos = {key: repo for key, repo in map(self._repo_of, (f.component for f in failing)) if key and repo}
        commit_pinned = {
            upgrades.parent_of(f.component) for f in failing if f.component.kind in upgrades.COMMIT_KINDS
        }
        newest: dict[tuple[str, str], upgrades.Newest] = {}
        annotated: list[Finding] = []

        if parents:
            try:
                newest = upgrades.newest_versions(parents, self.repo / "mise/mise.toml", repos, commit_pinned)
            except (OSError, ValueError, procs.CommandError, ghapi.GitHubError):
                newest = {}

        for finding in findings:
            url = advisory_url(finding)

            if finding.component.kind == Kind.OS_PACKAGE:
                annotated.append(dataclasses.replace(finding, url=url, **distro.status(finding)))
                continue

            parent = upgrades.parent_of(finding.component)
            known = newest.get(parent) if parent else None

            if known is None or (known.in_line is None and known.any_line is None):
                annotated.append(dataclasses.replace(finding, url=url))
                continue

            status = WAITING

            if upgrades.available(known):
                status = FIX_AVAILABLE

            annotated.append(dataclasses.replace(finding, url=url, status=status, action=upgrades.action(known)))

        return annotated

    def install_paths(self) -> dict[tuple[str, str], str]:
        listing = inventory._mise_json(["ls", "--installed"], Path.home())

        return {
            (tool, entry["version"]): entry["install_path"]
            for tool, entries in listing.items()
            for entry in entries
            if entry.get("install_path")
        }

    def narrowed_to_binaries(self, findings: list[Finding]) -> list[Finding]:
        candidates = [finding for finding in findings if _from_upstream_lockfile(finding)]

        if not candidates:
            return findings

        try:
            installs = self.install_paths()
        except (procs.CommandError, ValueError):
            return findings

        listed: dict[str, set[str] | None] = {}
        narrowed: list[Finding] = []

        for finding in findings:
            path = installs.get((finding.component.name, finding.component.version))

            if not _from_upstream_lockfile(finding) or path is None:
                narrowed.append(finding)
                continue

            if path not in listed:
                try:
                    listed[path] = osv.binary_packages(path)
                except (osv.SourceError, procs.CommandError, ValueError):
                    listed[path] = None

            narrowed.append(_against_binary(finding, listed[path]))

        return narrowed


def advisory_url(finding: Finding) -> str:
    identifier = finding.id.split(",")[0].strip()

    if finding.source.startswith(GITHUB_SOURCE) and identifier.startswith("GHSA-"):
        repo = finding.source.removeprefix(GITHUB_SOURCE)
        return f"https://github.com/{repo}/security/advisories/{identifier}"

    match identifier.split("-")[0]:
        case "CVE":
            return f"https://nvd.nist.gov/vuln/detail/{identifier}"
        case "GHSA":
            return f"https://github.com/advisories/{identifier}"
        case "RUSTSEC":
            return f"https://rustsec.org/advisories/{identifier}.html"
        case "GO":
            return f"https://pkg.go.dev/vuln/{identifier}"
        case "FEDORA":
            return f"https://bodhi.fedoraproject.org/updates/{identifier}"
        case _ if finding.source.startswith(("osv", "osv-scanner")):
            return f"https://osv.dev/vulnerability/{identifier}"
        case _:
            return ""


def _from_upstream_lockfile(finding: Finding) -> bool:
    return (
        finding.component.kind == Kind.MISE_TOOL
        and finding.component.scope == Scope.DECLARED
        and finding.source.startswith(UPSTREAM_SCAN)
    )


def _against_binary(finding: Finding, packages: set[str] | None) -> Finding:
    if not packages:
        return finding

    ecosystem = finding.package.split("/", 1)[0]
    ecosystems = {package.split("/", 1)[0] for package in packages}

    if ecosystem not in ecosystems or finding.package in packages:
        return finding

    return dataclasses.replace(finding, notice=NOT_COMPILED_IN)


def unique_findings(findings: list[Finding]) -> list[Finding]:
    seen: set[tuple[str, str, str]] = set()
    unique: list[Finding] = []

    for finding in sorted(findings, key=lambda item: item.dev_only):
        key = (finding.component.key(), finding.id, finding.package)

        if key not in seen:
            seen.add(key)
            unique.append(finding)

    return unique
