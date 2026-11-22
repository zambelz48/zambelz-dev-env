import ast
import re
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass

import ghapi
from cpe import version_key
from model import Component, Finding

CONSTRAINT = re.compile(r"^\s*(<=|>=|<|>|=)?\s*v?([0-9][^\s,]*)\s*$")
TAG_FORMATS = ("v{version}", "{version}")
CONTAINED = ("ahead", "identical")
PARALLEL = 8


class SourceError(Exception):
    pass


@dataclass(frozen=True)
class Pinned:
    url: str
    revision: str
    path: str


def advisories(repo: str) -> list[dict]:
    try:
        pages = ghapi.json_get(f"repos/{repo}/security-advisories?state=published&per_page=100", paginate=True)
    except ghapi.GitHubError as error:
        raise SourceError(f"cannot read {repo} security advisories: {error}") from error

    return [advisory for page in pages for advisory in page]


def in_range(version: str, expression: str) -> bool:
    key = version_key(version)

    for part in expression.split(","):
        match = CONSTRAINT.match(part)

        if match is None:
            raise SourceError(f"cannot read the version range '{expression}'")

        operator, bound = match.group(1) or "=", version_key(match.group(2))

        match operator:
            case "<":
                ok = key < bound
            case "<=":
                ok = key <= bound
            case ">":
                ok = key > bound
            case ">=":
                ok = key >= bound
            case _:
                ok = key == bound

        if not ok:
            return False

    return True


def _lower_bound(expression: str) -> str | None:
    for part in expression.split(","):
        match = CONSTRAINT.match(part)

        if match and match.group(1) in (">=", ">"):
            return match.group(2)

    return None


def _finding(component: Component, repo: str, advisory: dict, note: str = "") -> Finding:
    patched = tuple(
        vulnerability.get("patched_versions")
        for vulnerability in advisory.get("vulnerabilities", [])
        if vulnerability.get("patched_versions")
    )

    return Finding(
        component=component,
        source=f"github {repo}",
        id=advisory["ghsa_id"],
        summary=f"{advisory.get('summary', '')}{note}",
        aliases=tuple(alias for alias in [advisory.get("cve_id")] if alias),
        fixed_in=patched,
        severity=advisory.get("severity") or "unknown",
        package=f"{repo}@{component.version}",
    )


def check_version(component: Component, repo: str, version: str) -> list[Finding]:
    findings: list[Finding] = []

    for advisory in advisories(repo):
        for vulnerability in advisory.get("vulnerabilities", []):
            expression = vulnerability.get("vulnerable_version_range") or ""

            if expression and in_range(version, expression):
                findings.append(_finding(component, repo, advisory))
                break

    return findings


def _contains(repo: str, commit: str, version: str) -> bool | None:
    for template in TAG_FORMATS:
        tag = template.format(version=version)

        try:
            compare = ghapi.json_get(f"repos/{repo}/compare/{tag}...{commit}")
        except ghapi.GitHubError:
            continue

        return compare.get("status") in CONTAINED

    return None


def check_commit(component: Component, repo: str, commit: str) -> list[Finding]:
    findings: list[Finding] = []

    for advisory in advisories(repo):
        for vulnerability in advisory.get("vulnerabilities", []):
            patched = vulnerability.get("patched_versions") or ""
            lower = _lower_bound(vulnerability.get("vulnerable_version_range") or "")

            if lower is not None and _contains(repo, commit, lower) is False:
                continue

            if not patched:
                findings.append(_finding(component, repo, advisory, " (no patched release)"))
                break

            contained = _contains(repo, commit, patched.split(",")[0].strip())

            if contained is None:
                findings.append(_finding(component, repo, advisory, f" (cannot verify: no tag for {patched})"))
                break

            if not contained:
                findings.append(_finding(component, repo, advisory))
                break

    return findings


def submodules(repo: str, tag: str) -> list[Pinned]:
    try:
        text = ghapi.raw_file(repo, ".gitmodules", tag)
    except ghapi.GitHubError as error:
        raise SourceError(f"cannot read {repo} .gitmodules at {tag}: {error}") from error

    paths = re.findall(r"^\s*path\s*=\s*(\S+)\s*$", text, re.MULTILINE)
    urls = re.findall(r"^\s*url\s*=\s*(\S+)\s*$", text, re.MULTILINE)

    def pinned(pair: tuple[str, str]) -> Pinned:
        path, url = pair

        try:
            entry = ghapi.json_get(f"repos/{repo}/contents/{path}?ref={tag}")
        except ghapi.GitHubError as error:
            raise SourceError(f"cannot read submodule {path} of {repo} at {tag}: {error}") from error

        if not isinstance(entry, dict) or entry.get("type") != "submodule":
            raise SourceError(f"{repo} {path} at {tag} is not a submodule")

        return Pinned(url=url, revision=entry["sha"], path=path)

    with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
        return list(pool.map(pinned, zip(paths, urls)))


class _DepsEvaluator(ast.NodeVisitor):
    def __init__(self, variables: dict):
        self.variables = variables

    def value(self, node: ast.AST) -> object:
        match node:
            case ast.Constant(value=value):
                return value
            case ast.Call(func=ast.Name(id="Var"), args=[argument]):
                return self.variables.get(self.value(argument), "")
            case ast.Call(func=ast.Name(id="Str"), args=[argument]):
                return self.value(argument)
            case ast.BinOp(left=left, op=ast.Add(), right=right):
                return f"{self.value(left)}{self.value(right)}"
            case ast.Dict(keys=keys, values=values):
                return {self.value(key): self.value(item) for key, item in zip(keys, values) if key is not None}
            case ast.List(elts=elements):
                return [self.value(element) for element in elements]
            case _:
                return None


def deps(repo: str, tag: str, path: str) -> tuple[list[Pinned], list[str]]:
    try:
        tree = ast.parse(ghapi.raw_file(repo, path, tag))
    except (ghapi.GitHubError, SyntaxError) as error:
        raise SourceError(f"cannot read {repo} {path} at {tag}: {error}") from error

    assignments = {
        node.targets[0].id: node.value
        for node in tree.body
        if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
    }
    variables = _DepsEvaluator({}).value(assignments.get("vars", ast.Dict(keys=[], values=[]))) or {}
    evaluator = _DepsEvaluator(variables)
    entries = evaluator.value(assignments.get("deps", ast.Dict(keys=[], values=[]))) or {}
    pinned: list[Pinned] = []
    unpinned: list[str] = []

    for dep_path, entry in entries.items():
        url = entry

        if isinstance(entry, dict):
            url = entry.get("url")

        if not isinstance(url, str) or "@" not in url:
            unpinned.append(dep_path)
            continue

        address, _, revision = url.rpartition("@")
        pinned.append(Pinned(url=address, revision=revision, path=dep_path))

    return pinned, unpinned
