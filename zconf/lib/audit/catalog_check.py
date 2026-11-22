import json
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field

import ghapi
import webapi
from catalog import Catalog, CatalogError, Source, sources_for, vendored_version
from model import Component

NVD_CPES = "https://services.nvd.nist.gov/rest/json/cpes/2.0"
PARALLEL = 8


@dataclass
class CheckResult:
    not_covered: list[str] = field(default_factory=list)
    problems: list[str] = field(default_factory=list)
    unused: list[str] = field(default_factory=list)
    checked: int = 0


def coverage(catalog: Catalog, components: list[Component], managers: list[str]) -> CheckResult:
    result = CheckResult(problems=catalog.problems(), unused=catalog.unused(components, managers))

    for component in components:
        try:
            sources = sources_for(catalog, component)
        except CatalogError as error:
            result.problems.append(f"{component.key()}: {error}")
            continue

        if not sources:
            result.not_covered.append(f"{component.key()} ({component.origin}): no source in {catalog.path.name}")

    return result


def _cpe_exists(cpe: str) -> str | None:
    data = webapi.get_json(NVD_CPES, {"cpeMatchString": cpe, "resultsPerPage": 1})

    if data.get("totalResults", 0) == 0:
        return f"{cpe} is not in the NVD CPE dictionary"

    return None


def _repo_exists(repo: str) -> str | None:
    try:
        ghapi.json_get(f"repos/{repo}")
    except ghapi.GitHubError as error:
        return f"GitHub repository {repo} cannot be read: {error}"

    return None


def _file(repo: str, path: str, tag: str) -> str:
    return ghapi.raw_file(repo, path, tag)


def _file_exists(repo: str, path: str, tag: str) -> str | None:
    try:
        _file(repo, path, tag)
    except ghapi.GitHubError:
        return f"{repo}: {path} does not exist at {tag}"

    return None


def _vendored_ok(repo: str, tag: str, entry: dict) -> str | None:
    try:
        text = _file(repo, entry["path"], tag)
    except ghapi.GitHubError:
        return f"{repo}: vendored {entry['name']} file {entry['path']} does not exist at {tag}"

    if vendored_version(text, entry["regex"]) is None:
        return f"{repo}: vendored {entry['name']} version pattern does not match {entry['path']} at {tag}"

    return None


def _json_path(text: str, dotted: str) -> object:
    value: object = json.loads(text)

    for key in dotted.split("."):
        value = value[key]

    return value


def _bundle_ok(repo: str, tag: str, bundle: dict) -> list[str]:
    path, _, dotted = bundle["version_from"].partition(":")

    try:
        version = str(_json_path(_file(repo, path, tag), dotted))
    except (ghapi.GitHubError, KeyError, ValueError) as error:
        return [f"{repo}: cannot read {bundle['name']} version from {path}:{dotted} at {tag}: {error}"]

    inner_tag = bundle.get("upstream_tag", "v{version}").format(version=version)
    found = [_repo_exists(bundle["repo"])]
    found.extend(_file_exists(bundle["repo"], inner, inner_tag) for inner in bundle.get("upstream_files", []))

    return [problem for problem in found if problem]


def _source_checks(source: Source) -> list[str]:
    params = source.params

    match source.kind:
        case "nvd" | "nvd-commit":
            return [problem for problem in [_cpe_exists(params["cpe"])] if problem]
        case "github-advisories":
            return [problem for problem in [_repo_exists(params["repo"])] if problem]
        case "upstream-files":
            found = [_file_exists(params["repo"], path, params["tag"]) for path in params["paths"]]
            return [problem for problem in found if problem]
        case "upstream-submodules":
            return [problem for problem in [_file_exists(params["repo"], ".gitmodules", params["tag"])] if problem]
        case "upstream-deps":
            return [problem for problem in [_file_exists(params["repo"], params["path"], params["tag"])] if problem]
        case "upstream-vendored":
            found = [_vendored_ok(params["repo"], params["tag"], entry) for entry in params["entries"]]
            return [problem for problem in found if problem]
        case "upstream-bundle":
            return _bundle_ok(params["repo"], params["tag"], params["bundle"])
        case _:
            return []


def verify(catalog: Catalog, components: list[Component], managers: list[str]) -> CheckResult:
    result = coverage(catalog, components, managers)
    unique: dict[tuple, Source] = {}

    for component in components:
        try:
            sources = sources_for(catalog, component)
        except CatalogError:
            continue

        for source in sources:
            key = (source.kind, json.dumps(source.params, sort_keys=True, default=str))
            unique[key] = source

    for section in catalog.data.values():
        for entry in section.values():
            if entry.get("repo"):
                repo_source = Source("github-advisories", {"repo": entry["repo"]})
                unique[(repo_source.kind, entry["repo"])] = repo_source

            for cpe in entry.get("cpe", []):
                unique[("nvd", cpe)] = Source("nvd", {"cpe": cpe})

    with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
        for problems in pool.map(_source_checks, unique.values()):
            result.problems.extend(problems)

    result.checked = len(unique)

    return result
