import ast
import re
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass

import ghapi
from cpe import version_key
from model import Component, Finding

RANGE_TOKEN = re.compile(r"(<=|>=|<|>|=)?\s*v?([0-9][0-9A-Za-z.+-]*)(?:\s*\(\s*([A-Za-z][A-Za-z -]*)\))?")
RANGE_SEPARATORS = re.compile(r"[\s,]*")
STABLE_CHANNEL = "stable"
PATCHED_VERSION = re.compile(r"(?<![0-9A-Za-z.-])v?[0-9]+(?:\.[0-9]+)+(?:-[0-9A-Za-z.]+)?")
DATE_VERSION = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")
PRODUCT_PART = re.compile(r"^\s*([A-Za-z][A-Za-z.]*)\s+version\s+(.+?)\s*$", re.IGNORECASE)
RANGE_REWRITES = (
    (re.compile(r"\b(?:prior to|before)\s+", re.IGNORECASE), "< "),
    (re.compile(r"<\s+="), "<="),
    (re.compile(r">\s+="), ">="),
)
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


def _direction(operator: str) -> str:
    match operator:
        case "<" | "<=":
            return "upper"
        case ">" | ">=":
            return "lower"
        case _:
            return "exact"


@dataclass
class RangeGroup:
    bounds: list[tuple[str, str]]
    channel: str = ""

    def applies_to(self, version: str) -> bool:
        if self.channel in ("", STABLE_CHANNEL):
            return True

        return self.channel in version.lower()


def _normalized(expression: str) -> str:
    text = expression

    for pattern, replacement in RANGE_REWRITES:
        text = pattern.sub(replacement, text)

    return text


def _for_product(expression: str, product: str | None) -> str | None:
    parts = expression.split(",")
    labelled = [PRODUCT_PART.match(part) for part in parts]

    if not any(labelled):
        return expression

    if not product:
        raise SourceError(f"the version range '{expression}' names products; set advisory_product in the catalog")

    kept = [match.group(2) for match in labelled if match and match.group(1).lower() == product.lower()]

    if not kept:
        return None

    return ", ".join(kept)


def range_groups(expression: str, product: str | None = None) -> list[RangeGroup]:
    groups: list[RangeGroup] = []
    text = _for_product(expression, product)

    if text is None:
        return groups

    for alternative in _normalized(text).split("||"):
        groups.extend(_alternative_groups(alternative, expression))

    return groups


def _alternative_groups(text: str, expression: str) -> list[RangeGroup]:
    leftover = RANGE_SEPARATORS.sub("", RANGE_TOKEN.sub("", text))

    if leftover:
        raise SourceError(f"cannot read the version range '{expression}'")

    groups = [RangeGroup([])]

    for operator, bound, label in RANGE_TOKEN.findall(text):
        operator = operator or "="
        seen = {_direction(item) for item, _ in groups[-1].bounds}

        if _direction(operator) in seen or "exact" in seen:
            groups.append(RangeGroup([]))

        groups[-1].bounds.append((operator, bound))

        if label:
            groups[-1].channel = label.strip().lower()

    if not groups[0].bounds:
        raise SourceError(f"cannot read the version range '{expression}'")

    return groups


def _holds(key: tuple, operator: str, bound: str) -> bool:
    limit = version_key(bound)

    match operator:
        case "<":
            return key < limit
        case "<=":
            return key <= limit
        case ">":
            return key > limit
        case ">=":
            return key >= limit
        case _:
            return key == limit


def in_range(version: str, expression: str, product: str | None = None) -> bool:
    key = version_key(version)

    return any(
        group.applies_to(version) and all(_holds(key, operator, bound) for operator, bound in group.bounds)
        for group in range_groups(expression, product)
    )


def patched_list(text: str) -> list[str]:
    return [match.group(0) for match in PATCHED_VERSION.finditer(text or "")]


def _line(version: str) -> tuple:
    return version_key(version)[0][:2]


def is_patched(version: str, patched: list[str]) -> bool:
    key = version_key(version)
    at_or_above = [item for item in patched if key >= version_key(item)]

    if not at_or_above:
        return False

    if len(patched) == 1:
        return True

    return any(_line(item) == _line(version) for item in at_or_above) or key >= max(map(version_key, patched))


def affected(version: str, vulnerability: dict, product: str | None = None) -> bool:
    expression = vulnerability.get("vulnerable_version_range") or ""
    patched = patched_list(vulnerability.get("patched_versions") or "")

    if not expression:
        return False

    try:
        hit = in_range(version, expression, product)
    except SourceError:
        if not patched:
            raise

        hit = True

    return hit and not is_patched(version, patched)


def _same_package(name: str, target: str) -> bool:
    name, target = name.strip().lower(), target.strip().lower()

    return name == target or name.startswith(f"{target} ") or name.startswith(f"{target}-sdk")


def relevant(advisory: dict, target: str | None) -> list[dict]:
    entries = advisory.get("vulnerabilities", [])

    if not target:
        return entries

    matching = [entry for entry in entries if _same_package((entry.get("package") or {}).get("name") or "", target)]

    return matching or entries


def _lower_bound(expression: str) -> str | None:
    if not expression:
        return None

    lowest: str | None = None

    try:
        groups = range_groups(expression)
    except SourceError:
        return None

    for group in groups:
        lower = [bound for operator, bound in group.bounds if operator in (">=", ">")]

        if not lower:
            return None

        if lowest is None or version_key(lower[0]) < version_key(lowest):
            lowest = lower[0]

    return lowest


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


def check_version(component: Component, repo: str, version: str, product: str | None = None) -> list[Finding]:
    findings: list[Finding] = []

    target = product or repo.split("/")[-1]

    for advisory in advisories(repo):
        for vulnerability in relevant(advisory, target):
            try:
                hit = affected(version, vulnerability, product)
            except SourceError as error:
                raise SourceError(f"{repo} {advisory['ghsa_id']}: {error}") from error

            if hit:
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


def _contains_by_date(repo: str, commit: str, day: str) -> bool | None:
    try:
        details = ghapi.json_get(f"repos/{repo}")
        branch = details["default_branch"]
        on_branch = ghapi.json_get(f"repos/{repo}/compare/{commit}...{branch}").get("status") in CONTAINED
        committed = ghapi.json_get(f"repos/{repo}/commits/{commit}")["commit"]["committer"]["date"][:10]
    except (ghapi.GitHubError, KeyError, TypeError):
        return None

    if not on_branch:
        return None

    return committed >= day


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

            if DATE_VERSION.fullmatch(patched.strip()):
                contained = _contains_by_date(repo, commit, patched.strip())
            else:
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
